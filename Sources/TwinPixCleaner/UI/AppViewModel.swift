import SwiftUI
import Combine
import Quartz
import Photos

enum AppState: Equatable {
    case idle
    case scanning
    case results([DuplicateGroup])
    
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning):
            return true
        case (.results, .results):
            return true
        default:
            return false
        }
    }
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
    
    // Quick Look
    let quickLookCoordinator = QuickLookCoordinator()
    
    // Undo support
    struct DeletedFileRecord {
        let originalURL: URL
        let trashedURL: URL
        let groupHash: String
        let groupFileSize: Int64
    }
    @Published var deletionHistory: [DeletedFileRecord] = []
    
    private var scanTask: Task<Void, Never>?
    
    func startScanning(directory: URL) {
        state = .scanning
        duplicateCount = 0
        selectedFiles.removeAll()
        scanProgress = 0.0
        currentFile = ""
        appError = nil
        
        let mode = scanMode
        
        scanTask = Task { @MainActor in
            let duplicates: [DuplicateGroup]
            
            let progressHandler: @MainActor @Sendable (Double, String) -> Void = { progress, file in
                self.scanProgress = progress
                self.currentFile = file
            }
            
            let scanner: any ImageScanner = mode == .exact ? DuplicateDetector() : SimilarityDetector(threshold: 8.0)
            
            duplicates = await scanner.scan(
                in: directory,
                onProgress: progressHandler
            )
            
            if !Task.isCancelled {
                self.state = .results(duplicates)
                self.duplicateCount = duplicates.count
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
        
        let mode = scanMode
        
        scanTask = Task { @MainActor in
            let duplicates: [DuplicateGroup]
            
            let progressHandler: @MainActor @Sendable (Double, String) -> Void = { progress, file in
                self.scanProgress = progress
                self.currentFile = file
            }
            
            let scanner: any ImageScanner = PhotoLibraryScanner(mode: mode)
            
            // For photos, the directory URL doesn't matter
            let dummyURL = URL(string: "photos://library")!
            duplicates = await scanner.scan(
                in: dummyURL,
                onProgress: progressHandler
            )
            
            if !Task.isCancelled {
                // If it returns empty but we have an error (e.g. prompt was just denied)
                let finalStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                if finalStatus == .restricted || finalStatus == .denied {
                    self.appError = .unknown("Apple Photos access was denied. Please run the compiled TwinPixCleaner.app bundle and grant permission.")
                    self.state = .idle
                } else {
                    self.state = .results(duplicates)
                    self.duplicateCount = duplicates.count
                }
            }
        }
    }
    
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
        appError = .scanCancelled
    }
    
    func reset() {
        state = .idle
        duplicateCount = 0
        selectedFiles.removeAll()
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
        
        for url in selectedFiles {
            // Find the group this file belongs to
            let matchingGroup = groups.first { $0.fileURLs.contains(url) }
            
            do {
                let trashedURL = try FileDeleter.deleteFile(at: url)
                deletionHistory.append(DeletedFileRecord(
                    originalURL: url,
                    trashedURL: trashedURL,
                    groupHash: matchingGroup?.hash ?? "",
                    groupFileSize: matchingGroup?.fileSize ?? 0
                ))
            } catch {
                failedDeletions.append(url.lastPathComponent)
            }
        }
        
        if !failedDeletions.isEmpty {
            appError = .multipleDeletionsFailed(failedDeletions)
        }
        
        // Update groups
        groups = groups.compactMap { group in
            let remainingURLs = group.fileURLs.filter { !selectedFiles.contains($0) }
            if remainingURLs.count > 1 {
                return DuplicateGroup(hash: group.hash, fileSize: group.fileSize, fileURLs: remainingURLs)
            }
            return nil
        }
        
        selectedFiles.removeAll()
        state = .results(groups)
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
            
            // Update the group
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
        } catch {
            appError = .deletionFailed(url, error.localizedDescription)
        }
    }
    
    /// Undo the last deletion (⌘Z support)
    func undoLastDeletion() {
        guard let record = deletionHistory.popLast() else { return }
        guard case .results(var groups) = state else { return }
        
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
    
    func getFileMetadata(url: URL) -> String {
        if url.scheme == "photos" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idItem = components.queryItems?.first(where: { $0.name == "id" }),
                  let localIdentifier = idItem.value else {
                return "Photo Asset"
            }
            
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = assets.firstObject else { return "Unknown Asset" }
            
            var info = "Photo Asset"
            
            if let creationDate = asset.creationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                info += "\nCreated: \(formatter.string(from: creationDate))"
            }
            
            info += "\nDimensions: \(asset.pixelWidth) x \(asset.pixelHeight)"
            
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
