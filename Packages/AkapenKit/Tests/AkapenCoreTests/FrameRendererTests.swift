import Foundation
import Testing
import AkapenCore

private typealias Box = TestImages.PixelBox

/// `FrameRenderer` の入口。PNG を受け取るものと、撮った画像をそのまま受け取るもの。
enum RenderEntry: CaseIterable, Sendable {
    case png
    case image
}

private func render(
    _ entry: RenderEntry,
    imageWidth: Int,
    imageHeight: Int,
    region: ScreenRect,
    frame: ScreenRect,
    maxLongEdge: Int = FrameRenderer.defaultMaxLongEdge
) throws -> TestImages.Bitmap {
    let output: Data
    switch entry {
    case .png:
        let png = TestImages.solidPNG(width: imageWidth, height: imageHeight, color: TestImages.blue)
        output = try FrameRenderer.render(png: png, region: region, frame: frame, maxLongEdge: maxLongEdge)
    case .image:
        let image = TestImages.solidImage(width: imageWidth, height: imageHeight, color: TestImages.blue)
        output = try FrameRenderer.render(image: image, region: region, frame: frame, maxLongEdge: maxLongEdge)
    }
    return try #require(TestImages.decode(output))
}

@Test
func defaultLongEdgeIs1568() {
    #expect(FrameRenderer.defaultMaxLongEdge == 1568)
}

@Test(arguments: RenderEntry.allCases)
func drawsFrameOutsideTheRectAtRetinaScale(entry: RenderEntry) throws {
    // 範囲 400×300 pt を 2 倍で撮った 800×600 px。枠は範囲の (50, 50) から 100×50 pt。
    let bitmap = try render(
        entry,
        imageWidth: 800,
        imageHeight: 600,
        region: ScreenRect(x: 100, y: 50, width: 400, height: 300),
        frame: ScreenRect(x: 150, y: 100, width: 100, height: 50)
    )
    #expect(bitmap.width == 800)
    #expect(bitmap.height == 600)
    // 囲んだ範囲は px で (100, 100)〜(299, 199)。太さは 3pt × 2 = 6px で外側に付く。
    #expect(bitmap.frameRedBox() == Box(minX: 94, minY: 94, maxX: 305, maxY: 205))
    #expect(bitmap.allPixels(in: Box(minX: 100, minY: 100, maxX: 299, maxY: 199), are: TestImages.blue))
    // 帯の太さ: 左の帯は 94〜99、上の帯は 94〜99。
    #expect(bitmap.allPixels(in: Box(minX: 94, minY: 94, maxX: 99, maxY: 205), are: TestImages.frameRed))
    #expect(bitmap.allPixels(in: Box(minX: 94, minY: 94, maxX: 305, maxY: 99), are: TestImages.frameRed))
    #expect(bitmap.allPixels(in: Box(minX: 300, minY: 94, maxX: 305, maxY: 205), are: TestImages.frameRed))
    #expect(bitmap.allPixels(in: Box(minX: 94, minY: 200, maxX: 305, maxY: 205), are: TestImages.frameRed))
    // 帯の外は元の色のまま。
    #expect(bitmap.pixel(x: 93, y: 150) == TestImages.blue)
    #expect(bitmap.pixel(x: 306, y: 150) == TestImages.blue)
}

@Test(arguments: RenderEntry.allCases)
func keepsMinimumStrokeOfThreePixels(entry: RenderEntry) throws {
    // 1 倍の画像を半分に縮めると、3pt は 1.5px になるが、3px で描く。
    let bitmap = try render(
        entry,
        imageWidth: 400,
        imageHeight: 200,
        region: ScreenRect(x: 0, y: 0, width: 400, height: 200),
        frame: ScreenRect(x: 100, y: 50, width: 100, height: 60),
        maxLongEdge: 200
    )
    #expect(bitmap.width == 200)
    #expect(bitmap.height == 100)
    // 囲んだ範囲は px で (50, 25)〜(99, 54)。
    #expect(bitmap.frameRedBox() == Box(minX: 47, minY: 22, maxX: 102, maxY: 57))
    #expect(bitmap.allPixels(in: Box(minX: 47, minY: 22, maxX: 49, maxY: 57), are: TestImages.frameRed))
    #expect(bitmap.pixel(x: 75, y: 40) == TestImages.blue)
}

