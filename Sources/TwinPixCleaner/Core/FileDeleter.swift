import Foundation
import Photos

struct FileDeleter {
    /// Moves the file to Trash and returns the URL of the trashed item.
    @discardableResult
    static func deleteFile(at url: URL) throws -> URL {
        let results = try deleteFiles(at: [url])
        guard let trashed = results[url] else {
            throw NSError(domain: "FileDeleter", code: 5, userInfo: [NSLocalizedDescriptionKey: "Deletion failed to return trashed URL"])
        }
        return trashed
    }
    
    /// Batches deletions. For Apple Photos, this ensures only one permission prompt is shown.
    /// Returns a dictionary mapping original URLs to their trashed URLs.
    static func deleteFiles(at urls: [URL]) throws -> [URL: URL] {
        var results: [URL: URL] = [:]
        var photoLocalIdentifiers: [String] = []
        var photoURLs: [URL] = []
        var fileURLs: [URL] = []
        
        for url in urls {
            if url.scheme == "photos" {
                if let localIdentifier = PhotosAssetURL.localIdentifier(from: url) {
                    photoLocalIdentifiers.append(localIdentifier)
                    photoURLs.append(url)
                }
            } else {
                fileURLs.append(url)
            }
        }

        // Batch delete Apple Photos assets — a single performChanges call means only one
        // permission prompt, and the change is atomic (all-or-nothing).
        if !photoLocalIdentifiers.isEmpty {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: photoLocalIdentifiers, options: nil)
            
            var assetsToDelete: [PHAsset] = []
            assets.enumerateObjects { asset, _, _ in
                assetsToDelete.append(asset)
            }
            
            if !assetsToDelete.isEmpty {
                class ErrorContainer: @unchecked Sendable {
                    var error: Error?
                }
                
                let group = DispatchGroup()
                let errorContainer = ErrorContainer()
                group.enter()
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
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
                
                for url in photoURLs {
                    results[url] = url // Photos don't change URL when trashed
                }
            }
        }
        
        // Each Finder file is trashed independently — a failure on one file must not discard the
        // URLs that were already successfully trashed above/before it. Files missing from
        // `results` are treated as failed deletions by the caller.
        for url in fileURLs {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
                results[url] = (resultingURL as URL?) ?? url
            } catch {
                continue
            }
        }

        return results
    }
    
    /// Restores a previously trashed file back to its original location.
    static func restoreFile(from trashedURL: URL, to originalURL: URL) throws {
        if originalURL.scheme == "photos" {
            throw NSError(domain: "FileDeleter", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cannot undo Apple Photos deletion programmatically. Please restore from 'Recently Deleted' in the Photos app."])
        }
        
        let parentDir = originalURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        try FileManager.default.moveItem(at: trashedURL, to: originalURL)
    }
}
