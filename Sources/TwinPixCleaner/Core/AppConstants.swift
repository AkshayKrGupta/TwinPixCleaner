import Foundation
import CoreGraphics
import os

/// Structured loggers for unified, subsystem-categorized Console.app logging.
public enum AppLogger {
    public static let scanner = Logger(subsystem: "com.akshaykrgupta.TwinPixCleaner", category: "Scanner")
    public static let quickLook = Logger(subsystem: "com.akshaykrgupta.TwinPixCleaner", category: "QuickLook")
    public static let general = Logger(subsystem: "com.akshaykrgupta.TwinPixCleaner", category: "General")
}

/// Centralized constants for the entire TwinPixCleaner application.
/// Using this enum prevents hardcoded magic strings and allows for easy updates/localization.
public enum AppConstants {
    
    /// User-facing text strings
    public enum Strings {
        public static let appName = "TwinPixCleaner"
        public static let aboutDescription = "A smart duplicate photo finder for macOS"
        public static let developerName = "Akshay K Gupta"
        public static let linkedinURL = "https://www.linkedin.com/in/akshay-kr-gupta/"

        public static let newScan = "New Scan"
        public static let cancelScan = "Cancel Scan"
        public static let selectFolder = "Select Folder to Scan"
        public static let dragDropPrompt = "or drag and drop a folder here"
        
        public static let scanningTitle = "Scanning for Duplicates"
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
        public static let folderPlus = "folder.fill.badge.plus"
        public static let checkmarkCircle = "checkmark.circle"
        public static let photoCopies = "photo.on.rectangle.angled"
        public static let docText = "doc.text"
        public static let trash = "trash"
        public static let keepShield = "shield.checkered"
        public static let eyePreview = "eye.fill"
        public static let warningTriangle = "exclamationmark.triangle.fill"
    }

    /// Global UI metrics
    public enum UI {
        public static let defaultCornerRadius: CGFloat = 16.0
        public static let cardCornerRadius: CGFloat = 20.0
    }

    /// Scan tuning
    public enum Scan {
        /// Rev2 (macOS 14+): precision-first near-duplicate L2 threshold on normalized 768-D prints.
        public static let similarityThresholdRev2: Float = 0.28
        /// Rev2 screenshots: much stricter — Vision collapses UI chrome / ignores text differences.
        public static let similarityThresholdRev2Screenshot: Float = 0.12
        /// Rev1 fallback (macOS 13): legacy 2048-D feature-print scale.
        public static let similarityThresholdRev1: Float = 8.0
        /// Rev1 screenshots: proportionally stricter on the legacy distance scale.
        public static let similarityThresholdRev1Screenshot: Float = 3.0
        /// Max pixel size for ImageIO / PhotoKit decode before Vision feature print.
        public static let featurePrintMaxPixelSize: Int = 768
        /// Concurrent Vision print tasks (capped vs active CPU count).
        public static let maxConcurrentFeaturePrints: Int = 6

        /// Active distance threshold for the Vision revision in use on this OS.
        /// Shared by filesystem and Apple Photos similarity scanners so both stay in sync.
        public static func activeThreshold() -> Float {
            if #available(macOS 14.0, *) {
                return similarityThresholdRev2
            }
            return similarityThresholdRev1
        }

        /// Stricter threshold for screenshot-only clustering (same OS revision scale).
        public static func activeScreenshotThreshold() -> Float {
            if #available(macOS 14.0, *) {
                return similarityThresholdRev2Screenshot
            }
            return similarityThresholdRev1Screenshot
        }
    }
}
