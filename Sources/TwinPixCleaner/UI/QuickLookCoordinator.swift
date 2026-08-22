@preconcurrency import Quartz
import SwiftUI
import Photos

@MainActor
class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var previewURLs: [URL] = []
    var currentIndex: Int = 0
    private var tempPhotoURLs: [URL: URL] = [:]

    nonisolated private static var tempDirectory: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TwinPixCleaner_QL", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Cleans up any orphaned temporary preview files from current or past sessions.
    nonisolated static func cleanupTempDirectory() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("TwinPixCleaner_QL", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    override init() {
        super.init()
        Self.cleanupTempDirectory()
    }
    
    deinit {
        // Clean up any leaked temp files when the coordinator is deallocated (e.g. app quit)
        for (_, tempURL) in tempPhotoURLs {
            try? FileManager.default.removeItem(at: tempURL)
        }
        Self.cleanupTempDirectory()
    }
    
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
        guard let asset = PhotosAssetURL.asset(from: url) else { return url }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        var tempURL = url

        manager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
            guard let data = data, let written = self.writeTempPhoto(data: data, dataUTI: dataUTI) else { return }
            tempURL = written
        }

        return tempURL
    }

    /// Async counterpart to `extractPhotoToTemp`, used to prefetch off the main thread
    /// before the panel opens (see `show(urls:at:)`) so the synchronous
    /// `QLPreviewPanelDataSource` callback doesn't have to block on an iCloud download.
    @discardableResult
    private func prefetchPhotoToTemp(url: URL) async -> URL? {
        if let cached = tempPhotoURLs[url] { return cached }
        guard let asset = PhotosAssetURL.asset(from: url) else { return nil }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        let result: (Data, String?)? = await withCheckedContinuation { continuation in
            manager.requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
                if let data { continuation.resume(returning: (data, dataUTI)) }
                else { continuation.resume(returning: nil) }
            }
        }
        guard let (data, dataUTI) = result, let fileURL = writeTempPhoto(data: data, dataUTI: dataUTI) else {
            return nil
        }

        tempPhotoURLs[url] = fileURL
        return fileURL
    }

    private func writeTempPhoto(data: Data, dataUTI: String?) -> URL? {
        let ext: String
        if let uti = dataUTI {
            if uti.contains("jpeg") { ext = "jpg" }
            else if uti.contains("png") { ext = "png" }
            else if uti.contains("heic") { ext = "heic" }
            else { ext = "jpg" }
        } else {
            ext = "jpg"
        }

        let tempDir = Self.tempDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + "." + ext)

        do {
            // Write with atomic flag for safety
            try data.write(to: fileURL, options: [.atomic])
            // Restrict permissions to owner read/write only (0o600) so other processes
            // running as the same user cannot read the exported photo.
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return fileURL
        } catch {
            print("Failed to write temp photo for quicklook: \(error)")
            return nil
        }
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        return false
    }
    
    // MARK: - Public API
    
    func show(urls: [URL], at index: Int = 0) {
        previewURLs = urls
        currentIndex = max(0, min(index, urls.count - 1))

        // Prefetch the initially visible photo asynchronously so the synchronous
        // QLPreviewPanelDataSource callback below has a chance to find it already cached
        // instead of blocking the main thread on an iCloud download.
        if currentIndex < urls.count, urls[currentIndex].scheme == "photos" {
            let urlToPrefetch = urls[currentIndex]
            Task { await prefetchPhotoToTemp(url: urlToPrefetch) }
        }

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
