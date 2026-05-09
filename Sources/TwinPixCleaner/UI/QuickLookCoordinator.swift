@preconcurrency import Quartz
import SwiftUI
import Photos

@MainActor
class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var previewURLs: [URL] = []
    var currentIndex: Int = 0
    private var tempPhotoURLs: [URL: URL] = [:]
    
    // MARK: - QLPreviewPanelDataSource
    
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return MainActor.assumeIsolated { previewURLs.count }
    }
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        return MainActor.assumeIsolated {
            guard index >= 0, index < previewURLs.count else { return nil }
            let originalURL = previewURLs[index]
            
            if originalURL.scheme == "photos" {
                if let cached = tempPhotoURLs[originalURL] {
                    return cached as NSURL
                }
                let tempURL = extractPhotoToTemp(url: originalURL)
                tempPhotoURLs[originalURL] = tempURL
                return tempURL as NSURL
            }
            
            return originalURL as NSURL
        }
    }
    
    private func extractPhotoToTemp(url: URL) -> URL {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idItem = components.queryItems?.first(where: { $0.name == "id" }),
              let localIdentifier = idItem.value else {
            return url
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return url }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        var tempURL = url
        
        manager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
            guard let data = data else { return }
            
            let ext: String
            if let uti = dataUTI {
                if uti.contains("jpeg") { ext = "jpg" }
                else if uti.contains("png") { ext = "png" }
                else if uti.contains("heic") { ext = "heic" }
                else { ext = "jpg" }
            } else {
                ext = "jpg"
            }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + "." + ext
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL)
                tempURL = fileURL
            } catch {
                print("Failed to write temp photo for quicklook: \(error)")
            }
        }
        
        return tempURL
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        return false
    }
    
    // MARK: - Public API
    
    func show(urls: [URL], at index: Int = 0) {
        previewURLs = urls
        currentIndex = max(0, min(index, urls.count - 1))
        
        if let panel = QLPreviewPanel.shared() {
            if panel.isVisible {
                panel.reloadData()
            } else {
                panel.dataSource = self
                panel.delegate = self
                panel.currentPreviewItemIndex = currentIndex
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    func dismiss() {
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        }
        // Clean up temp files
        for (_, tempURL) in tempPhotoURLs {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempPhotoURLs.removeAll()
    }
    
    func toggle(urls: [URL], at index: Int = 0) {
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            dismiss()
        } else {
            show(urls: urls, at: index)
        }
    }
}

/// An invisible NSView that accepts and responds to QLPreviewPanel.
/// This is needed because SwiftUI views can't natively accept QLPreviewPanel.
struct QuickLookResponderView: NSViewRepresentable {
    let coordinator: QuickLookCoordinator
    
    func makeNSView(context: Context) -> QuickLookNSView {
        let view = QuickLookNSView()
        view.coordinator = coordinator
        return view
    }
    
    func updateNSView(_ nsView: QuickLookNSView, context: Context) {
        nsView.coordinator = coordinator
    }
}

class QuickLookNSView: NSView {
    var coordinator: QuickLookCoordinator?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = coordinator
            panel.delegate = coordinator
        }
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        // Clean up if needed
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 { // Spacebar
            coordinator?.toggle(urls: coordinator?.previewURLs ?? [])
        } else {
            super.keyDown(with: event)
        }
    }
}
