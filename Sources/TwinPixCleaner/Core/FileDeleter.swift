import Foundation
import Photos

struct FileDeleter {
    /// Moves the file to Trash and returns the URL of the trashed item.
    @discardableResult
    static func deleteFile(at url: URL) throws -> URL {
        if url.scheme == "photos" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let idItem = components.queryItems?.first(where: { $0.name == "id" }),
                  let localIdentifier = idItem.value else {
                throw NSError(domain: "FileDeleter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Photo URL"])
            }
            
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = assets.firstObject else {
                throw NSError(domain: "FileDeleter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Photo not found in Library"])
            }
            
            class ErrorContainer: @unchecked Sendable {
                var error: Error?
            }
            
            let group = DispatchGroup()
            let errorContainer = ErrorContainer()
            group.enter()
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }) { success, error in
                if !success {
                    errorContainer.error = error ?? NSError(domain: "FileDeleter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Deletion rejected"])
                }
                group.leave()
            }
            group.wait()
            
            if let error = errorContainer.error {
                throw error
            }
            return url // For photos, there is no separate trashed URL needed
        }
        
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return (resultingURL as URL?) ?? url
    }
    
    /// Restores a previously trashed file back to its original location.
    static func restoreFile(from trashedURL: URL, to originalURL: URL) throws {
        if originalURL.scheme == "photos" {
            throw NSError(domain: "FileDeleter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot undo Apple Photos deletion programmatically. Please restore from 'Recently Deleted' in the Photos app."])
        }
        
        // Ensure the parent directory exists
        let parentDir = originalURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        try FileManager.default.moveItem(at: trashedURL, to: originalURL)
    }
}
