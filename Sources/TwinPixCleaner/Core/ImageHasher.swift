import Foundation
import CryptoKit

struct ImageHasher {
    static func computeHash(for url: URL) -> String? {
        guard let handle = FileHandle(forReadingAtPath: url.path) else {
            print("Error hashing file \(url.lastPathComponent): could not open for reading")
            return nil
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        do {
            // Stream in 1MB chunks instead of loading the whole file into memory.
            while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
        } catch {
            print("Error hashing file \(url.lastPathComponent): \(error)")
            return nil
        }

        let digest = hasher.finalize()
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func getFileSize(for url: URL) -> Int64? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resources.fileSize ?? 0)
        } catch {
            print("Error getting file size for \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
