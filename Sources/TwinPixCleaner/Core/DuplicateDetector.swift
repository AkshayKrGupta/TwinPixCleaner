import Foundation

struct DuplicateGroup: Identifiable, Hashable {
    let id = UUID()
    let hash: String
    let fileSize: Int64
    let fileURLs: [URL]
}

class DuplicateDetector {
    static func findDuplicates(in directory: URL) async -> [DuplicateGroup] {
        // 1. Scan for files
        let files = FileScanner.scan(directory: directory)
        
        if files.isEmpty {
            return []
        }
        
        // 2. Group by size
        var filesBySize: [Int64: [URL]] = [:]
        for file in files {
            if let size = ImageHasher.getFileSize(for: file), size > 0 {
                filesBySize[size, default: []].append(file)
            }
        }
        
        // 3. Filter groups with > 1 file
        let potentialDuplicates = filesBySize.filter { $0.value.count > 1 }
        
        if potentialDuplicates.isEmpty {
            return []
        }
        
        var duplicates: [DuplicateGroup] = []
        
        // 4. Hash and group by hash
        for (size, urls) in potentialDuplicates {
            var filesByHash: [String: [URL]] = [:]
            
            for url in urls {
                if let hash = ImageHasher.computeHash(for: url) {
                    filesByHash[hash, default: []].append(url)
                }
            }
            
            // 5. Collect actual duplicates
            for (hash, dupUrls) in filesByHash where dupUrls.count > 1 {
                duplicates.append(DuplicateGroup(hash: hash, fileSize: size, fileURLs: dupUrls))
            }
        }
        
        return duplicates
    }
}
