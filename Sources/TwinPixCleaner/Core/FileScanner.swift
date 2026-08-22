import Foundation

struct FileScanner {
    /// Still-image extensions eligible for compare. See `StillImageEligibility`.
    static let imageExtensions: Set<String> = StillImageEligibility.allowedExtensions

    static func scan(directory: URL) throws -> [URL] {
        var fileURLs: [URL] = []
        let fileManager = FileManager.default

        // Options for enumeration: skip hidden files, produce URLs
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: options) else {
            throw AppError.unreadableDirectory(directory)
        }

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    if StillImageEligibility.isComparableStillImageFile(fileURL) {
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
