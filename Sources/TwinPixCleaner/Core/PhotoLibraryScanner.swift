import Foundation
import Photos
import CryptoKit
import AppKit

@MainActor
struct PhotoLibraryScanner: ImageScanner {
    let mode: ScanMode

    init(mode: ScanMode) {
        self.mode = mode
    }

    public func scan(
        in directory: URL,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async -> ScanResult {
        onProgress(0.0, "Requesting Photo Library Access...")

        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            onProgress(1.0, "Access Denied")
            return ScanResult(groups: [], skippedCount: 0)
        }

        onProgress(0.05, "Fetching assets...")

        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        let totalCount = assets.count
        if totalCount == 0 { return ScanResult(groups: [], skippedCount: 0) }

        if mode == .exact {
            return await scanExact(assets: assets, totalCount: totalCount, onProgress: onProgress)
        } else {
            return await scanSimilar(assets: assets, totalCount: totalCount, onProgress: onProgress)
        }
    }

    // MARK: - Exact Match Scanning

    private func scanExact(
        assets: PHFetchResult<PHAsset>,
        totalCount: Int,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async -> ScanResult {
        var candidates: [(url: URL, size: Int64, label: String)] = []
        var skipped = 0

        // 1. Build candidates by file size — skip iCloud-only assets that have no local resource
        for i in 0..<totalCount {
            guard !Task.isCancelled else { return ScanResult(groups: [], skippedCount: skipped) }

            let asset = assets.object(at: i)
            let resources = PHAssetResource.assetResources(for: asset)
            let photoResource = resources.first(where: { $0.type == .photo })

            guard StillImageEligibility.isComparableStillPhotoAsset(asset, resource: photoResource) else {
                skipped += 1
                continue
            }

            if let resource = photoResource {
                let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
                if size > 0 {
                    let url = PhotosAssetURL.build(for: asset.localIdentifier)
                    candidates.append((url, size, resource.originalFilename))
                } else {
                    skipped += 1
                }
            } else {
                skipped += 1
            }

            if i % 100 == 0 {
                let fraction = 0.05 + (Double(i) / Double(totalCount) * 0.1)
                onProgress(fraction, "Grouping by size: \(i)/\(totalCount)")
                await Task.yield()
            }
        }

        // 2. Group by size, then hash the raw stored bytes within each size bucket.
        // PHAsset isn't Sendable, so the hash closure re-resolves the asset from the
        // (Sendable) photos:// URL instead of capturing PHAsset objects across the boundary.
        let result = await SizeHashGrouping.group(
            candidates: candidates,
            hash: { url in await self.computeHash(forPhotoURL: url) },
            onProgress: onProgress,
            baseProgress: 0.15,
            progressSpan: 0.85
        )

        onProgress(1.0, "Complete")
        return ScanResult(groups: result.groups, skippedCount: skipped + result.skippedCount)
    }

    // MARK: - Visual Similarity Scanning

    private struct PhotoPrintCandidate: Sendable {
        let url: URL
        let localIdentifier: String
        let modificationDate: Date?
        let fileSize: Int64
    }

    private func scanSimilar(
        assets: PHFetchResult<PHAsset>,
        totalCount: Int,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async -> ScanResult {
        var candidates: [PhotoPrintCandidate] = []
        var skipped = 0

        for i in 0..<totalCount {
            guard !Task.isCancelled else { return ScanResult(groups: [], skippedCount: skipped) }

            let asset = assets.object(at: i)
            let photoResource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo })

            guard StillImageEligibility.isComparableStillPhotoAsset(asset, resource: photoResource) else {
                skipped += 1
                continue
            }

            var fileSize: Int64 = 0
            if let resource = photoResource {
                fileSize = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            }

            candidates.append(
                PhotoPrintCandidate(
                    url: PhotosAssetURL.build(for: asset.localIdentifier),
                    localIdentifier: asset.localIdentifier,
                    modificationDate: asset.modificationDate,
                    fileSize: fileSize
                )
            )

            if i % 100 == 0 {
                let fraction = 0.05 + (Double(i) / Double(totalCount) * 0.05)
                onProgress(fraction, "Preparing: \(i)/\(totalCount)")
                await Task.yield()
            }
        }

        let printResult = await computePhotoPrints(
            candidates: candidates,
            onProgress: onProgress,
            baseProgress: 0.1,
            progressSpan: 0.4
        )

        var sizeByURL: [URL: Int64] = [:]
        for c in candidates { sizeByURL[c.url] = c.fileSize }

        let prints = printResult.prints
        skipped += printResult.skipped

        if prints.isEmpty {
            onProgress(1.0, "Complete")
            return ScanResult(groups: [], skippedCount: skipped)
        }

        onProgress(0.5, "Comparing images...")

        let clusters = await FeaturePrintClustering.cluster(
            prints: prints.map { ($0.url, $0.vector) },
            threshold: AppConstants.Scan.activeThreshold(),
            onProgress: onProgress,
            baseProgress: 0.5,
            progressSpan: 0.5
        )

        let groups = clusters.map { urls -> DuplicateGroup in
            DuplicateGroup(
                hash: "visual-\(UUID().uuidString)",
                fileSize: sizeByURL[urls[0]] ?? 0,
                fileURLs: urls
            )
        }

        onProgress(1.0, "Complete")
        return ScanResult(groups: groups, skippedCount: skipped)
    }

