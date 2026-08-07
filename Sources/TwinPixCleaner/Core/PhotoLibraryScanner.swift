import Foundation
import Photos
import CryptoKit
import Vision

#if os(macOS)
import AppKit
#endif

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

            if let resource = resources.first(where: { $0.type == .photo }) {
                let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
                if size > 0 {
                    let url = buildPhotoURL(for: asset.localIdentifier)
                    candidates.append((url, size, resource.originalFilename))
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

    private func scanSimilar(
        assets: PHFetchResult<PHAsset>,
        totalCount: Int,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async -> ScanResult {
        var prints: [(url: URL, print: VNFeaturePrintObservation)] = []
        var sizeByURL: [URL: Int64] = [:]
        var skipped = 0
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .fast
        // FIX: Do not silently download iCloud-only assets
        requestOptions.isNetworkAccessAllowed = false

        let targetSize = CGSize(width: 256, height: 256)

        for i in 0..<totalCount {
            guard !Task.isCancelled else { return ScanResult(groups: [], skippedCount: skipped) }

            let asset = assets.object(at: i)

            var fileSize: Int64 = 0
            if let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo }) {
                fileSize = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            }

            let fraction = 0.05 + (Double(i) / Double(totalCount) * 0.4)
            onProgress(fraction, "Analyzing visually: \(i)/\(totalCount)")

            let cgImage = await withCheckedContinuation { continuation in
                imageManager.requestImage(
                    for: asset, targetSize: targetSize, contentMode: .aspectFit, options: requestOptions
                ) { image, info in
                    // Skip assets not available locally (iCloud-only)
                    let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    if isInCloud {
                        continuation.resume(returning: nil as CGImage?)
                        return
                    }
                    continuation.resume(returning: image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                }
            }

            if let cgImage = cgImage {
                let request = VNGenerateImageFeaturePrintRequest()
                request.revision = VNGenerateImageFeaturePrintRequestRevision1
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                    if let featurePrint = request.results?.first as? VNFeaturePrintObservation {
                        let url = buildPhotoURL(for: asset.localIdentifier)
                        prints.append((url: url, print: featurePrint))
                        sizeByURL[url] = fileSize
                    } else {
                        skipped += 1
                    }
                } catch {
                    print("Failed to compute print for \(asset.localIdentifier)")
                    skipped += 1
                }
            } else {
                skipped += 1
            }

            if i % 10 == 0 { await Task.yield() }
        }

        onProgress(0.5, "Comparing images...")

        let threshold = AppConstants.Scan.similarityThreshold
        let clusters = await FeaturePrintClustering.cluster(
            prints: prints,
            threshold: threshold,
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
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let idItem = components.queryItems?.first(where: { $0.name == "id" }),
              let localIdentifier = idItem.value else {
            return nil
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
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

    nonisolated private func buildPhotoURL(for localIdentifier: String) -> URL {
        var components = URLComponents()
        components.scheme = "photos"
        components.host = "asset"
        components.queryItems = [URLQueryItem(name: "id", value: localIdentifier)]
        // Fallback is a static, always-valid literal — the dynamic localIdentifier is the
        // only part that could theoretically fail percent-encoding, so this never masks a
        // real per-asset failure, it just avoids a force-unwrap crash if it ever did.
        return components.url ?? URL(string: "photos://asset")!
    }
}
