import AppKit
import Foundation
import Testing
import AkapenCore
@testable import AkapenUI

/// サムネイルの切り抜き方（赤枠の中心を中央に、画像からはみ出さない）と、一覧の時刻。
@Suite
struct ThumbnailCropTests {
    let aspect: CGFloat = 96.0 / 60.0

    @Test
    func wideImageIsCroppedAroundFrameCenter() {
        let rect = ThumbnailCrop.rect(
            imageSize: CGSize(width: 2000, height: 1000),
            windowFrame: ScreenRect(x: 100, y: 50, width: 1000, height: 500),
            frame: ScreenRect(x: 600, y: 250, width: 100, height: 100),
            aspect: aspect
        )
        #expect(rect == CGRect(x: 300, y: 0, width: 1600, height: 1000))
    }

    @Test
    func cropStaysInsideImageNearEdges() {
        let left = ThumbnailCrop.rect(
            imageSize: CGSize(width: 2000, height: 1000),
            windowFrame: ScreenRect(x: 0, y: 0, width: 1000, height: 500),
            frame: ScreenRect(x: 0, y: 0, width: 10, height: 10),
            aspect: aspect
        )
        #expect(left.minX == 0)
        let right = ThumbnailCrop.rect(
            imageSize: CGSize(width: 2000, height: 1000),
            windowFrame: ScreenRect(x: 0, y: 0, width: 1000, height: 500),
            frame: ScreenRect(x: 990, y: 490, width: 10, height: 10),
            aspect: aspect
        )
        #expect(right.maxX == 2000)
        #expect(right.maxY == 1000)
    }

    @Test
    func tallImageKeepsFullWidth() {
        let rect = ThumbnailCrop.rect(
            imageSize: CGSize(width: 800, height: 1200),
            windowFrame: ScreenRect(x: -1440, y: -100, width: 400, height: 600),
            frame: ScreenRect(x: -1340, y: 200, width: 100, height: 40),
            aspect: aspect
        )
        #expect(rect == CGRect(x: 0, y: 390, width: 800, height: 500))
    }

    @Test
    func timeUsesGivenTimeZone() {
        #expect(AnnotationTime.string(from: Fixtures.createdAt, timeZone: Fixtures.timeZone) == "14:32")
        #expect(AnnotationTime.string(from: Fixtures.createdAt, timeZone: TimeZone(identifier: "UTC")!) == "05:32")
    }

    @Test
    @MainActor
    func fileProviderCropsSavedImage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("akapen-ui-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("01.png")
        try SnapshotImages.mockWindowPNG(size: CGSize(width: 1000, height: 660), frame: CGRect(x: 770, y: 404, width: 204, height: 56)).write(to: url)
        let annotation = Fixtures.annotation("x", path: url.path)
        let provider = FileThumbnailProvider()
        let image = try #require(provider.thumbnail(for: annotation))
        #expect(abs(image.size.width / image.size.height - aspect) < 0.01)
        #expect(provider.thumbnail(for: Fixtures.annotation("y", path: directory.appendingPathComponent("missing.png").path)) == nil)
    }
}
