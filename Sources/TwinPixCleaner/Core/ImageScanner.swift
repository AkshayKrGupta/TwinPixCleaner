import Foundation

/// Represents a group of mathematically or visually identical files.
public struct DuplicateGroup: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let hash: String
    public let fileSize: Int64
    public let fileURLs: [URL]
    
    public init(hash: String, fileSize: Int64, fileURLs: [URL]) {
        self.hash = hash
        self.fileSize = fileSize
        self.fileURLs = fileURLs
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
    /// - Returns: An array of `DuplicateGroup`. Returning an empty array means no matches were found.
    func scan(
        in directory: URL,
        onProgress: @MainActor @Sendable @escaping (Double, String) -> Void
    ) async -> [DuplicateGroup]
}
