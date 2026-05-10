import Foundation
import CryptoKit

/// `DuplicateDetector` implements `ImageScanner` to find bit-for-bit identical files.
/// Process:
/// 1. Scans the directory natively.
/// 2. Groups files by exact file size.
/// 3. Computes SHA-256 hashes only for files that share a size.
/// 4. Groups by hash to return actual duplicates.
public struct DuplicateDetector: ImageScanner {
    
    public init() {}
    
    public func scan(
        in directory: URL,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void = { _, _ in }
    ) async -> [DuplicateGroup] {
        return await Task.detached {
            // 1. Scan for files
            await onProgress(0.0, "Scanning folder…")
            let files = FileScanner.scan(directory: directory)
            
            if files.isEmpty {
                return []
            }
            
            // 2. Group by size (fast pass — ~10% of progress)
            var filesBySize: [Int64: [URL]] = [:]
            for (index, file) in files.enumerated() {
                if let size = ImageHasher.getFileSize(for: file), size > 0 {
                    filesBySize[size, default: []].append(file)
                }
                if index % 50 == 0 {
                    let fraction = Double(index) / Double(files.count) * 0.1
                    await onProgress(fraction, file.lastPathComponent)
                }
            }
            
            // 3. Filter groups with > 1 file
            let potentialDuplicates = filesBySize.filter { $0.value.count > 1 }
            
            if potentialDuplicates.isEmpty {
                await onProgress(1.0, "Complete")
                return []
            }
            
            var duplicates: [DuplicateGroup] = []
            
            // 4. Hash and group by hash (~10%–100% of progress)
            let filesToHash = potentialDuplicates.flatMap { $0.value }
            var hashIndex = 0
            
            for (size, urls) in potentialDuplicates {
                var filesByHash: [String: [URL]] = [:]
                
                for url in urls {
                    hashIndex += 1
                    let fraction = 0.1 + (Double(hashIndex) / Double(filesToHash.count)) * 0.9
                    await onProgress(fraction, url.lastPathComponent)
                    
                    if let hash = ImageHasher.computeHash(for: url) {
                        filesByHash[hash, default: []].append(url)
                    }
                    
                    // Yield periodically
                    if hashIndex % 10 == 0 {
                        await Task.yield()
                    }
                }
                
                // 5. Collect actual duplicates
                for (hash, dupUrls) in filesByHash where dupUrls.count > 1 {
                    duplicates.append(DuplicateGroup(hash: hash, fileSize: size, fileURLs: dupUrls))
                }
            }
            
            await onProgress(1.0, "Complete")
            return duplicates
        }.value
    }
}
