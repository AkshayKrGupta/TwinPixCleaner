import XCTest
@testable import TwinPixCleaner

final class SizeHashGroupingTests: XCTestCase {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    func testGroupsFilesWithSameSizeAndHash() async {
        let a = url("a.jpg")
        let b = url("b.jpg")
        let candidates = [(url: a, size: Int64(100), label: "a.jpg"), (url: b, size: Int64(100), label: "b.jpg")]

        let result = await SizeHashGrouping.group(
            candidates: candidates,
            hash: { _ in "same-hash" },
            onProgress: { _, _ in },
            baseProgress: 0.0,
            progressSpan: 1.0
        )

        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(Set(result.groups[0].fileURLs), Set([a, b]))
        XCTAssertEqual(result.skippedCount, 0)
    }

    func testDoesNotGroupSameSizeDifferentHash() async {
        let a = url("a.jpg")
        let b = url("b.jpg")
        let candidates = [(url: a, size: Int64(100), label: "a.jpg"), (url: b, size: Int64(100), label: "b.jpg")]

        let result = await SizeHashGrouping.group(
            candidates: candidates,
            hash: { u in u == a ? "hash-a" : "hash-b" },
            onProgress: { _, _ in },
            baseProgress: 0.0,
            progressSpan: 1.0
        )

        XCTAssertTrue(result.groups.isEmpty)
    }

    func testDoesNotGroupAcrossDifferentSizes() async {
        let a = url("a.jpg")
        let b = url("b.jpg")
        let candidates = [(url: a, size: Int64(100), label: "a.jpg"), (url: b, size: Int64(200), label: "b.jpg")]

        let result = await SizeHashGrouping.group(
            candidates: candidates,
            hash: { _ in "same-hash" },
            onProgress: { _, _ in },
            baseProgress: 0.0,
            progressSpan: 1.0
        )

        XCTAssertTrue(result.groups.isEmpty)
    }

    func testCountsUnhashableFilesAsSkipped() async {
        let a = url("a.jpg")
        let b = url("b.jpg")
        let candidates = [(url: a, size: Int64(100), label: "a.jpg"), (url: b, size: Int64(100), label: "b.jpg")]

        let result = await SizeHashGrouping.group(
            candidates: candidates,
            hash: { u in u == a ? "hash-a" : nil },
            onProgress: { _, _ in },
            baseProgress: 0.0,
            progressSpan: 1.0
        )

        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertEqual(result.skippedCount, 1)
    }
}
