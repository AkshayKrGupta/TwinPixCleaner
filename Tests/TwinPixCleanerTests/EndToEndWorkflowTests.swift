import XCTest
import SwiftUI
@testable import TwinPixCleaner

final class EndToEndWorkflowTests: XCTestCase {

    var tempFolder: URL!

    override func setUp() {
        super.setUp()
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("TwinPixCleanerTests_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let tempFolder {
            try? FileManager.default.removeItem(at: tempFolder)
        }
        super.tearDown()
    }

    /// Helper to create a simple PNG image of given dimensions and color
    private func createTestImage(filename: String, color: NSColor = .red, size: CGSize = CGSize(width: 50, height: 50)) -> URL {
        let image = NSImage(size: size)
        image.lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        image.unlockFocus()

        let fileURL = tempFolder.appendingPathComponent(filename)
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: fileURL)
        }
        return fileURL
    }

    // MARK: - Exact Scan End-to-End

    @MainActor
    func testExactMatchScannerDetectsBitForBitDuplicates() async throws {
        // Create 2 identical files and 1 different file
        let img1 = createTestImage(filename: "photo1.png", color: .blue).resolvingSymlinksInPath()
        let img2 = tempFolder.appendingPathComponent("photo2.png").resolvingSymlinksInPath()
        try FileManager.default.copyItem(at: img1, to: img2)
        _ = createTestImage(filename: "photo3.png", color: .green, size: CGSize(width: 80, height: 80))

        let detector = DuplicateDetector()
        let result = try await detector.scan(in: tempFolder) { _, _ in }

        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups[0].fileURLs.count, 2)
        let resolvedURLs = result.groups[0].fileURLs.map { $0.resolvingSymlinksInPath() }
        XCTAssertTrue(resolvedURLs.contains(img1))
        XCTAssertTrue(resolvedURLs.contains(img2))
        XCTAssertEqual(result.skippedCount, 0)
    }

    // MARK: - Visual Similarity Scan End-to-End

    @MainActor
    func testSimilarityScannerGroupsVisualDuplicates() async throws {
        // Create identical visually colored images
        let img1 = createTestImage(filename: "shot1.png", color: .red, size: CGSize(width: 100, height: 100)).resolvingSymlinksInPath()
        let img2 = createTestImage(filename: "shot2.png", color: .red, size: CGSize(width: 100, height: 100)).resolvingSymlinksInPath()
        let different = createTestImage(filename: "shot3.png", color: .cyan, size: CGSize(width: 100, height: 100)).resolvingSymlinksInPath()

        let detector = SimilarityDetector()
        let result = try await detector.scan(in: tempFolder) { _, _ in }

        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups[0].fileURLs.count, 2)
        let resolvedURLs = result.groups[0].fileURLs.map { $0.resolvingSymlinksInPath() }
        XCTAssertTrue(resolvedURLs.contains(img1))
        XCTAssertTrue(resolvedURLs.contains(img2))
        XCTAssertFalse(resolvedURLs.contains(different))
    }

    // MARK: - Undo State Full Group Reconstruction

    @MainActor
    func testUndoRestoresFullDuplicateGroup() {
        let vm = AppViewModel()
        let urlA = tempFolder.appendingPathComponent("a.png")
        let urlB = tempFolder.appendingPathComponent("b.png")
        try? Data("same".utf8).write(to: urlA)
        try? Data("same".utf8).write(to: urlB)

        let initialGroup = DuplicateGroup(hash: "test-hash", fileSize: 4, fileURLs: [urlA, urlB])
        vm.state = .results([initialGroup])

        // Select and delete urlB
        vm.selectedFiles = [urlB]
        vm.deleteSelectedFiles()

        // Group dropped because remaining count < 2
        if case .results(let remainingGroups) = vm.state {
            XCTAssertTrue(remainingGroups.isEmpty)
        } else {
            XCTFail("State should be results")
        }

        // Undo deletion
        vm.undoLastDeletion()

        // Verify that the restored group has BOTH files (not just [urlB])
        if case .results(let restoredGroups) = vm.state {
            XCTAssertEqual(restoredGroups.count, 1)
            XCTAssertEqual(restoredGroups[0].fileURLs.count, 2)
            XCTAssertTrue(restoredGroups[0].fileURLs.contains(urlA))
            XCTAssertTrue(restoredGroups[0].fileURLs.contains(urlB))
        } else {
            XCTFail("State should be results with restored group")
        }
    }

    // MARK: - Sequential Deletions in Multi-Item Group

    @MainActor
    func testSequentialSingleFileDeletionsInMultipleItemDuplicateGroup() {
        let vm = AppViewModel()
        let urlA = tempFolder.appendingPathComponent("multi_a.png")
        let urlB = tempFolder.appendingPathComponent("multi_b.png")
        let urlC = tempFolder.appendingPathComponent("multi_c.png")
        try? Data("multi-same".utf8).write(to: urlA)
        try? Data("multi-same".utf8).write(to: urlB)
        try? Data("multi-same".utf8).write(to: urlC)

        let initialGroup = DuplicateGroup(hash: "multi-hash", fileSize: 10, fileURLs: [urlA, urlB, urlC])
        vm.state = .results([initialGroup])

        // Delete first duplicate
        vm.deleteFile(url: urlA, in: initialGroup)
        XCTAssertNil(vm.appError)

        if case .results(let remainingGroups) = vm.state {
            XCTAssertEqual(remainingGroups.count, 1)
            XCTAssertEqual(remainingGroups[0].fileURLs.count, 2)
            XCTAssertFalse(remainingGroups[0].fileURLs.contains(urlA))
            XCTAssertTrue(remainingGroups[0].fileURLs.contains(urlB))
            XCTAssertTrue(remainingGroups[0].fileURLs.contains(urlC))
        } else {
            XCTFail("State should have 1 group with 2 remaining files")
        }

        // Delete second duplicate in the same group
        vm.deleteFile(url: urlB, in: initialGroup)
        XCTAssertNil(vm.appError)

        if case .results(let finalGroups) = vm.state {
            XCTAssertTrue(finalGroups.isEmpty, "Group should be removed when only 1 copy remains")
        } else {
            XCTFail("State should be results")
        }
    }
}
