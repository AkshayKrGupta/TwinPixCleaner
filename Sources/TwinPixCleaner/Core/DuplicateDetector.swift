import Foundation

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
    ) async throws -> ScanResult {
        return try await Task.detached {
            // 1. Scan for files
            await onProgress(0.0, "Scanning folder…")
            let files = try FileScanner.scan(directory: directory)

            if files.isEmpty {
                return ScanResult(groups: [], skippedCount: 0)
            }

            // 2. Build candidates by size (fast pass — ~10% of progress)
            var candidates: [(url: URL, size: Int64, label: String)] = []
            var skipped = 0
            for (index, file) in files.enumerated() {
                guard !Task.isCancelled else { return ScanResult(groups: [], skippedCount: skipped) }
                if let size = ImageHasher.getFileSize(for: file) {
                    candidates.append((file, size, file.lastPathComponent))
                } else {
                    skipped += 1
                }
                if index % 50 == 0 {
                    let fraction = Double(index) / Double(files.count) * 0.1
                    await onProgress(fraction, file.lastPathComponent)
                }
            }

            // 3. Group by size, then hash within each size bucket (~10%–100% of progress)
            let result = await SizeHashGrouping.group(
                candidates: candidates,
                hash: { url in ImageHasher.computeHash(for: url) },
                onProgress: onProgress,
                baseProgress: 0.1,
                progressSpan: 0.9
            )

            await onProgress(1.0, "Complete")
            return ScanResult(groups: result.groups, skippedCount: skipped + result.skippedCount)
        }.value
    }
}
