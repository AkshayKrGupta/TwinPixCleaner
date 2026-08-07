import Foundation
import Vision

/// Shared "group by size, then hash within each size bucket" pipeline used by both
/// `DuplicateDetector` (filesystem) and `PhotoLibraryScanner` (Apple Photos) exact-match scans.
/// Callers do their own (source-specific) size lookup and hashing; this only owns the
/// generic bucketing/grouping/progress-reporting shape so both scanners can't drift apart.
enum SizeHashGrouping {
    static func group(
        candidates: [(url: URL, size: Int64, label: String)],
        hash: @escaping @Sendable (URL) async -> String?,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void,
        baseProgress: Double,
        progressSpan: Double
    ) async -> (groups: [DuplicateGroup], skippedCount: Int) {
        var bySize: [Int64: [(url: URL, label: String)]] = [:]
        for candidate in candidates where candidate.size > 0 {
            bySize[candidate.size, default: []].append((candidate.url, candidate.label))
        }

        let potentialDuplicates = bySize.filter { $0.value.count > 1 }
        if potentialDuplicates.isEmpty {
            await onProgress(baseProgress + progressSpan, "Complete")
            return ([], 0)
        }

        var groups: [DuplicateGroup] = []
        var skipped = 0
        let totalToHash = potentialDuplicates.values.reduce(0) { $0 + $1.count }
        var hashedCount = 0

        for (size, items) in potentialDuplicates {
            guard !Task.isCancelled else { return (groups, skipped) }
            var byHash: [String: [URL]] = [:]

            for item in items {
                guard !Task.isCancelled else { return (groups, skipped) }
                hashedCount += 1
                let fraction = baseProgress + (Double(hashedCount) / Double(totalToHash)) * progressSpan
                await onProgress(fraction, item.label)

                if let h = await hash(item.url) {
                    byHash[h, default: []].append(item.url)
                } else {
                    skipped += 1
                }

                if hashedCount % 10 == 0 { await Task.yield() }
            }

            for (h, urls) in byHash where urls.count > 1 {
                groups.append(DuplicateGroup(hash: h, fileSize: size, fileURLs: urls))
            }
        }

        return (groups, skipped)
    }
}

/// Shared O(n²) feature-print clustering used by both `SimilarityDetector` (filesystem)
/// and `PhotoLibraryScanner` (Apple Photos) similarity scans: two images cluster together
/// if their Vision feature-print distance is within `threshold`.
enum FeaturePrintClustering {
    static func cluster(
        prints: [(url: URL, print: VNFeaturePrintObservation)],
        threshold: Float,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void,
        baseProgress: Double,
        progressSpan: Double
    ) async -> [[URL]] {
        var groups: [[URL]] = []
        var processedIndices = Set<Int>()

        for i in 0..<prints.count {
            guard !Task.isCancelled else { return groups }
            if processedIndices.contains(i) { continue }

            let (url1, print1) = prints[i]
            var groupURLs = [url1]
            processedIndices.insert(i)

            for j in (i + 1)..<prints.count {
                if processedIndices.contains(j) { continue }
                let (url2, print2) = prints[j]

                var distance: Float = 0
                do {
                    try print1.computeDistance(&distance, to: print2)
                    if distance <= threshold {
                        groupURLs.append(url2)
                        processedIndices.insert(j)
                    }
                } catch {
                    continue
                }
            }

            if groupURLs.count > 1 {
                groups.append(groupURLs)
            }

            if i % 10 == 0 {
                let fraction = baseProgress + (Double(processedIndices.count) / Double(prints.count)) * progressSpan
                await onProgress(fraction, "Clustering \(processedIndices.count)/\(prints.count)…")
                await Task.yield()
            }
        }

        return groups
    }
}
