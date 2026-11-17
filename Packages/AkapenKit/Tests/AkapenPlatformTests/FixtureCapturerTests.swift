import AkapenCore
import CoreGraphics
import Foundation
import ImageIO
import Testing
import AkapenPlatform

@MainActor
struct FixtureCapturerTests {
    private let windows = [
        CaptureWindow(id: 10, frame: ScreenRect(x: 100, y: 80, width: 480, height: 320), appName: "Sample App", title: "Sample"),
        CaptureWindow(id: 11, frame: ScreenRect(x: 0, y: 0, width: 300.5, height: 41), appName: "Other"),
    ]

    @Test
    func windowsReturnsGivenList() async throws {
        let capturer = FixtureCapturer(windows: windows)
        #expect(try await capturer.windows() == windows)
    }

    @Test
    func captureIsDeterministic() async throws {
        let capturer = FixtureCapturer(windows: windows)
        let first = try await capturer.capture(window: windows[0])
        let second = try await capturer.capture(window: windows[0])
        let another = try await FixtureCapturer(windows: windows).capture(window: windows[0])
        #expect(first == second)
        #expect(first == another)
    }

    @Test(arguments: [1, 2, 3])
    func captureSizeIsWindowTimesScale(scale: Int) async throws {
        let capturer = FixtureCapturer(windows: windows, scale: scale)
        for window in windows {
            let image = try decode(try await capturer.capture(window: window))
            #expect(image.width == Int((window.frame.width * Double(scale)).rounded()))
            #expect(image.height == Int((window.frame.height * Double(scale)).rounded()))
        }
    }

    @Test
    func captureHasNoRedPixels() async throws {
        let capturer = FixtureCapturer(windows: windows)
        let image = try decode(try await capturer.capture(window: windows[0]))
        let pixels = try rgba(image)
        var redCount = 0
        var colors = Set<UInt32>()
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let red = pixels[offset]
            let green = pixels[offset + 1]
            let blue = pixels[offset + 2]
            if red > green || red > blue {
                redCount += 1
            }
            colors.insert(UInt32(red) << 16 | UInt32(green) << 8 | UInt32(blue))
        }
        #expect(redCount == 0)
        // 地・格子・四隅の目印が入っている。
        #expect(colors.count >= 6)
    }

    @Test
    func captureRejectsEmptyWindow() async throws {
        let empty = CaptureWindow(id: 1, frame: ScreenRect(x: 0, y: 0, width: 0, height: 10), appName: "Empty")
        let capturer = FixtureCapturer(windows: [empty])
        await #expect(throws: FixtureCapturer.FixtureError.emptyWindow) {
            try await capturer.capture(window: empty)
        }
    }

    private func decode(_ png: Data) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == "public.png")
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        #expect(drawn)
        return pixels
    }
}
