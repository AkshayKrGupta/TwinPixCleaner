import Foundation

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

/// Union-find over Accelerate L2 distances. Transitive near-duplicates (A~B, B~C) form one group.
enum FeaturePrintClustering {

    struct UnionFind {
        private var parent: [Int]
        private var rank: [Int]

        init(count: Int) {
            parent = Array(0..<count)
            rank = Array(repeating: 0, count: count)
        }

        mutating func find(_ x: Int) -> Int {
            if parent[x] != x {
                parent[x] = find(parent[x])
            }
            return parent[x]
        }

        mutating func union(_ a: Int, _ b: Int) {
            let ra = find(a)
            let rb = find(b)
            if ra == rb { return }
            if rank[ra] < rank[rb] {
                parent[ra] = rb
            } else if rank[ra] > rank[rb] {
                parent[rb] = ra
            } else {
                parent[rb] = ra
                rank[ra] += 1
            }
        }
    }

    static func cluster(
        prints: [(url: URL, vector: [Float])],
        threshold: Float,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void,
        baseProgress: Double,
        progressSpan: Double
    ) async -> [[URL]] {
        let n = prints.count
        guard n > 1 else { return [] }

        var uf = UnionFind(count: n)
        let totalPairs = n * (n - 1) / 2
        var compared = 0
        let yieldEvery = max(1, min(10_000, totalPairs / 50))

        for i in 0..<n {
            guard !Task.isCancelled else { break }
            let vi = prints[i].vector
            for j in (i + 1)..<n {
                let vj = prints[j].vector
                guard vi.count == vj.count, !vi.isEmpty else {
                    compared += 1
                    continue
                }
                if FeaturePrintEngine.l2Distance(vi, vj) <= threshold {
                    uf.union(i, j)
                }
                compared += 1
                if compared % yieldEvery == 0 {
                    // Progress bar tracks pair work; label stays in photo units (not n² pair counts).
                    let fraction = baseProgress + (Double(compared) / Double(totalPairs)) * progressSpan
                    await onProgress(fraction, "Clustering \(i + 1)/\(n)…")
                    await Task.yield()
                }
            }
        }

        var buckets: [Int: [URL]] = [:]
        for i in 0..<n {
            let root = uf.find(i)
            buckets[root, default: []].append(prints[i].url)
        }
        return buckets.values.filter { $0.count > 1 }
    }
}
