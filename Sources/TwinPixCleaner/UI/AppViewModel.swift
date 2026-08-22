import SwiftUI
import Photos

// Synthesized Equatable: DuplicateGroup is itself Equatable, so `.results` compares the
// actual groups instead of always reporting equal regardless of content.
enum AppState: Equatable {
    case idle
    case scanning
    case results([DuplicateGroup])
}

enum ScanMode: String, CaseIterable, Identifiable {
    case exact = "Exact Match"
    case similar = "Visual Similarity"
    var id: String { rawValue }
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var state: AppState = .idle
    @Published var duplicateCount: Int = 0
    @Published var selectedFiles: Set<URL> = []
    @Published var scanProgress: Double = 0.0
    @Published var currentFile: String = ""
    @Published var appError: AppError?
    
    @Published var scanMode: ScanMode = .exact
    @Published var showUserGuide: Bool = false
    @Published var lastScanSkippedCount: Int = 0
    
    let quickLookCoordinator = QuickLookCoordinator()

    struct DeletedFileRecord {
        let originalURL: URL
        let trashedURL: URL
        let groupHash: String
        let groupFileSize: Int64
    }
    @Published var deletionHistory: [DeletedFileRecord] = []
    @Published var showUndoToast: Bool = false
    @Published var lastDeletionCount: Int = 0

    private var scanTask: Task<Void, Never>?
    private var undoToastDismissTask: Task<Void, Never>?
    private var metadataCache: [URL: String] = [:]

    init() {
        Task.detached(priority: .background) {
            FeaturePrintEngine.pruneCache()
        }
    }
    
    func startScanning(directory: URL) {
        state = .scanning
        duplicateCount = 0
        selectedFiles.removeAll()
        scanProgress = 0.0
        currentFile = ""
        appError = nil
        lastScanSkippedCount = 0

        let mode = scanMode

        scanTask = Task { @MainActor in
            let progressHandler: @MainActor @Sendable (Double, String) -> Void = { progress, file in
                self.scanProgress = progress
                self.currentFile = file
            }

            let scanner: any ImageScanner = mode == .exact ? DuplicateDetector() : SimilarityDetector()

            do {
                let result = try await scanner.scan(in: directory, onProgress: progressHandler)
                if !Task.isCancelled {
                    self.state = .results(result.groups)
                    self.duplicateCount = result.groups.count
                    self.lastScanSkippedCount = result.skippedCount
                }
            } catch {
                if !Task.isCancelled {
                    self.appError = (error as? AppError) ?? .unknown(error.localizedDescription)
                    self.state = .idle
                }
            }
        }
    }
    
    func startPhotosScanning() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .restricted || status == .denied {
            self.appError = .unknown("Apple Photos access denied. Please run the compiled TwinPixCleaner.app bundle instead of 'swift run', and ensure permission is granted in System Settings.")
            return
        }
        
        state = .scanning
        duplicateCount = 0
        selectedFiles.removeAll()
        scanProgress = 0.0
        currentFile = ""
        appError = nil
        lastScanSkippedCount = 0

        let mode = scanMode

