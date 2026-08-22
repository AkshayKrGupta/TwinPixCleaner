import XCTest
@testable import TwinPixCleaner

final class FeaturePrintClusteringTests: XCTestCase {

    private func url(_ name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    /// Three points on a line: A—B—C with A≁C by direct distance, but union-find merges all.
    func testUnionFindMergesTransitiveChain() async {
        // 1-D embeddings: A=0, B=1, C=2; threshold 1.5 → A~B, B~C, A!~C
        let a = url("a.jpg")
        let b = url("b.jpg")
        let c = url("c.jpg")
        let prints: [(url: URL, vector: [Float])] = [
            (a, [0]),
            (b, [1]),
            (c, [2])
        ]

        let groups = await FeaturePrintClustering.cluster(
            prints: prints,
            threshold: 1.5,
            onProgress: { _, _ in },
            baseProgress: 0,
            progressSpan: 1
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), Set([a, b, c]))
    }

    func testDoesNotMergeFarApartPoints() async {
        let a = url("a.jpg")
        let b = url("b.jpg")
        let prints: [(url: URL, vector: [Float])] = [
            (a, [0]),
            (b, [10])
        ]

        let groups = await FeaturePrintClustering.cluster(
            prints: prints,
            threshold: 1.5,
            onProgress: { _, _ in },
            baseProgress: 0,
            progressSpan: 1
        )

        XCTAssertTrue(groups.isEmpty)
    }

    func testTwoSeparatePairs() async {
        let a = url("a.jpg")
        let b = url("b.jpg")
        let c = url("c.jpg")
        let d = url("d.jpg")
        let prints: [(url: URL, vector: [Float])] = [
            (a, [0]),
            (b, [0.5]),
            (c, [100]),
            (d, [100.5])
        ]

        let groups = await FeaturePrintClustering.cluster(
            prints: prints,
            threshold: 1.0,
            onProgress: { _, _ in },
            baseProgress: 0,
            progressSpan: 1
        )

        XCTAssertEqual(groups.count, 2)
        let sets = Set(groups.map { Set($0) })
        XCTAssertEqual(sets, Set([Set([a, b]), Set([c, d])]))
    }

    func testL2DistanceIdenticalVectorsIsZero() {
        let v: [Float] = [0.1, -0.2, 0.3, 0.4]
        let distance = FeaturePrintEngine.l2Distance(v, v)
        XCTAssertEqual(distance, 0, accuracy: 1e-6)
    }

    func testL2DistanceKnownValues() {
        let a: [Float] = [0, 0, 0]
        let b: [Float] = [3, 4, 0]
        let distance = FeaturePrintEngine.l2Distance(a, b)
        XCTAssertEqual(distance, 5, accuracy: 1e-5)
    }

    func testRev2ThresholdInExpectedRange() {
        XCTAssertLessThan(AppConstants.Scan.similarityThresholdRev2, 2.0)
        XCTAssertGreaterThan(AppConstants.Scan.similarityThresholdRev2, 0)
        XCTAssertEqual(AppConstants.Scan.similarityThresholdRev1, 8.0)
        XCTAssertEqual(AppConstants.Scan.featurePrintMaxPixelSize, 768)
    }

    func testActiveThresholdMatchesRevisionScale() {
        let threshold = AppConstants.Scan.activeThreshold()
        let shot = AppConstants.Scan.activeScreenshotThreshold()
        if #available(macOS 14.0, *) {
            XCTAssertEqual(threshold, AppConstants.Scan.similarityThresholdRev2)
            XCTAssertEqual(shot, AppConstants.Scan.similarityThresholdRev2Screenshot)
            XCTAssertLessThan(shot, threshold)
        } else {
            XCTAssertEqual(threshold, AppConstants.Scan.similarityThresholdRev1)
            XCTAssertEqual(shot, AppConstants.Scan.similarityThresholdRev1Screenshot)
            XCTAssertLessThan(shot, threshold)
        }
    }

    func testScreenshotPoolUsesSeparateThreshold() async {
        let a = url("Screenshot-a.png")
        let b = url("Screenshot-b.png")
        let c = url("photo.jpg")
        let d = url("photo2.jpg")
        // Screenshots are moderately close (would merge at 0.28, not at 0.12)
        let prints: [(url: URL, vector: [Float], isScreenshot: Bool)] = [
            (a, [0.0], true),
            (b, [0.20], true),
            (c, [0.0], false),
            (d, [0.20], false)
        ]

        let groups = await FeaturePrintClustering.clusterSeparatingScreenshots(
            prints: prints,
            photoThreshold: 0.28,
            screenshotThreshold: 0.12,
            onProgress: { _, _ in },
            baseProgress: 0,
            progressSpan: 1
        )

        // Photos merge (0.20 <= 0.28); screenshots stay apart (0.20 > 0.12)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), Set([c, d]))
    }

    func testCacheStoreLoadAndClear() {
        let key = "test-key-\(UUID().uuidString)"
        let vector: [Float] = [1.0, 2.0, 3.0, 4.0]

        FeaturePrintEngine.storeCachedVector(vector, cacheKey: key)
        let loaded = FeaturePrintEngine.loadCachedVector(cacheKey: key)
        XCTAssertEqual(loaded, vector)

        let cleared = FeaturePrintEngine.clearCache()
        XCTAssertTrue(cleared)
        let loadedAfterClear = FeaturePrintEngine.loadCachedVector(cacheKey: key)
        XCTAssertNil(loadedAfterClear)
    }
}