@Test(arguments: RenderEntry.allCases)
func downscalesOnlyWhenLongEdgeExceedsLimit(entry: RenderEntry) throws {
    // 1600×1000 pt を 2 倍で撮った 3200×2000 px は、長辺 1568 px に縮める。
    let bitmap = try render(
        entry,
        imageWidth: 3200,
        imageHeight: 2000,
        region: ScreenRect(x: 0, y: 0, width: 1600, height: 1000),
        frame: ScreenRect(x: 400, y: 300, width: 200, height: 100)
    )
    #expect(bitmap.width == 1568)
    #expect(bitmap.height == 980)
    // 縮小後は 0.98 px/pt。太さは 3pt × 0.98 ≒ 2.94 → 3px。囲んだ範囲は (392, 294)〜(587, 391)。
    #expect(bitmap.frameRedBox() == Box(minX: 389, minY: 291, maxX: 590, maxY: 394))
    #expect(bitmap.pixel(x: 490, y: 340) == TestImages.blue)
    // 上限ちょうどの画像は縮めない。
    let exact = try render(
        entry,
        imageWidth: 1568,
        imageHeight: 100,
        region: ScreenRect(x: 0, y: 0, width: 1568, height: 100),
        frame: ScreenRect(x: 10, y: 10, width: 10, height: 10)
    )
    #expect(exact.width == 1568)
    #expect(exact.height == 100)
}

@Test(arguments: RenderEntry.allCases)
func clipsFrameToWindowAndMovesEdgeStrokeInside(entry: RenderEntry) throws {
    // 範囲 200×100 pt を 1 倍で撮った画像。枠は左にはみ出している。
    let bitmap = try render(
        entry,
        imageWidth: 200,
        imageHeight: 100,
        region: ScreenRect(x: 0, y: 0, width: 200, height: 100),
        frame: ScreenRect(x: -50, y: 20, width: 100, height: 40)
    )
    // 切り詰めた枠は (0, 20)〜(49, 59)。左の帯は画像の端に当たるので、内側の 0〜2 に寄せる。
    #expect(bitmap.frameRedBox() == Box(minX: 0, minY: 17, maxX: 52, maxY: 62))
    #expect(bitmap.allPixels(in: Box(minX: 0, minY: 17, maxX: 2, maxY: 62), are: TestImages.frameRed))
    #expect(bitmap.allPixels(in: Box(minX: 3, minY: 20, maxX: 49, maxY: 59), are: TestImages.blue))
}

@Test(arguments: RenderEntry.allCases)
func clipsFrameAtBottomRightCorner(entry: RenderEntry) throws {
    let bitmap = try render(
        entry,
        imageWidth: 200,
        imageHeight: 100,
        region: ScreenRect(x: 1000, y: 500, width: 200, height: 100),
        frame: ScreenRect(x: 1150, y: 560, width: 100, height: 100)
    )
    // 切り詰めた枠は (150, 60)〜(199, 99)。右と下の帯は内側に寄る。
    #expect(bitmap.frameRedBox() == Box(minX: 147, minY: 57, maxX: 199, maxY: 99))
    #expect(bitmap.allPixels(in: Box(minX: 197, minY: 57, maxX: 199, maxY: 99), are: TestImages.frameRed))
    #expect(bitmap.allPixels(in: Box(minX: 147, minY: 97, maxX: 199, maxY: 99), are: TestImages.frameRed))
    #expect(bitmap.allPixels(in: Box(minX: 150, minY: 60, maxX: 196, maxY: 96), are: TestImages.blue))
}

@Test(arguments: RenderEntry.allCases)
func drawsNothingWhenFrameDoesNotOverlapWindow(entry: RenderEntry) throws {
    let bitmap = try render(
        entry,
        imageWidth: 100,
        imageHeight: 100,
        region: ScreenRect(x: 0, y: 0, width: 100, height: 100),
        frame: ScreenRect(x: 300, y: 300, width: 50, height: 50)
    )
    #expect(bitmap.frameRedBox() == nil)
}

@Test
func rejectsUnreadableImageAndEmptyWindow() {
    let region = ScreenRect(x: 0, y: 0, width: 100, height: 100)
    #expect(throws: FrameRenderer.RenderError.unreadableImage) {
        try FrameRenderer.render(png: Data("not a png".utf8), region: region, frame: region)
    }
    let png = TestImages.solidPNG(width: 10, height: 10, color: TestImages.blue)
    #expect(throws: FrameRenderer.RenderError.invalidRegion) {
        try FrameRenderer.render(png: png, region: ScreenRect(x: 0, y: 0, width: 0, height: 10), frame: region)
    }
    let image = TestImages.solidImage(width: 10, height: 10, color: TestImages.blue)
    #expect(throws: FrameRenderer.RenderError.invalidRegion) {
        try FrameRenderer.render(image: image, region: ScreenRect(x: 0, y: 0, width: 10, height: 0), frame: region)
    }
}

@Test
func bothEntriesWriteTheSamePixels() throws {
    let region = ScreenRect(x: 100, y: 50, width: 400, height: 300)
    let frame = ScreenRect(x: 150, y: 100, width: 100, height: 50)
    let fromPNG = try render(.png, imageWidth: 800, imageHeight: 600, region: region, frame: frame)
    let fromImage = try render(.image, imageWidth: 800, imageHeight: 600, region: region, frame: frame)
    #expect(fromPNG.width == fromImage.width)
    #expect(fromPNG.height == fromImage.height)
    #expect(fromPNG.bytes == fromImage.bytes)
}
