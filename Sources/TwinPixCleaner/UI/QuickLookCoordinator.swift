@preconcurrency import Quartz
import SwiftUI

@MainActor
class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var previewURLs: [URL] = []
    var currentIndex: Int = 0
    
    // MARK: - QLPreviewPanelDataSource
    
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return MainActor.assumeIsolated { previewURLs.count }
    }
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        return MainActor.assumeIsolated {
            guard index >= 0, index < previewURLs.count else { return nil }
            return previewURLs[index] as NSURL
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
