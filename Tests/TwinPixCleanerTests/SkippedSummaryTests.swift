import XCTest
@testable import TwinPixCleaner

final class SkippedSummaryTests: XCTestCase {

    func testSkippedSummaryCapsSampleItemsAtMaxSamples() {
        var summary = SkippedSummary()

        for i in 1...250 {
            summary.add(name: "Photo_\(i).heic", detail: "photos://\(i)", reason: .inCloudOnly)
        }

        XCTAssertEqual(summary.totalCount, 250)
        XCTAssertEqual(summary.sampleItems.count, 100)
        XCTAssertEqual(summary.reasonCounts[.inCloudOnly], 250)
        XCTAssertEqual(summary.sampleItems.first?.name, "Photo_1.heic")
        XCTAssertEqual(summary.sampleItems.last?.name, "Photo_100.heic")
    }

    func testSkippedSummaryTracksMultipleReasons() {
        var summary = SkippedSummary()

        summary.add(name: "cloud.heic", reason: .inCloudOnly)
        summary.add(name: "video.mp4", reason: .unsupportedFormat)
        summary.add(name: "corrupt.png", reason: .unreadableFile)

        XCTAssertEqual(summary.totalCount, 3)
        XCTAssertEqual(summary.sampleItems.count, 3)
        XCTAssertEqual(summary.reasonCounts[.inCloudOnly], 1)
        XCTAssertEqual(summary.reasonCounts[.unsupportedFormat], 1)
        XCTAssertEqual(summary.reasonCounts[.unreadableFile], 1)
    }

    func testSkippedSummaryMerge() {
        var summary1 = SkippedSummary()
        var summary2 = SkippedSummary()

        for i in 1...60 {
            summary1.add(name: "file_a_\(i).png", reason: .inCloudOnly)
            summary2.add(name: "file_b_\(i).png", reason: .unreadableFile)
        }

        summary1.merge(summary2)

        XCTAssertEqual(summary1.totalCount, 120)
        XCTAssertEqual(summary1.sampleItems.count, 100) // capped at 100
        XCTAssertEqual(summary1.reasonCounts[.inCloudOnly], 60)
        XCTAssertEqual(summary1.reasonCounts[.unreadableFile], 60)
    }
}
