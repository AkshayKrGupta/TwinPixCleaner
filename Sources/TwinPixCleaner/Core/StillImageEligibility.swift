import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

/// Shared rules for which assets may enter exact/similarity compare pipelines.
/// Still photos only — no GIF/video/animated multi-frame.
enum StillImageEligibility {

    /// Extensions allowed for folder scans (still images).
    static let allowedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "bmp", "webp"
    ]

    private static let animatedFilenameExtensions: Set<String> = ["gif"]

    // MARK: - Folder / file URLs

    static func isComparableStillImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { return false }
        // Animated WebP — skip multi-frame containers.
        if ext == "webp", imageSourceFrameCount(url) > 1 {
            return false
        }
        return true
    }

    /// Filename heuristic for folder scans (Photos uses `mediaSubtypes` instead).
    static func isScreenshotFile(_ url: URL) -> Bool {
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        if name.hasPrefix("screenshot") { return true }
        if name.hasPrefix("screen shot") { return true }
        if name.contains("screenshot") { return true }
        return false
    }

    // MARK: - Photos library

    static func isComparableStillPhotoAsset(_ asset: PHAsset, resource: PHAssetResource?) -> Bool {
        if asset.playbackStyle == .imageAnimated || asset.playbackStyle == .video {
            return false
        }
        guard let resource else { return true }

        let filename = resource.originalFilename.lowercased()
        let ext = (filename as NSString).pathExtension
        if animatedFilenameExtensions.contains(ext) { return false }

        let uti = resource.uniformTypeIdentifier
        let utiLower = uti.lowercased()
        if utiLower.contains("gif") || utiLower.contains("image.animated") {
            return false
        }
        if let type = UTType(uti), type.conforms(to: .audiovisualContent) {
            return false
        }
        return true
    }

    static func isScreenshotPhotoAsset(_ asset: PHAsset) -> Bool {
        asset.mediaSubtypes.contains(.photoScreenshot)
    }

    // MARK: - Helpers

    private static func imageSourceFrameCount(_ url: URL) -> Int {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return 1 }
        return CGImageSourceGetCount(source)
    }
}
