import Foundation
import Vision
import ImageIO
import CoreGraphics
import Accelerate
import CryptoKit

/// Shared on-device Vision feature-print pipeline for folder and Photos similarity scans.
/// ImageIO thumbnail decode → Rev2 (macOS 14+) / Rev1 → disk cache → Accelerate L2.
enum FeaturePrintEngine {

    struct Entry: Sendable {
        let url: URL
        let vector: [Float]
    }

    // MARK: - Revision / threshold helpers

    static var activeRevision: Int {
        if #available(macOS 14.0, *) {
            return Int(VNGenerateImageFeaturePrintRequestRevision2)
        }
        return Int(VNGenerateImageFeaturePrintRequestRevision1)
    }

    // MARK: - Disk cache

    static func cacheDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base
            .appendingPathComponent("TwinPixCleaner", isDirectory: true)
            .appendingPathComponent("feature-prints", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cacheFileURL(forCacheKey key: String) throws -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return try cacheDirectory().appendingPathComponent(name, isDirectory: false)
    }

    static func fullCacheKey(contentKey: String) -> String {
        "\(contentKey)|\(activeRevision)|\(AppConstants.Scan.featurePrintMaxPixelSize)"
    }

    static func contentKey(forFileURL url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return nil
        }
        let mtime = values.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = values.fileSize ?? 0
        return "\(url.path)|\(mtime)|\(size)"
    }

    static func contentKey(photoLocalIdentifier: String, modificationDate: Date?) -> String {
        let mtime = modificationDate?.timeIntervalSince1970 ?? 0
        return "\(photoLocalIdentifier)|\(mtime)"
    }

    static func loadCachedVector(cacheKey: String) -> [Float]? {
        guard let fileURL = try? cacheFileURL(forCacheKey: cacheKey),
              let data = try? Data(contentsOf: fileURL),
              data.count >= MemoryLayout<Float>.size,
              data.count % MemoryLayout<Float>.size == 0 else {
            return nil
        }
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
    }

    static func storeCachedVector(_ vector: [Float], cacheKey: String) {
        guard !vector.isEmpty,
              let fileURL = try? cacheFileURL(forCacheKey: cacheKey) else { return }
        vector.withUnsafeBufferPointer { buf in
            let data = Data(buffer: buf)
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Completely removes all cached feature prints from disk.
    @discardableResult
    static func clearCache() -> Bool {
        guard let dir = try? cacheDirectory() else { return false }
        do {
            try FileManager.default.removeItem(at: dir)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// Prunes cached feature print files older than `maxAgeDays` (default 30 days).
    static func pruneCache(maxAgeDays: Int = 30) {
        guard let dir = try? cacheDirectory() else { return }
        let cutoff = Date().addingTimeInterval(-Double(maxAgeDays * 24 * 3600))
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        for file in files {
            if let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
               let mdate = values.contentModificationDate,
               mdate < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Decode

    static func decodeThumbnail(url: URL, maxPixel: Int = AppConstants.Scan.featurePrintMaxPixelSize) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return thumbnail
    }

    // MARK: - Vision

    static func makeFeaturePrintRequest() -> VNGenerateImageFeaturePrintRequest {
        let request = VNGenerateImageFeaturePrintRequest()
        if #available(macOS 14.0, *) {
            request.revision = VNGenerateImageFeaturePrintRequestRevision2
        } else {
            request.revision = VNGenerateImageFeaturePrintRequestRevision1
        }
        // Do not set usesCPUOnly — allow ANE on Apple Silicon.
        return request
    }

    static func computeVector(from cgImage: CGImage) -> [Float]? {
        let request = makeFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNFeaturePrintObservation,
                  observation.elementType == .float,
                  observation.elementCount > 0 else {
                return nil
            }
            let count = observation.elementCount
            return observation.data.withUnsafeBytes { raw in
                Array(raw.bindMemory(to: Float.self).prefix(count))
            }
        } catch {
            return nil
        }
    }

    /// Cache-aware vector for a filesystem image URL (ImageIO → Vision).
    static func vector(forFileURL url: URL) -> [Float]? {
        autoreleasepool {
            guard let content = contentKey(forFileURL: url) else { return nil }
            let key = fullCacheKey(contentKey: content)
            if let cached = loadCachedVector(cacheKey: key) {
                return cached
            }
            guard let cgImage = decodeThumbnail(url: url),
                  let vector = computeVector(from: cgImage) else {
                return nil
            }
            storeCachedVector(vector, cacheKey: key)
            return vector
        }
    }

    /// Cache-aware vector from an already-decoded image (Photos path).
    static func vector(fromCGImage cgImage: CGImage, contentKey: String) -> [Float]? {
        autoreleasepool {
            let key = fullCacheKey(contentKey: contentKey)
            if let cached = loadCachedVector(cacheKey: key) {
                return cached
            }
            guard let vector = computeVector(from: cgImage) else { return nil }
            storeCachedVector(vector, cacheKey: key)
            return vector
        }
    }

    // MARK: - Concurrent file prints

    static func computeFilePrints(
        urls: [URL],
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void,
        baseProgress: Double,
        progressSpan: Double
    ) async -> (prints: [Entry], skipped: Int) {
        let limit = min(
            AppConstants.Scan.maxConcurrentFeaturePrints,
            max(1, ProcessInfo.processInfo.activeProcessorCount)
        )
        let total = urls.count
        if total == 0 { return ([], 0) }

        let counter = ProgressCounter()
        var results: [Entry?] = Array(repeating: nil, count: total)
        var skipped = 0

        await withTaskGroup(of: (Int, Entry?).self) { group in
            var nextIndex = 0
            var inFlight = 0

            func enqueueAvailable() {
                while inFlight < limit && nextIndex < total {
                    let index = nextIndex
                    let url = urls[index]
                    nextIndex += 1
                    inFlight += 1
                    group.addTask {
                        let vector = vector(forFileURL: url)
                        let entry = vector.map { Entry(url: url, vector: $0) }
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
                    let label = urls[index].lastPathComponent
                    await onProgress(fraction, label)
                }

                enqueueAvailable()
            }
        }

        return (results.compactMap { $0 }, skipped)
    }

    // MARK: - Distance

    /// Euclidean L2 distance between two equal-length float feature prints (Accelerate).
    static func l2Distance(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count && !a.isEmpty)
        var distanceSquared: Float = 0
        vDSP_distancesq(a, 1, b, 1, &distanceSquared, vDSP_Length(a.count))
        return sqrtf(distanceSquared)
    }
}

// MARK: - Progress helper

private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
