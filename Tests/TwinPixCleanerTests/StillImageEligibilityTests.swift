import XCTest
@testable import TwinPixCleaner

final class StillImageEligibilityTests: XCTestCase {

    func testAllowsCommonStillExtensions() {
        XCTAssertTrue(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/photo.jpg")))
        XCTAssertTrue(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/photo.JPEG")))
        XCTAssertTrue(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/photo.png")))
        XCTAssertTrue(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/photo.heic")))
    }

    func testRejectsGifByExtension() {
        XCTAssertFalse(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/anim.gif")))
        XCTAssertFalse(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/clip.mp4")))
        XCTAssertFalse(StillImageEligibility.isComparableStillImageFile(URL(fileURLWithPath: "/a/movie.mov")))
    }

    func testScreenshotFilenameDetection() {
        XCTAssertTrue(StillImageEligibility.isScreenshotFile(
            URL(fileURLWithPath: "/a/Screenshot 2024-01-01 at 12.00.00.png")
        ))
        XCTAssertTrue(StillImageEligibility.isScreenshotFile(
            URL(fileURLWithPath: "/a/Screen Shot 2024-01-01.png")
        ))
        XCTAssertFalse(StillImageEligibility.isScreenshotFile(
            URL(fileURLWithPath: "/a/IMG_1234.HEIC")
        ))
    }

    func testGifNotInAllowedExtensions() {
        XCTAssertFalse(StillImageEligibility.allowedExtensions.contains("gif"))
        XCTAssertTrue(FileScanner.imageExtensions.isDisjoint(with: ["gif", "mp4", "mov"]))
    }
}
