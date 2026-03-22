import Foundation

/// Defines all possible errors that can occur during the execution of TwinPixCleaner.
/// Conforms to `LocalizedError` to provide user-facing error descriptions for SwiftUI alerts.
public enum AppError: Error, LocalizedError, Equatable {
    
    /// Thrown when directory traversal fails or user selects an invalid folder.
    case unreadableDirectory(URL)
    
    /// Thrown when an individual file deletion to the macOS Trash fails.
    case deletionFailed(URL, String)
    
    /// Thrown when multiple file deletions fail.
    case multipleDeletionsFailed([String])
    
    /// Thrown when attempting to undo a deletion fails.
    case restorationFailed(URL, String)
    
    /// Thrown when a background scan operation is cancelled.
    case scanCancelled
    
    /// Generic unknown error fallback.
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .unreadableDirectory(let url):
            return "Could not read the directory at \(url.path). Ensure you have necessary permissions."
        case .deletionFailed(let url, let reason):
            return "Failed to move \(url.lastPathComponent) to Trash: \(reason)"
        case .multipleDeletionsFailed(let files):
            return "Failed to delete \(files.count) file(s): \(files.joined(separator: ", "))"
        case .restorationFailed(let url, let reason):
            return "Failed to restore \(url.lastPathComponent) from Trash: \(reason)"
        case .scanCancelled:
            return "The scan operation was cancelled."
        case .unknown(let details):
            return "An unrecoverable error occurred: \(details)"
        }
    }
}
