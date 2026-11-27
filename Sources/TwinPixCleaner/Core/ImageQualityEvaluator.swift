import Foundation
import ImageIO
import Photos

/// Represents metadata used to assess and compare image quality.
public struct ImageQualityInfo: Comparable, Sendable {
    public let url: URL
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let fileSize: Int64
    public let bitDepth: Int
    public let hasExif: Bool
    public let formatTier: Int
    public let creationDate: Date?

    public var pixelCount: Int64 {
        Int64(pixelWidth) * Int64(pixelHeight)
    }

    public init(
        url: URL,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        fileSize: Int64 = 0,
        bitDepth: Int = 8,
        hasExif: Bool = false,
        formatTier: Int = 0,
        creationDate: Date? = nil
    ) {
        self.url = url
        self.pixelWidth = max(0, pixelWidth)
        self.pixelHeight = max(0, pixelHeight)
        self.fileSize = max(0, fileSize)
        self.bitDepth = max(0, bitDepth)
        self.hasExif = hasExif
        self.formatTier = formatTier
        self.creationDate = creationDate
    }

    /// Compares two images to determine which is higher quality.
    /// Returns true if `lhs` is lower quality than `rhs` (so `.max()` yields the highest quality).
    ///
    /// Comparison hierarchy:
    /// 1. Resolution / Pixel count (higher is better).
    /// 2. Color bit depth (e.g. 10/12/16-bit HDR/RAW > 8-bit SDR).
    /// 3. Format tier (RAW / Lossless > Modern HEIC > Legacy Lossy JPEG).
    /// 4. EXIF metadata presence (original with camera/GPS metadata > stripped copy).
    /// 5. File size in bytes (larger file preserves higher bitrate / less lossy compression).
    /// 6. Capture/Creation date (older original is preferred over newer copies / exports).
    /// 7. Deterministic tie-breaker by absolute URL string.
    public static func < (lhs: ImageQualityInfo, rhs: ImageQualityInfo) -> Bool {
        // 1. Resolution / Pixel count
        if lhs.pixelCount != rhs.pixelCount {
            return lhs.pixelCount < rhs.pixelCount
        }

        // 2. Color Bit Depth (e.g. 10/12/16-bit > 8-bit)
        if lhs.bitDepth != rhs.bitDepth {
            return lhs.bitDepth < rhs.bitDepth
        }

        // 3. Format tier (RAW/Lossless > Lossy)
        if lhs.formatTier != rhs.formatTier {
            return lhs.formatTier < rhs.formatTier
        }

        // 4. EXIF metadata preservation (camera info / GPS > stripped)
        if lhs.hasExif != rhs.hasExif {
            return !lhs.hasExif && rhs.hasExif
        }

        // 5. File size (larger file preserves higher quality / bit depth / metadata)
        if lhs.fileSize != rhs.fileSize {
            return lhs.fileSize < rhs.fileSize
        }

        // 6. Creation date (earlier date preferred as original)
        if let dateL = lhs.creationDate, let dateR = rhs.creationDate {
            if dateL != dateR {
                return dateL > dateR
            }
        } else if lhs.creationDate != rhs.creationDate {
            // Known date is preferred over unknown date
            return lhs.creationDate == nil
        }

        // 7. Deterministic tie-breaker (works for both filesystem and photos:// URLs)
        return lhs.url.absoluteString > rhs.url.absoluteString
    }
}

/// Evaluates image quality attributes (resolution, bit depth, format, metadata, file size, capture date)
/// for intelligent duplicate resolution.
public enum ImageQualityEvaluator {

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// Format quality tier: RAW (4) > Lossless PNG/TIFF (3) > Modern HEIC (2) > Standard JPEG/WebP (1).
    public static func formatTier(for url: URL) -> Int {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "dng", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2":
            return 4
        case "tiff", "tif", "png":
            return 3
        case "heic", "heif":
            return 2
        case "jpg", "jpeg", "webp", "bmp":
            return 1
        default:
            return 0
        }
    }

    /// Reads quality attributes from a file or Photos asset URL without loading full image pixels into memory.
    public static func evaluate(url: URL) -> ImageQualityInfo {
        if url.scheme == "photos" {
            guard let asset = PhotosAssetURL.asset(from: url) else {
                return ImageQualityInfo(url: url)
            }
            let width = asset.pixelWidth
            let height = asset.pixelHeight
            let resources = PHAssetResource.assetResources(for: asset)
            let photoResource = resources.first { $0.type == .photo } ?? resources.first
            let size = (photoResource?.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0
            let isRaw = photoResource?.uniformTypeIdentifier.lowercased().contains("raw") == true
            let formatTier = isRaw ? 4 : 2

            return ImageQualityInfo(
                url: url,
                pixelWidth: width,
                pixelHeight: height,
                fileSize: size,
                bitDepth: 8,
                hasExif: true,
                formatTier: formatTier,
                creationDate: asset.creationDate
            )
        }

        // Standard filesystem URL
        let resolvedURL = url.resolvingSymlinksInPath()

        var fileSize: Int64 = 0
        if let values = try? resolvedURL.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
            fileSize = Int64(size)
        } else if let attr = try? FileManager.default.attributesOfItem(atPath: resolvedURL.path), let size = attr[.size] as? Int64 {
            fileSize = size
        }

        var creationDate: Date? = nil
        if let values = try? resolvedURL.resourceValues(forKeys: [.creationDateKey]), let date = values.creationDate {
            creationDate = date
        } else if let attr = try? FileManager.default.attributesOfItem(atPath: resolvedURL.path), let date = attr[.creationDate] as? Date {
            creationDate = date
        }

        var width: Int = 0
        var height: Int = 0
        var bitDepth: Int = 8
        var hasExif = false

        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]

        if let source = CGImageSourceCreateWithURL(resolvedURL as CFURL, sourceOptions as CFDictionary),
           let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {

            // Top-level dimensions
            width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
            height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0

            // Bit depth (e.g. 8, 10, 12, 16)
            if let depth = (properties[kCGImagePropertyDepth] as? NSNumber)?.intValue, depth > 0 {
                bitDepth = depth
            }

            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
            let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

            // Fallback dimensions from EXIF dictionary if top-level dimensions were missing
            if (width == 0 || height == 0), let exif {
                width = (exif[kCGImagePropertyExifPixelXDimension] as? NSNumber)?.intValue ?? width
                height = (exif[kCGImagePropertyExifPixelYDimension] as? NSNumber)?.intValue ?? height
            }

            // Check if genuine camera EXIF or GPS metadata exists
            if (exif != nil && !exif!.isEmpty) || (gps != nil && !gps!.isEmpty) {
                hasExif = true
            }

            // Prefer EXIF/TIFF capture date over filesystem date (e.g. preserves date when file was copied)
            if let dateString = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
                ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String),
               let parsedDate = exifDateFormatter.date(from: dateString) {
                creationDate = parsedDate
            }
        }

        return ImageQualityInfo(
            url: url,
            pixelWidth: width,
            pixelHeight: height,
            fileSize: fileSize,
            bitDepth: bitDepth,
            hasExif: hasExif,
            formatTier: formatTier(for: resolvedURL),
            creationDate: creationDate
        )
    }

    /// Selects the highest quality image URL from a collection.
    public static func bestQualityURL(in urls: [URL]) -> URL? {
        guard !urls.isEmpty else { return nil }
        guard urls.count > 1 else { return urls.first }
        return urls.map { evaluate(url: $0) }.max()?.url
    }
}
