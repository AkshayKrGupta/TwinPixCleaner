import Foundation

/// `SimilarityDetector` implements `ImageScanner` to find visually similar, but not identical, images.
/// Uses `FeaturePrintEngine` (Vision Rev2/Rev1 + disk cache) and union-find clustering.
/// Screenshots stay in the scan but use a stricter threshold in a separate cluster pool.
public struct SimilarityDetector: ImageScanner {

    /// Distance threshold determining how "different" images can be to still be considered similar.
    public let threshold: Float

    public init(threshold: Float = AppConstants.Scan.activeThreshold()) {
        self.threshold = threshold
    }

    public func scan(
        in directory: URL,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void = { _, _ in }
    ) async throws -> ScanResult {
        return try await Task.detached {
            await onProgress(0.0, "Scanning folder…")
            let files = try FileScanner.scan(directory: directory)
            if files.isEmpty { return ScanResult(groups: [], skippedCount: 0) }

            // No silent cap — concurrency + ImageIO thumbnails bound memory.
            let printResult = await FeaturePrintEngine.computeFilePrints(
                urls: files,
                onProgress: onProgress,
                baseProgress: 0.0,
                progressSpan: 0.8
            )

            let prints = printResult.prints.map {
                ($0.url, $0.vector, StillImageEligibility.isScreenshotFile($0.url))
            }
            let skipped = printResult.skipped

            if prints.isEmpty { return ScanResult(groups: [], skippedCount: skipped) }

            await onProgress(0.8, "Comparing images…")
            let clusters = await FeaturePrintClustering.clusterSeparatingScreenshots(
                prints: prints,
                photoThreshold: threshold,
                screenshotThreshold: AppConstants.Scan.activeScreenshotThreshold(),
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
