import Foundation
import Vision
import AppKit

/// `SimilarityDetector` implements `ImageScanner` to find visually similar, but not identical, images.
/// It uses Apple's Vision framework to compute ML feature prints and groups images based on a distance threshold.
public struct SimilarityDetector: ImageScanner {
    
    /// Distance threshold determining how "different" images can be to still be considered similar.
    /// A typical value is 8.0 to 15.0 for moderate similarity.
    public let threshold: Float
    
    public init(threshold: Float = 8.0) {
        self.threshold = threshold
    }
    
    private func computeFeaturePrint(for url: URL) -> VNFeaturePrintObservation? {
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
    
    public func scan(
        in directory: URL,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void = { _, _ in }
    ) async -> [DuplicateGroup] {
        onProgress(0.0, "Scanning folder…")
        let files = FileScanner.scan(directory: directory)
        if files.isEmpty { return [] }
        
        // Limit to prevent crashes with large libraries
        let maxFiles = 500
        let filesToProcess = files.count > maxFiles ? Array(files.prefix(maxFiles)) : files
        
        var prints: [(URL, VNFeaturePrintObservation)] = []
        
        // 1. Compute feature prints in batches (~0–80% of progress)
        let batchSize = 50
        var processedCount = 0
        
        for batchStart in stride(from: 0, to: filesToProcess.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, filesToProcess.count)
            let batch = Array(filesToProcess[batchStart..<batchEnd])
            
            for file in batch {
                processedCount += 1
                let fraction = Double(processedCount) / Double(filesToProcess.count) * 0.8
                onProgress(fraction, file.lastPathComponent)
                
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
        
        // 2. Cluster images (~80–100% of progress)
        onProgress(0.8, "Comparing images…")
        
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
            
            // Report clustering progress and yield periodically
            if i % 10 == 0 {
                let fraction = 0.8 + (Double(processedIndices.count) / Double(prints.count)) * 0.2
                onProgress(fraction, "Clustering \(processedIndices.count)/\(prints.count)…")
                await Task.yield()
            }
        }
        
        onProgress(1.0, "Complete")
        return groups
    }
}
