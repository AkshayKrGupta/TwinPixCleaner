import Foundation
import SwiftUI

/// Categorized reason why an item was skipped during a scan.
public enum SkipReason: String, CaseIterable, Identifiable, Sendable {
    case inCloudOnly = "Stored in iCloud"
    case unsupportedFormat = "Video / Animated Media"
    case unreadableFile = "Unreadable or Corrupt File"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .inCloudOnly:
            return "icloud.slash"
        case .unsupportedFormat:
            return "video.slash"
        case .unreadableFile:
            return "exclamationmark.triangle"
        }
    }

    public var explanatoryText: String {
        switch self {
        case .inCloudOnly:
            return "Photo is stored only in iCloud and not downloaded locally on this Mac."
        case .unsupportedFormat:
            return "Video, GIF, or animated container excluded from still photo compares."
        case .unreadableFile:
            return "File could not be opened, read, or hashed due to disk permissions or corruption."
        }
    }
}

/// A recorded sample of an asset or file that was skipped.
public struct SkippedItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let detail: String?
    public let reason: SkipReason

    public init(id: String = UUID().uuidString, name: String, detail: String? = nil, reason: SkipReason) {
        self.id = id
        self.name = name
        self.detail = detail
        self.reason = reason
    }
}

/// Aggregated summary of skipped items across an entire scan.
/// To preserve low memory usage on 50k+ photo libraries, `sampleItems` is capped at 100 entries
/// while `totalCount` and `reasonCounts` track 100% of skipped assets.
public struct SkippedSummary: Sendable, Equatable {
    public static let maxSamples = 100

    public private(set) var totalCount: Int = 0
    public private(set) var reasonCounts: [SkipReason: Int] = [:]
    public private(set) var sampleItems: [SkippedItem] = []

    public init() {}

    public init(totalCount: Int, reasonCounts: [SkipReason: Int], sampleItems: [SkippedItem]) {
        self.totalCount = totalCount
        self.reasonCounts = reasonCounts
        self.sampleItems = Array(sampleItems.prefix(Self.maxSamples))
    }

    public mutating func add(name: String, detail: String? = nil, reason: SkipReason) {
        totalCount += 1
        reasonCounts[reason, default: 0] += 1
        if sampleItems.count < Self.maxSamples {
            sampleItems.append(SkippedItem(name: name, detail: detail, reason: reason))
        }
    }

    public mutating func merge(_ other: SkippedSummary) {
        totalCount += other.totalCount
        for (reason, count) in other.reasonCounts {
            reasonCounts[reason, default: 0] += count
        }
        let availableSlots = Self.maxSamples - sampleItems.count
        if availableSlots > 0 {
            sampleItems.append(contentsOf: other.sampleItems.prefix(availableSlots))
        }
    }
}
