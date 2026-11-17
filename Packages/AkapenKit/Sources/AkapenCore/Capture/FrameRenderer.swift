import CoreGraphics
import Foundation
import ImageIO

/// 撮影した画像に赤枠を描き込み、長辺の上限に合わせて縮小する。CoreGraphics と ImageIO だけで描く。
public enum FrameRenderer {
    /// 保存する画像の長辺の上限（px）の既定値。
    public static let defaultMaxLongEdge = 1568

    /// 赤枠の太さ（画面上の pt）。縮小後の画像で、この太さに当たる px で描く。
    public static let strokeWidthInPoints = 3.0

    /// 赤枠の太さの下限（px）。
    public static let minimumStrokeWidthInPixels = 3

    /// 赤枠の色（`#FF3E3E`）の RGB 成分。0〜255。
    public static let frameColorRGB: (red: UInt8, green: UInt8, blue: UInt8) = (0xFF, 0x3E, 0x3E)

    /// 描き込みに失敗した理由。
    public enum RenderError: Error, Equatable {
        /// PNG として読めない、または大きさが 0。
        case unreadableImage
        /// ウィンドウの矩形の幅か高さが 0 以下。
        case invalidWindowFrame
        /// 描画先を用意できなかった。
        case drawingFailed
        /// PNG に書き出せなかった。
        case encodingFailed
    }

    /// 赤枠を描き込んで縮小した PNG を返す。
    ///
    /// - Parameters:
    ///   - png: ウィンドウ全体を写した PNG。
    ///   - windowFrame: そのウィンドウの矩形（画面全体の座標、pt）。
    ///   - frame: 描いた枠の矩形（画面全体の座標、pt）。ウィンドウからはみ出す分は内側に切り詰める。
    ///   - maxLongEdge: 長辺の上限（px）。超えるときだけ縮小する。
    ///
    /// 画像の倍率は「画像の幅(px) ÷ ウィンドウの幅(pt)」から求める。
    /// 枠線は枠の矩形の外側に描き、囲んだ中身を隠さない。ただし画像の端に当たる辺は内側に寄せる。
    /// 枠がウィンドウと重ならなければ、枠は描かずに縮小だけをする。
    public static func render(
        png: Data,
        windowFrame: ScreenRect,
        frame: ScreenRect,
        maxLongEdge: Int = defaultMaxLongEdge
    ) throws -> Data {
        guard windowFrame.width > 0, windowFrame.height > 0 else {
            throw RenderError.invalidWindowFrame
        }
        let source = try decode(png)
        let sourceWidth = source.width
        let sourceHeight = source.height
        let downscale = Swift.min(1.0, Double(Swift.max(maxLongEdge, 1)) / Double(Swift.max(sourceWidth, sourceHeight)))
        let width = Swift.max(1, Int((Double(sourceWidth) * downscale).rounded()))
        let height = Swift.max(1, Int((Double(sourceHeight) * downscale).rounded()))
        let context = try makeContext(width: width, height: height, like: source)
        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        // 元の画像の倍率（px/pt）に縮小の比率を掛けた、縮小後の画像での px/pt。
        let sourcePixelsPerPoint = Double(sourceWidth) / windowFrame.width
        let pixelsPerPoint = sourcePixelsPerPoint * Double(width) / Double(sourceWidth)
        if let clipped = frame.intersection(windowFrame) {
            drawFrame(
                clipped,
                in: context,
                windowFrame: windowFrame,
                pixelsPerPoint: pixelsPerPoint,
                imageSize: (width, height)
            )
        }
        guard let output = context.makeImage() else {
            throw RenderError.drawingFailed
        }
        return try encode(output)
    }

    /// 縮小後の画像での赤枠の太さ（px）。
    static func strokeWidth(pixelsPerPoint: Double) -> Int {
        Swift.max(minimumStrokeWidthInPixels, Int((strokeWidthInPoints * pixelsPerPoint).rounded()))
    }

    private static func decode(_ png: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width > 0,
              image.height > 0 else {
            throw RenderError.unreadableImage
        }
        return image
    }

    /// 元の画像の色空間で描画先を作る（中身の色を変えないため）。使えなければ sRGB にする。
    private static func makeContext(width: Int, height: Int, like image: CGImage) throws -> CGContext {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        var spaces: [CGColorSpace] = []
        if let space = image.colorSpace, space.model == .rgb {
            spaces.append(space)
        }
        if let srgb = CGColorSpace(name: CGColorSpace.sRGB) {
            spaces.append(srgb)
        }
        for space in spaces {
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: bitmapInfo
            )
            if let context {
                return context
            }
        }
        throw RenderError.drawingFailed
    }

    /// 枠の外側に、太さ `strokeWidth` の帯を塗る。座標は px に揃えて、にじませない。
    private static func drawFrame(
        _ frame: ScreenRect,
        in context: CGContext,
        windowFrame: ScreenRect,
        pixelsPerPoint: Double,
        imageSize: (width: Int, height: Int)
    ) {
        let stroke = strokeWidth(pixelsPerPoint: pixelsPerPoint)
        // 左上原点の px 座標。
        let left = Int(((frame.x - windowFrame.x) * pixelsPerPoint).rounded())
        let top = Int(((frame.y - windowFrame.y) * pixelsPerPoint).rounded())
        let right = Int(((frame.maxX - windowFrame.x) * pixelsPerPoint).rounded())
        let bottom = Int(((frame.maxY - windowFrame.y) * pixelsPerPoint).rounded())
        // 外側へ広げ、画像からはみ出す辺は画像の端で止める（その辺の帯は内側に寄る）。
        let outerLeft = Swift.max(0, left - stroke)
        let outerTop = Swift.max(0, top - stroke)
        let outerRight = Swift.min(imageSize.width, right + stroke)
        let outerBottom = Swift.min(imageSize.height, bottom + stroke)
        guard outerRight > outerLeft, outerBottom > outerTop else {
            return
        }
        let outer = flipped(left: outerLeft, top: outerTop, right: outerRight, bottom: outerBottom, height: imageSize.height)
        let red = frameColorRGB
        let color = CGColor(
            srgbRed: CGFloat(red.red) / 255,
            green: CGFloat(red.green) / 255,
            blue: CGFloat(red.blue) / 255,
            alpha: 1
        )
        context.setShouldAntialias(false)
        context.setFillColor(color)
        let innerWidth = outerRight - outerLeft - stroke * 2
        let innerHeight = outerBottom - outerTop - stroke * 2
        guard innerWidth > 0, innerHeight > 0 else {
            context.fill(outer)
            return
        }
        let inner = outer.insetBy(dx: CGFloat(stroke), dy: CGFloat(stroke))
        context.addRect(outer)
        context.addRect(inner)
        context.fillPath(using: .evenOdd)
    }

    /// 左上原点の px の矩形を、CoreGraphics の左下原点の矩形に直す。
    private static func flipped(left: Int, top: Int, right: Int, bottom: Int, height: Int) -> CGRect {
        CGRect(x: left, y: height - bottom, width: right - left, height: bottom - top)
    }

    private static func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            throw RenderError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw RenderError.encodingFailed
        }
        return data as Data
    }
}
