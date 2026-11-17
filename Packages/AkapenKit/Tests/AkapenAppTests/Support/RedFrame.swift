import CoreGraphics
import Foundation
import ImageIO
import AkapenCore

/// 保存された画像の大きさと、赤い画素の外接矩形。
struct SavedImage {
    let pixelWidth: Int
    let pixelHeight: Int
    /// 赤い画素（`#FF3E3E` に近い画素）の外接矩形（px、左上が原点）。なければ nil。
    let redBounds: CGRect?

    /// PNG を読む。読めなければ nil。
    init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        pixelWidth = image.width
        pixelHeight = image.height
        redBounds = Self.redBounds(of: image)
    }

    /// 赤い画素の外接矩形を、ウィンドウに対する pt の矩形にする。
    func redFrameInWindow(_ window: ScreenRect) -> CGRect? {
        guard let redBounds else {
            return nil
        }
        let scale = Double(pixelWidth) / window.width
        return CGRect(
            x: redBounds.minX / scale,
            y: redBounds.minY / scale,
            width: redBounds.width / scale,
            height: redBounds.height / scale
        )
    }

    /// 描いた枠から見込む、赤い画素の外接矩形（ウィンドウに対する pt）。赤枠は枠の外側に描くので、線の太さの分だけ広い。
    func expectedRedFrame(drawn rect: ScreenRect, window: ScreenRect) -> CGRect {
        let pixelsPerPoint = Double(pixelWidth) / window.width
        let stroke = max(
            Double(FrameRenderer.minimumStrokeWidthInPixels),
            (FrameRenderer.strokeWidthInPoints * pixelsPerPoint).rounded()
        ) / pixelsPerPoint
        return CGRect(
            x: rect.x - window.x - stroke,
            y: rect.y - window.y - stroke,
            width: rect.width + stroke * 2,
            height: rect.height + stroke * 2
        )
    }

    private static func redBounds(of image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixels,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = Int.max
        var minY = Int.max
        var maxX = Int.min
        var maxY = Int.min
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let red = pixels[offset]
                let green = pixels[offset + 1]
                let blue = pixels[offset + 2]
                guard red >= 200, green <= 110, blue <= 110 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard minX <= maxX else {
            return nil
        }
        // CGContext の画素の並びは上の行から（左上が原点）。
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

/// 2 つの矩形が、辺ごとに `tolerance` 以内で一致するか。
func rectsMatch(_ actual: CGRect?, _ expected: CGRect, tolerance: Double) -> Bool {
    guard let actual else {
        return false
    }
    return abs(actual.minX - expected.minX) <= tolerance
        && abs(actual.minY - expected.minY) <= tolerance
        && abs(actual.maxX - expected.maxX) <= tolerance
        && abs(actual.maxY - expected.maxY) <= tolerance
}
