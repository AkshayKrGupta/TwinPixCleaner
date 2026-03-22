import Foundation

struct FileDeleter {
    /// Moves the file to Trash and returns the URL of the trashed item.
    @discardableResult
    static func deleteFile(at url: URL) throws -> URL {
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
        return (resultingURL as URL?) ?? url
    }
    
    /// Restores a previously trashed file back to its original location.
    static func restoreFile(from trashedURL: URL, to originalURL: URL) throws {
        // Ensure the parent directory exists
        let parentDir = originalURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        try FileManager.default.moveItem(at: trashedURL, to: originalURL)
    }
}