    /// Concurrent PhotoKit decode (768 highQuality, local-only) + FeaturePrintEngine Vision/cache.
    private func computePhotoPrints(
        candidates: [PhotoPrintCandidate],
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void,
        baseProgress: Double,
        progressSpan: Double
    ) async -> (prints: [FeaturePrintEngine.Entry], skipped: Int) {
        let limit = min(
            AppConstants.Scan.maxConcurrentFeaturePrints,
            max(1, ProcessInfo.processInfo.activeProcessorCount)
        )
        let total = candidates.count
        if total == 0 { return ([], 0) }

        let maxPixel = AppConstants.Scan.featurePrintMaxPixelSize
        let counter = PhotoProgressCounter()
        var results: [FeaturePrintEngine.Entry?] = Array(repeating: nil, count: total)
        var skipped = 0

        await withTaskGroup(of: (Int, FeaturePrintEngine.Entry?).self) { group in
            var nextIndex = 0
            var inFlight = 0

            func enqueueAvailable() {
                while inFlight < limit && nextIndex < total {
                    let index = nextIndex
                    let candidate = candidates[index]
                    nextIndex += 1
                    inFlight += 1
                    group.addTask {
                        let entry = Self.featurePrint(for: candidate, maxPixel: maxPixel)
                        return (index, entry)
                    }
                }
            }

            enqueueAvailable()
            for await (index, entry) in group {
                inFlight -= 1
                if let entry {
                    results[index] = entry
                } else {
                    skipped += 1
                }

                let done = counter.increment()
                if done == total || done % 10 == 0 {
                    let fraction = baseProgress + (Double(done) / Double(total)) * progressSpan
                    onProgress(fraction, "Analyzing visually: \(done)/\(total)")
                }
                enqueueAvailable()
            }
        }

        return (results.compactMap { $0 }, skipped)
    }

    /// Background-safe: re-fetches PHAsset by id, sync PhotoKit request, then engine print/cache.
    nonisolated private static func featurePrint(
        for candidate: PhotoPrintCandidate,
        maxPixel: Int
    ) -> FeaturePrintEngine.Entry? {
        let contentKey = FeaturePrintEngine.contentKey(
            photoLocalIdentifier: candidate.localIdentifier,
            modificationDate: candidate.modificationDate
        )
        let cacheKey = FeaturePrintEngine.fullCacheKey(contentKey: contentKey)
        if let cached = FeaturePrintEngine.loadCachedVector(cacheKey: cacheKey) {
            return FeaturePrintEngine.Entry(url: candidate.url, vector: cached)
        }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [candidate.localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return nil }

        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.resizeMode = .fast
        // Never trigger iCloud downloads during a scan
        requestOptions.isNetworkAccessAllowed = false

        let target = CGSize(width: maxPixel, height: maxPixel)
        var cgImage: CGImage?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: target,
            contentMode: .aspectFit,
            options: requestOptions
        ) { image, info in
            let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            if isInCloud { return }
            cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        guard let cgImage,
              let vector = FeaturePrintEngine.vector(fromCGImage: cgImage, contentKey: contentKey) else {
            return nil
        }
        return FeaturePrintEngine.Entry(url: candidate.url, vector: vector)
    }

    /// Hashes the raw stored bytes of the photo asset file using PHAssetResourceManager.
    /// This reads the actual file bytes — NOT decoded/transcoded image data — producing
    /// a stable SHA-256 that reliably identifies bit-for-bit identical photos.
    ///
    /// Must be nonisolated: PHAssetResourceManager calls its dataReceivedHandler on
    /// com.apple.photos.assetResources.fileIO (a background queue). If this method were
    /// @MainActor-isolated, Swift would inject a queue assertion into the closure that
    /// would trap (EXC_BREAKPOINT / dispatch_assert_queue_fail).
    /// Resolves the `PHAsset` from its `photos://` URL and hashes it. Exists so the hash
    /// closure passed into `SizeHashGrouping.group` only needs to send a `URL` (Sendable)
    /// across the boundary rather than a `PHAsset` (not Sendable).
    nonisolated private func computeHash(forPhotoURL url: URL) async -> String? {
        guard let asset = PhotosAssetURL.asset(from: url) else { return nil }
        return await computeHash(for: asset)
    }

    nonisolated private func computeHash(for asset: PHAsset) async -> String? {
        guard let resource = PHAssetResource.assetResources(for: asset)
            .first(where: { $0.type == .photo }) else {
            return nil
        }

        let options = PHAssetResourceRequestOptions()
        // Never trigger iCloud downloads during a scan
        options.isNetworkAccessAllowed = false

        // Use a class to accumulate streaming chunks across two closures
        final class DataAccumulator: @unchecked Sendable {
            var chunks: [Data] = []
        }
        let accumulator = DataAccumulator()

        return await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { chunk in
                    // Called on com.apple.photos.assetResources.fileIO — must be nonisolated
                    accumulator.chunks.append(chunk)
                },
                completionHandler: { error in
                    guard error == nil, !accumulator.chunks.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    var hasher = SHA256()
                    for chunk in accumulator.chunks {
                        hasher.update(data: chunk)
                    }
                    let digest = hasher.finalize()
                    let hashString = digest.compactMap { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: hashString)
                }
            )
        }
    }
}

private final class PhotoProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
