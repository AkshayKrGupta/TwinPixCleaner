import Foundation
import CryptoKit

struct ImageHasher {
    static func computeHash(for url: URL) -> String? {
        do {
            let fileData = try Data(contentsOf: url)
            let digest = SHA256.hash(data: fileData)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            print("Error hashing file \(url.lastPathComponent): \(error)")
            return nil
        }
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
