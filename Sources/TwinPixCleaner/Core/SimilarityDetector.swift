import Foundation
import Vision
import AppKit

class SimilarityDetector {
    
    static func computeFeaturePrint(for url: URL) -> VNFeaturePrintObservation? {
        autoreleasepool {
            guard let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }
            
            let request = VNGenerateImageFeaturePrintRequest()
            request.revision = VNGenerateImageFeaturePrintRequestRevision1
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                return request.results?.first as? VNFeaturePrintObservation
            } catch {
                print("Failed to compute feature print for \(url.lastPathComponent): \(error)")
                return nil
            }
        }
    }
    
    static func findSimilarImages(in directory: URL, threshold: Float) async -> [DuplicateGroup] {
        let files = FileScanner.scan(directory: directory)
        if files.isEmpty { return [] }
        
        // Limit to prevent crashes with large libraries
        let maxFiles = 500
        let filesToProcess = files.count > maxFiles ? Array(files.prefix(maxFiles)) : files
        
        var prints: [(URL, VNFeaturePrintObservation)] = []
        
        // 1. Compute feature prints in batches to manage memory
        let batchSize = 50
        for batchStart in stride(from: 0, to: filesToProcess.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, filesToProcess.count)
            let batch = Array(filesToProcess[batchStart..<batchEnd])
            
            for file in batch {
                autoreleasepool {
                    if let print = computeFeaturePrint(for: file) {
                        prints.append((file, print))
                    }
                }
            }
            
            // Yield to prevent blocking
            await Task.yield()
        }
        
        if prints.isEmpty { return [] }
        
        var groups: [DuplicateGroup] = []
        var processedIndices = Set<Int>()
        
        // 2. Cluster images with optimized comparison
        for i in 0..<prints.count {
            if processedIndices.contains(i) { continue }
            
            let (url1, print1) = prints[i]
            var groupURLs = [url1]
            processedIndices.insert(i)
            
            // Only compare with remaining unprocessed images
            for j in (i+1)..<prints.count {
                if processedIndices.contains(j) { continue }
                
                let (url2, print2) = prints[j]
                
                var distance: Float = 0
                do {
                    try print1.computeDistance(&distance, to: print2)
                    // Threshold 8.0 is moderate - finds similar but not too loose
                    if distance <= threshold {
                        groupURLs.append(url2)
                        processedIndices.insert(j)
                    }
                } catch {
                    // Skip on error rather than crash
                    continue
                }
            }
            
            if groupURLs.count > 1 {
                // Calculate average size for display
                let totalSize = groupURLs.reduce(0) { $0 + (ImageHasher.getFileSize(for: $1) ?? 0) }
                let avgSize = totalSize / Int64(groupURLs.count)
                
                groups.append(DuplicateGroup(
                    hash: "SIMILAR-" + UUID().uuidString,
                    fileSize: avgSize,
                    fileURLs: groupURLs
                ))
            }
            
            // Yield periodically to keep UI responsive
            if i % 10 == 0 {
                await Task.yield()
            }
        }
        
        return groups
    }
}
