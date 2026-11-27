import Foundation
import Testing
@testable import TwinPixCleaner

@Suite("ImageQualityEvaluator Tests")
struct ImageQualityEvaluatorTests {

    @Test("Higher resolution is preferred over lower resolution")
    func testHigherResolutionPreferred() {
        let lowRes = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/low.jpg"),
            pixelWidth: 1920,
            pixelHeight: 1080,
            fileSize: 5_000_000,
            creationDate: Date(timeIntervalSince1970: 1000)
        )
        let highRes = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/high.jpg"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 3_000_000,
            creationDate: Date(timeIntervalSince1970: 2000)
        )

        #expect(lowRes < highRes)
        #expect([lowRes, highRes].max()?.url == highRes.url)
    }

    @Test("Higher bit depth is preferred when resolutions are identical")
    func testHigherBitDepthPreferred() {
        let sdr = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/sdr.jpg"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 3_000_000,
            bitDepth: 8
        )
        let hdr = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/hdr.heic"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 3_000_000,
            bitDepth: 10
        )

        #expect(sdr < hdr)
        #expect([sdr, hdr].max()?.url == hdr.url)
    }

    @Test("RAW and Lossless formats are preferred over lossy formats")
    func testFormatTierPreferred() {
        let jpeg = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"),
            pixelWidth: 4000,
            pixelHeight: 3000,
            fileSize: 4_000_000,
            formatTier: 1
        )
        let raw = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/photo.dng"),
            pixelWidth: 4000,
            pixelHeight: 3000,
            fileSize: 4_000_000,
            formatTier: 4
        )

        #expect(jpeg < raw)
        #expect([jpeg, raw].max()?.url == raw.url)
    }

    @Test("EXIF presence is preferred when other metrics are identical")
    func testExifPresencePreferred() {
        let stripped = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/stripped.jpg"),
            pixelWidth: 4000,
            pixelHeight: 3000,
            fileSize: 2_000_000,
            hasExif: false
        )
        let original = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/original.jpg"),
            pixelWidth: 4000,
            pixelHeight: 3000,
            fileSize: 2_000_000,
            hasExif: true
        )

        #expect(stripped < original)
        #expect([stripped, original].max()?.url == original.url)
    }

    @Test("Larger file size is preferred when format, resolution and bit depth are equal")
    func testLargerFileSizePreferredWhenResolutionsEqual() {
        let smaller = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/compressed.jpg"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 1_500_000,
            creationDate: Date(timeIntervalSince1970: 1000)
        )
        let larger = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/original.jpg"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 4_500_000,
            creationDate: Date(timeIntervalSince1970: 2000)
        )

        #expect(smaller < larger)
        #expect([smaller, larger].max()?.url == larger.url)
    }

    @Test("Older creation date is preferred when resolution and size are identical")
    func testOlderCreationDatePreferredWhenEqualQuality() {
        let olderOriginal = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/original.jpg"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 2_000_000,
            creationDate: Date(timeIntervalSince1970: 1000)
        )
        let newerCopy = ImageQualityInfo(
            url: URL(fileURLWithPath: "/tmp/copy.jpg"),
            pixelWidth: 4032,
            pixelHeight: 3024,
            fileSize: 2_000_000,
            creationDate: Date(timeIntervalSince1970: 2000)
        )

        #expect(newerCopy < olderOriginal)
        #expect([newerCopy, olderOriginal].max()?.url == olderOriginal.url)
    }

    @Test("Photos asset URLs tie-breaker works deterministically")
    func testPhotosAssetTieBreaker() {
        let url1 = URL(string: "photos://asset?id=AAA")!
        let url2 = URL(string: "photos://asset?id=BBB")!

        let info1 = ImageQualityInfo(url: url1, pixelWidth: 100, pixelHeight: 100, fileSize: 100)
        let info2 = ImageQualityInfo(url: url2, pixelWidth: 100, pixelHeight: 100, fileSize: 100)

        #expect(info2 < info1)
        #expect([info1, info2].max()?.url == url1)
    }

    @Test("Select all duplicates retains one copy and marks the others for deletion")
    @MainActor
    func testSelectAllDuplicatesRetainsOneCopy() {
        let vm = AppViewModel()
        let url1 = URL(fileURLWithPath: "/tmp/file1.jpg")
        let url2 = URL(fileURLWithPath: "/tmp/file2.jpg")
        let url3 = URL(fileURLWithPath: "/tmp/file3.jpg")

        let group = DuplicateGroup(hash: "test-group", fileSize: 100, fileURLs: [url1, url2, url3])
        vm.state = .results([group])

        vm.selectAllDuplicates(in: group)

        // Exactly 2 of the 3 should be selected for deletion, exactly 1 preserved
        #expect(vm.selectedFiles.count == 2)
        let unselected = group.fileURLs.filter { !vm.selectedFiles.contains($0) }
        #expect(unselected.count == 1)
    }
}