        scanTask = Task { @MainActor in
            let progressHandler: @MainActor @Sendable (Double, String) -> Void = { progress, file in
                self.scanProgress = progress
                self.currentFile = file
            }

            let scanner: any ImageScanner = PhotoLibraryScanner(mode: mode)

            // For photos, the directory URL doesn't matter
            let dummyURL = URL(string: "photos://library")!

            do {
                let result = try await scanner.scan(in: dummyURL, onProgress: progressHandler)
                if !Task.isCancelled {
                    // If it returns empty but we have an error (e.g. prompt was just denied)
                    let finalStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if finalStatus == .restricted || finalStatus == .denied {
                        self.appError = .unknown("Apple Photos access was denied. Please run the compiled TwinPixCleaner.app bundle and grant permission.")
                        self.state = .idle
                    } else {
                        self.state = .results(result.groups)
                        self.duplicateCount = result.groups.count
                        self.lastScanSkippedCount = result.skippedCount
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.appError = (error as? AppError) ?? .unknown(error.localizedDescription)
                    self.state = .idle
                }
            }
        }
    }
    
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil
        // No appError here: cancelling is a routine, user-initiated action, not a failure —
        // popping the generic "Error" alert for it would be misleading.
        state = .idle
    }
    
    func reset() {
        state = .idle
        duplicateCount = 0
        selectedFiles.removeAll()
        lastScanSkippedCount = 0
        metadataCache.removeAll()
    }
    
    /// Selects all files in a group except the given one (the one to keep).
    func keepOnly(_ url: URL, in group: DuplicateGroup) {
        for fileURL in group.fileURLs where fileURL != url {
            selectedFiles.insert(fileURL)
        }
        selectedFiles.remove(url)
    }
    
    /// Selects all duplicates in a group except the first one.
    func selectAllDuplicates(in group: DuplicateGroup) {
        for fileURL in group.fileURLs.dropFirst() {
            selectedFiles.insert(fileURL)
        }
    }
    
    func toggleSelection(for url: URL) {
        if selectedFiles.contains(url) {
            selectedFiles.remove(url)
        } else {
            selectedFiles.insert(url)
        }
    }
    
    func deleteSelectedFiles() {
        guard case .results(var groups) = state else { return }

        var failedDeletions: [String] = []
        var deletedCount = 0
        let urlsToDelete = Array(selectedFiles)

        do {
            let results = try FileDeleter.deleteFiles(at: urlsToDelete)

            for url in urlsToDelete {
                if let trashedURL = results[url] {
                    let matchingGroup = groups.first { $0.fileURLs.contains(url) }
                    deletionHistory.append(DeletedFileRecord(
                        originalURL: url,
                        trashedURL: trashedURL,
                        groupHash: matchingGroup?.hash ?? "",
                        groupFileSize: matchingGroup?.fileSize ?? 0
                    ))
                    deletedCount += 1
                } else {
                    failedDeletions.append(url.lastPathComponent)
                }
            }
        } catch {
            appError = .multipleDeletionsFailed([error.localizedDescription])
            return // Stop if batch completely fails
        }

        if !failedDeletions.isEmpty {
            appError = .multipleDeletionsFailed(failedDeletions)
        }

        groups = groups.compactMap { group in
            let remainingURLs = group.fileURLs.filter { !selectedFiles.contains($0) }
            if remainingURLs.count > 1 {
                return DuplicateGroup(hash: group.hash, fileSize: group.fileSize, fileURLs: remainingURLs)
            }
            return nil
        }

        selectedFiles.removeAll()
        state = .results(groups)
        presentUndoToast(count: deletedCount)
    }

    func deleteFile(url: URL, in group: DuplicateGroup) {
        guard case .results(var groups) = state else { return }

        do {
            let trashedURL = try FileDeleter.deleteFile(at: url)
            deletionHistory.append(DeletedFileRecord(
                originalURL: url,
                trashedURL: trashedURL,
                groupHash: group.hash,
                groupFileSize: group.fileSize
            ))

            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                let updatedURLs = groups[index].fileURLs.filter { $0 != url }

                if updatedURLs.count > 1 {
                    let updatedGroup = DuplicateGroup(
                        hash: groups[index].hash,
                        fileSize: groups[index].fileSize,
                        fileURLs: updatedURLs
                    )
                    groups[index] = updatedGroup
                } else {
                    groups.remove(at: index)
                }
            }

            selectedFiles.remove(url)
            state = .results(groups)
            presentUndoToast(count: 1)
        } catch {
            appError = .deletionFailed(url, error.localizedDescription)
        }
    }

    /// Shows the "Moved to Trash · Undo" toast for a few seconds after a deletion.
    /// If a toast is already showing, the new count is added to it (rather than replacing it)
    /// so Undo still restores everything deleted while the toast has been visible.
    private func presentUndoToast(count: Int) {
        guard count > 0 else { return }
        lastDeletionCount = showUndoToast ? lastDeletionCount + count : count
        showUndoToast = true
        undoToastDismissTask?.cancel()
        undoToastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            self.showUndoToast = false
        }
    }

    /// Undoes every file from the deletion that triggered the current undo toast.
    func undoLastBatch() {
        undoToastDismissTask?.cancel()
        showUndoToast = false
        let count = min(lastDeletionCount, deletionHistory.count)
        for _ in 0..<count {
            undoLastDeletion()
        }
    }
    
    /// Undo the last deletion (⌘Z support)
    func undoLastDeletion() {
        guard let record = deletionHistory.popLast() else { return }
        guard case .results(var groups) = state else { return }

        // A manual step-by-step undo invalidates the toast's "undo this whole batch" count.
        if showUndoToast {
            undoToastDismissTask?.cancel()
            showUndoToast = false
        }
        
        do {
            try FileDeleter.restoreFile(from: record.trashedURL, to: record.originalURL)
            
            // Re-insert into the matching group or create a new one
            if let index = groups.firstIndex(where: { $0.hash == record.groupHash }) {
                var updatedURLs = groups[index].fileURLs
                updatedURLs.append(record.originalURL)
                groups[index] = DuplicateGroup(
                    hash: groups[index].hash,
                    fileSize: groups[index].fileSize,
                    fileURLs: updatedURLs
                )
            } else {
                // Group was removed — recreate it with just this file pair
                // (won't happen often; the group only disappears if < 2 files remain)
                groups.append(DuplicateGroup(
                    hash: record.groupHash,
                    fileSize: record.groupFileSize,
                    fileURLs: [record.originalURL]
                ))
            }
            
            state = .results(groups)
        } catch {
            appError = .restorationFailed(record.originalURL, error.localizedDescription)
        }
    }
    
    var canUndo: Bool {
        !deletionHistory.isEmpty
    }
    
    /// Quick Look: toggle preview for selected/all images
    func toggleQuickLook(for urls: [URL], at index: Int = 0) {
        quickLookCoordinator.toggle(urls: urls, at: index)
    }
    
    /// Metadata is read from disk/PhotoKit and is otherwise recomputed on every view-body
    /// re-evaluation (e.g. every selection change) since callers use this as a plain
    /// computed value — cache it per URL, since it doesn't change within a scan session.
    func getFileMetadata(url: URL) -> String {
        if let cached = metadataCache[url] { return cached }
        let info = computeFileMetadata(url: url)
        metadataCache[url] = info
        return info
    }

    private func computeFileMetadata(url: URL) -> String {
        if url.scheme == "photos" {
            guard let asset = PhotosAssetURL.asset(from: url) else { return "Unknown Asset" }


            let resources = PHAssetResource.assetResources(for: asset)
            let photoResource = resources.first { $0.type == .photo }
            let filename = photoResource?.originalFilename ?? "Photo Asset"
            
            var info = "Name: \(filename)"
            
            if let creationDate = asset.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                info += "\nCreated: \(formatter.string(from: creationDate))"
            }
            
            info += "\nDimensions: \(asset.pixelWidth) x \(asset.pixelHeight)"
            
            if let size = (photoResource?.value(forKey: "fileSize") as? NSNumber)?.int64Value, size > 0 {
                info += "\nSize: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
            }
            
            return info
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            var info = "Name: \(url.lastPathComponent)\nPath: \(url.path)"
            
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                info += "\nCreated: \(formatter.string(from: creationDate))"
            }
            
            if let size = attributes[.size] as? Int64 {
                info += "\nSize: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
            }
            
            return info
        } catch {
            return "Path: \(url.path)"
        }
    }
}
