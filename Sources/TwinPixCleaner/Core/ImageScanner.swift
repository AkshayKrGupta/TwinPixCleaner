import Foundation

/// Represents a group of mathematically or visually identical files.
public struct DuplicateGroup: Identifiable, Hashable, Sendable {
    // Derived from `hash` (which stays stable across a group's lifetime as files are
    // removed/restored) rather than a fresh random UUID, so SwiftUI can diff group rows
    // in place across edits instead of treating every edit as a full row replacement.
    public var id: String { hash }
    public let hash: String
    public let fileSize: Int64
    public let fileURLs: [URL]

    public init(hash: String, fileSize: Int64, fileURLs: [URL]) {
        self.hash = hash
        self.fileSize = fileSize
        self.fileURLs = fileURLs
    }
}

/// The outcome of a scan: the duplicate groups found, plus how many files were skipped
/// because they couldn't be read/hashed/analyzed.
public struct ScanResult: Sendable {
    public let groups: [DuplicateGroup]
    public let skippedCount: Int

    public init(groups: [DuplicateGroup], skippedCount: Int) {
        self.groups = groups
        self.skippedCount = skippedCount
    }
}

/// A protocol defining the standard interface for an image scanning engine.
/// Conforming types isolate their specific algorithms (e.g., Exact Hash or Visual ML Features),
/// allowing the presentation layer (ViewModel) to consume them via Dependency Injection.
@MainActor
public protocol ImageScanner: Sendable {

    /// Scans the provided directory and returns groups of duplicates.
    /// - Parameters:
    ///   - directory: The root URL to begin scanning from.
    ///   - onProgress: A callback closure returning the overall percentage (0.0 to 1.0) and current file/status string.
    /// - Returns: A `ScanResult` with the duplicate groups found and how many files were skipped.
    func scan(
        in directory: URL,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async throws -> ScanResult
}
