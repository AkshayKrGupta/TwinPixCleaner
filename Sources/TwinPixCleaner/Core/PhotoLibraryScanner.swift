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
    ) async -> [DuplicateGroup] {
        onProgress(0.0, "Requesting Photo Library Access...")
        
        // Wait for authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else {
            onProgress(1.0, "Access Denied")
            return []
        }
        
        onProgress(0.05, "Fetching assets...")
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = false
        // Only images for now
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        let totalCount = assets.count
        if totalCount == 0 {
            return []
        }
        
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
    ) async -> [DuplicateGroup] {
        var assetsBySize: [Int64: [PHAsset]] = [:]
        
        // 1. Group by file size
        for i in 0..<totalCount {
            let asset = assets.object(at: i)
            let resources = PHAssetResource.assetResources(for: asset)
            
            // Try to find the original photo resource
            if let resource = resources.first(where: { $0.type == .photo }) {
                // Use KVC to get file size, fallback to 0 if not accessible
                let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
                if size > 0 {
                    assetsBySize[size, default: []].append(asset)
                }
            }
            
            if i % 100 == 0 {
                let fraction = 0.05 + (Double(i) / Double(totalCount) * 0.1)
                onProgress(fraction, "Grouping by size: \(i)/\(totalCount)")
                await Task.yield()
            }
        }
        
        let potentialDuplicates = assetsBySize.filter { $0.value.count > 1 }
        
        if potentialDuplicates.isEmpty {
            onProgress(1.0, "Complete")
            return []
        }
        
        // 2. Hash potential duplicates
        var duplicates: [DuplicateGroup] = []
        let totalToHash = potentialDuplicates.values.map { $0.count }.reduce(0, +)
        var hashedCount = 0
        
        for (size, assetGroup) in potentialDuplicates {
            var assetsByHash: [String: [URL]] = [:]
            
            for asset in assetGroup {
                hashedCount += 1
                let fraction = 0.15 + (Double(hashedCount) / Double(totalToHash) * 0.85)
                onProgress(fraction, "Hashing asset \(hashedCount)/\(totalToHash)")
                
                if let hash = await computeHash(for: asset) {
                    let url = buildPhotoURL(for: asset.localIdentifier)
                    assetsByHash[hash, default: []].append(url)
                }
            }
            
            for (hash, urls) in assetsByHash where urls.count > 1 {
                duplicates.append(DuplicateGroup(hash: hash, fileSize: size, fileURLs: urls))
            }
        }
        
        onProgress(1.0, "Complete")
        return duplicates
    }
    
    // MARK: - Visual Similarity Scanning
    private func scanSimilar(
        assets: PHFetchResult<PHAsset>,
        totalCount: Int,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async -> [DuplicateGroup] {
        var prints: [(url: URL, print: VNFeaturePrintObservation, size: Int64)] = []
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .fastFormat // Small thumbnail is fine
        requestOptions.resizeMode = .fast
        requestOptions.isNetworkAccessAllowed = true
        
        let targetSize = CGSize(width: 256, height: 256)
        
        for i in 0..<totalCount {
            let asset = assets.object(at: i)
            
            var fileSize: Int64 = 0
            if let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .photo }) {
                fileSize = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            }
            
            let fraction = 0.05 + (Double(i) / Double(totalCount) * 0.4)
            onProgress(fraction, "Analyzing visually: \(i)/\(totalCount)")
            
            let cgImage = await withCheckedContinuation { continuation in
                imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: requestOptions) { image, _ in
                    continuation.resume(returning: image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                }
            }
            
            if let cgImage = cgImage {
                let request = VNGenerateImageFeaturePrintRequest()
                request.revision = VNGenerateImageFeaturePrintRequestRevision1
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                do {
                    try handler.perform([request])
                    if let print = request.results?.first as? VNFeaturePrintObservation {
                        let url = buildPhotoURL(for: asset.localIdentifier)
                        prints.append((url: url, print: print, size: fileSize))
                    }
                } catch {
                    print("Failed to compute print for \(asset.localIdentifier)")
                }
            }
            
            if i % 10 == 0 { await Task.yield() }
        }
        
        onProgress(0.5, "Comparing images...")
        
        var duplicates: [DuplicateGroup] = []
        var processedIndices = Set<Int>()
        let threshold: Float = 8.0
        
        for i in 0..<prints.count {
            if processedIndices.contains(i) { continue }
            
            let featureA = prints[i]
            var groupURLs = [featureA.url]
            processedIndices.insert(i)
            
            for j in (i + 1)..<prints.count {
                if processedIndices.contains(j) { continue }
                
                let featureB = prints[j]
                
                var distance: Float = 0
                do {
                    try featureA.print.computeDistance(&distance, to: featureB.print)
                    if distance <= threshold {
                        groupURLs.append(featureB.url)
                        processedIndices.insert(j)
                    }
                } catch {
                    continue
                }
            }
            
            if groupURLs.count > 1 {
                duplicates.append(DuplicateGroup(
                    hash: "visual-\(UUID().uuidString)",
                    fileSize: featureA.size,
                    fileURLs: groupURLs
                ))
            }
            
            if i % 50 == 0 {
                let fraction = 0.5 + (Double(i) / Double(prints.count) * 0.5)
                onProgress(fraction, "Grouping similar matches...")
                await Task.yield()
            }
        }
        
        onProgress(1.0, "Complete")
        return duplicates
    }
    
    // MARK: - Helpers
    
    private func computeHash(for asset: PHAsset) async -> String? {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        return await withCheckedContinuation { continuation in
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if let data = data {
                    let hash = SHA256.hash(data: data)
                    continuation.resume(returning: hash.compactMap { String(format: "%02x", $0) }.joined())
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func buildPhotoURL(for localIdentifier: String) -> URL {
        var components = URLComponents()
        components.scheme = "photos"
        components.host = "asset"
        components.queryItems = [URLQueryItem(name: "id", value: localIdentifier)]
        return components.url!
    }
}
