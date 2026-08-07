import Foundation
import Vision
import AppKit

/// `SimilarityDetector` implements `ImageScanner` to find visually similar, but not identical, images.
/// It uses Apple's Vision framework to compute ML feature prints and groups images based on a distance threshold.
public struct SimilarityDetector: ImageScanner {

    /// Distance threshold determining how "different" images can be to still be considered similar.
    /// A typical value is 8.0 to 15.0 for moderate similarity.
    public let threshold: Float

    public init(threshold: Float = AppConstants.Scan.similarityThreshold) {
        self.threshold = threshold
    }

    nonisolated private func computeFeaturePrint(for url: URL) -> VNFeaturePrintObservation? {
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
    ) async throws -> ScanResult {
        return try await Task.detached {
            await onProgress(0.0, "Scanning folder…")
            let files = try FileScanner.scan(directory: directory)
            if files.isEmpty { return ScanResult(groups: [], skippedCount: 0) }

            // Limit to prevent crashes with large libraries
            let maxFiles = 500
            let filesToProcess = files.count > maxFiles ? Array(files.prefix(maxFiles)) : files

            var prints: [(url: URL, print: VNFeaturePrintObservation)] = []
            var skipped = 0

            // 1. Compute feature prints in batches (~0–80% of progress)
            let batchSize = 50
            var processedCount = 0

            for batchStart in stride(from: 0, to: filesToProcess.count, by: batchSize) {
                guard !Task.isCancelled else { return ScanResult(groups: [], skippedCount: skipped) }
                let batchEnd = min(batchStart + batchSize, filesToProcess.count)
                let batch = Array(filesToProcess[batchStart..<batchEnd])

                for file in batch {
                    processedCount += 1
                    let fraction = Double(processedCount) / Double(filesToProcess.count) * 0.8
                    await onProgress(fraction, file.lastPathComponent)

                    autoreleasepool {
                        if let print = computeFeaturePrint(for: file) {
                            prints.append((file, print))
                        } else {
                            skipped += 1
                        }
                    }
                }

                // Yield to prevent blocking
                await Task.yield()
            }

            if prints.isEmpty { return ScanResult(groups: [], skippedCount: skipped) }

            // 2. Cluster images (~80–100% of progress)
            await onProgress(0.8, "Comparing images…")
            let clusters = await FeaturePrintClustering.cluster(
                prints: prints,
                threshold: threshold,
                onProgress: onProgress,
                baseProgress: 0.8,
                progressSpan: 0.2
            )

            let groups = clusters.map { urls -> DuplicateGroup in
                let totalSize = urls.reduce(0) { $0 + (ImageHasher.getFileSize(for: $1) ?? 0) }
                let avgSize = totalSize / Int64(urls.count)
                return DuplicateGroup(
                    hash: "SIMILAR-" + UUID().uuidString,
                    fileSize: avgSize,
                    fileURLs: urls
                )
            }

            await onProgress(1.0, "Complete")
            return ScanResult(groups: groups, skippedCount: skipped)
        }.value
    }
}
