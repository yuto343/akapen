import CoreGraphics
import Foundation
import ImageIO

/// テスト用の画像の作成と、画素の読み取り。すべて sRGB の 8bit RGBA。
enum TestImages {
    struct RGB: Equatable {
        var red: UInt8
        var green: UInt8
        var blue: UInt8
    }

    /// 画素の位置（左上原点、px）による外接矩形。両端を含む。
    struct PixelBox: Equatable {
        var minX: Int
        var minY: Int
        var maxX: Int
        var maxY: Int
    }

    /// 撮影した画像の地の色。
    static let blue = RGB(red: 0x20, green: 0x60, blue: 0xC0)

    /// 赤枠の色（#FF3E3E）。
    static let frameRed = RGB(red: 0xFF, green: 0x3E, blue: 0x3E)

    static var sRGB: CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB)!
    }

    /// 単色の PNG を作る。
    static func solidPNG(width: Int, height: Int, color: RGB) -> Data {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(
            CGColor(
                colorSpace: sRGB,
                components: [
                    CGFloat(color.red) / 255,
                    CGFloat(color.green) / 255,
                    CGFloat(color.blue) / 255,
                    1,
                ]
            )!
        )
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        _ = CGImageDestinationFinalize(destination)
        return data as Data
    }

    /// PNG を読み、画素を左上から行ごとに並べた形で返す。
    static func decode(_ png: Data) -> Bitmap? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            return nil
        }
        return Bitmap(width: width, height: height, bytes: bytes)
    }

    struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func pixel(x: Int, y: Int) -> RGB {
            let offset = (y * width + x) * 4
            return RGB(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
        }

        /// 赤枠の色の画素の外接矩形。1 つもなければ nil。
        func frameRedBox() -> PixelBox? {
            var box: PixelBox?
            for y in 0..<height {
                for x in 0..<width where isFrameRed(pixel(x: x, y: y)) {
                    if var current = box {
                        current.minX = min(current.minX, x)
                        current.minY = min(current.minY, y)
                        current.maxX = max(current.maxX, x)
                        current.maxY = max(current.maxY, y)
                        box = current
                    } else {
                        box = PixelBox(minX: x, minY: y, maxX: x, maxY: y)
                    }
                }
            }
            return box
        }

        /// 指定した範囲（両端を含む）の画素がすべて `color` か。
        func allPixels(in box: PixelBox, are color: RGB) -> Bool {
            for y in box.minY...box.maxY {
                for x in box.minX...box.maxX where pixel(x: x, y: y) != color {
                    return false
                }
            }
            return true
        }

        private func isFrameRed(_ rgb: RGB) -> Bool {
            abs(Int(rgb.red) - Int(frameRed.red)) <= 2
                && abs(Int(rgb.green) - Int(frameRed.green)) <= 2
                && abs(Int(rgb.blue) - Int(frameRed.blue)) <= 2
        }
    }
}
