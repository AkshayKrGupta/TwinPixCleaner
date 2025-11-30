import Foundation

struct FileScanner {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "tiff", "bmp", "gif", "webp"]

    static func scan(directory: URL) -> [URL] {
        var fileURLs: [URL] = []
        let fileManager = FileManager.default
        
        // Options for enumeration: skip hidden files, produce URLs
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: options) else {
            return []
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    if imageExtensions.contains(fileURL.pathExtension.lowercased()) {
                        fileURLs.append(fileURL)
                    }
                }
            } catch {
                print("Error reading file attributes: \(error)")
            }
        }
        
        return fileURLs
    }
}
