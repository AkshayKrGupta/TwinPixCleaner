import SwiftUI
import Combine

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
    @Published var scannedCount: Int = 0
    @Published var duplicateCount: Int = 0
    @Published var selectedFiles: Set<URL> = []
    @Published var scanProgress: Double = 0.0
    @Published var currentFile: String = ""
    @Published var errorMessage: String?
    
    @Published var scanMode: ScanMode = .exact
    @Published var showUserGuide: Bool = false
    
    private var scanTask: Task<Void, Never>?
    
    func startScanning(directory: URL) {
        state = .scanning
        scannedCount = 0
        duplicateCount = 0
        selectedFiles.removeAll()
        scanProgress = 0.0
        currentFile = ""
        errorMessage = nil
        
        let mode = scanMode
        
        scanTask = Task { @MainActor in
            let duplicates: [DuplicateGroup]
            
            if mode == .exact {
                duplicates = await DuplicateDetector.findDuplicates(in: directory)
            } else {
                // Use fixed moderate threshold of 8.0
                duplicates = await SimilarityDetector.findSimilarImages(in: directory, threshold: 8.0)
            }
            
            if !Task.isCancelled {
                self.state = .results(duplicates)
                self.duplicateCount = duplicates.count
            }
        }
    }
    
    func cancelScanning() {
        scanTask?.cancel()
        scanTask = nil
        state = .idle
        errorMessage = nil
    }
    
    func reset() {
        state = .idle
        scannedCount = 0
        duplicateCount = 0
        selectedFiles.removeAll()
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
            do {
                try FileDeleter.deleteFile(at: url)
            } catch {
                failedDeletions.append(url.lastPathComponent)
                print("Failed to delete \(url.path): \(error)")
            }
        }
        
        if !failedDeletions.isEmpty {
            errorMessage = "Failed to delete \(failedDeletions.count) file(s): \(failedDeletions.joined(separator: ", "))"
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
            try FileDeleter.deleteFile(at: url)
            
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
            errorMessage = "Failed to delete file: \(error.localizedDescription)"
            print("Error deleting file: \(error)")
        }
    }
    
    func getFileMetadata(url: URL) -> String {
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
