import Foundation
import SwiftUI

/// Centralized constants for the entire TwinPixCleaner application.
/// Using this enum prevents hardcoded magic strings and allows for easy updates/localization.
public enum AppConstants {
    
    /// User-facing text strings
    public enum Strings {
        public static let appName = "TwinPixCleaner"
        public static let aboutDescription = "A smart duplicate photo finder for macOS"
        public static let developerName = "Akshay K Gupta"
        public static let linkedinURL = "https://www.linkedin.com/in/akshay-kr-gupta/"
        
        public static let exactMatchName = "Exact Match"
        public static let exactMatchDesc = "Finds files that are bit-for-bit identical. Safe to delete any copy."
        public static let similarMatchName = "Visual Similarity"
        public static let similarMatchDesc = "Finds images that look similar but may have differences (size, format, edits)."
        
        public static let newScan = "New Scan"
        public static let cancelScan = "Cancel Scan"
        public static let selectFolder = "Select Folder to Scan"
        public static let dragDropPrompt = "or drag and drop a folder here"
        
        public static let scanningTitle = "Scanning for Duplicates"
        public static let exactScanProgress = "Exact Scan in Progress"
        public static let similarScanProgress = "Similarity Scan in Progress"
        public static let scanComplete = "%d%% Complete"
        
        public static let deleteSelected = "Delete"
        public static let keepThis = "Keep This"
        public static let trash = "Trash"
        public static let selectAllDuplicates = "Select All Duplicates"
        public static let undoDelete = "Undo Delete"
        
        public static let noDuplicatesFound = "No Duplicates Found"
        public static let noDuplicatesDesc = "Your photo library is clean and organized"

        public static let userGuide = "User Guide"

        public static let filesSkippedSuffix = "file(s) skipped (couldn't be read)"
    }

    /// System Image (SF Symbols) names
    public enum Icons {
        public static let appIcon = "photo.stack"
        public static let exactMatch = "rectangle.on.rectangle"
        public static let similarMatch = "wand.and.stars"
        public static let folderPlus = "folder.fill.badge.plus"
        public static let checkmarkCircle = "checkmark.circle"
        public static let photoCopies = "photo.on.rectangle.angled"
        public static let docText = "doc.text"
        public static let trash = "trash"
        public static let keepShield = "shield.checkered"
        public static let eyePreview = "eye.fill"
        public static let refresh = "arrow.top.right.and.arrow.bottom.left"
        public static let warningTriangle = "exclamationmark.triangle.fill"
    }

    /// Global UI metrics
    public enum UI {
        public static let defaultCornerRadius: CGFloat = 16.0
        public static let cardCornerRadius: CGFloat = 20.0
        public static let standardPadding: CGFloat = 24.0
        public static let imageThumbnailSize: CGFloat = 160.0
    }

    /// Scan tuning
    public enum Scan {
        /// Feature-print distance threshold below which two images are considered visually similar.
        /// Shared by the filesystem and Apple Photos similarity scanners so both stay in sync.
        public static let similarityThreshold: Float = 8.0
    }
}
