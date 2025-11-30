import Foundation

struct FileDeleter {
    static func deleteFile(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
