import CoreGraphics
import Foundation
import AkapenCore

/// 決まったウィンドウの一覧と、決まった絵の画像を返す偽の撮影。E2E と結合テスト用。
///
/// 絵は、明るい地に薄い格子と、四隅の目印。赤い画素は含めない（描き込まれた赤枠を、赤い画素の外接矩形で探せるように）。
/// 同じウィンドウの大きさと倍率なら、毎回 1 バイトも違わない PNG を返す。
@MainActor public final class FixtureCapturer: WindowCapturing {
    /// 画像を作れないときのエラー。
    public enum FixtureError: Error, Equatable {
        /// ウィンドウの大きさが 1 ピクセルに満たない。
        case emptyWindow
        /// 画像の生成に失敗した。
        case renderingFailed
    }

    /// 格子の間隔（pt）。
    static let gridSpacing = 40
    /// 四隅の目印の一辺（pt）。
    static let markerSize = 16

    /// 地の色。どの色も R が G と B を超えないようにして、赤と見分ける。
    static let backgroundColor: [UInt8] = [246, 247, 249]
    /// 格子の色。
    static let gridColor: [UInt8] = [222, 226, 232]
    /// 四隅の目印の色（左上・右上・左下・右下）。
    static let markerColors: [[UInt8]] = [
        [40, 90, 200],
        [30, 140, 90],
        [90, 90, 110],
        [20, 110, 160],
    ]

    private let fixedWindows: [CaptureWindow]
    private let scale: Int

    /// 返すウィンドウの一覧（手前から順）と、画像の倍率（Retina 相当なら 2）を渡す。
    public init(windows: [CaptureWindow], scale: Int = 2) {
        fixedWindows = windows
        self.scale = max(1, scale)
    }

    /// 渡された一覧をそのまま返す。
    public func windows() async throws -> [CaptureWindow] {
        fixedWindows
    }

    /// 「ウィンドウの大きさ × 倍率」の PNG を返す。
    public func capture(window: CaptureWindow) async throws -> Data {
        try Self.render(width: window.frame.width, height: window.frame.height, scale: scale)
    }

    /// 決まった絵の PNG を作る。大きさは pt、`scale` を掛けてピクセルにする。
    static func render(width: Double, height: Double, scale: Int) throws -> Data {
        let pixelWidth = Int((width * Double(scale)).rounded())
        let pixelHeight = Int((height * Double(scale)).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else {
            throw FixtureError.emptyWindow
        }
        let pixels = pixelBuffer(width: pixelWidth, height: pixelHeight, scale: scale)
        guard let image = makeImage(pixels: pixels, width: pixelWidth, height: pixelHeight) else {
            throw FixtureError.renderingFailed
        }
        do {
            return try PNGEncoding.encode(image)
        } catch {
            throw FixtureError.renderingFailed
        }
    }

    /// RGBX（1 画素 4 バイト、4 バイト目は使わない）の画素の並び。
    private static func pixelBuffer(width: Int, height: Int, scale: Int) -> [UInt8] {
        let spacing = gridSpacing * scale
        var plainRow = [UInt8](repeating: 255, count: width * 4)
        for x in 0..<width {
            let color = x % spacing == 0 ? gridColor : backgroundColor
            setPixel(&plainRow, offset: x * 4, color: color)
        }
        var lineRow = [UInt8](repeating: 255, count: width * 4)
        for x in 0..<width {
            setPixel(&lineRow, offset: x * 4, color: gridColor)
        }
        var pixels = [UInt8]()
        pixels.reserveCapacity(width * height * 4)
        for y in 0..<height {
            pixels.append(contentsOf: y % spacing == 0 ? lineRow : plainRow)
        }
        let marker = min(markerSize * scale, width, height)
        let corners = [
            (0, 0),
            (width - marker, 0),
            (0, height - marker),
            (width - marker, height - marker),
        ]
        for (corner, color) in zip(corners, markerColors) {
            for y in corner.1..<(corner.1 + marker) {
                for x in corner.0..<(corner.0 + marker) {
                    setPixel(&pixels, offset: (y * width + x) * 4, color: color)
                }
            }
        }
        return pixels
    }

    private static func setPixel(_ pixels: inout [UInt8], offset: Int, color: [UInt8]) {
        pixels[offset] = color[0]
        pixels[offset + 1] = color[1]
        pixels[offset + 2] = color[2]
        pixels[offset + 3] = 255
    }

    private static func makeImage(pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
