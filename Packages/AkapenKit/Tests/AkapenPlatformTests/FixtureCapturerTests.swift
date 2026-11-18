import AkapenCore
import CoreGraphics
import Foundation
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

    private let display = ScreenDescriptor(id: 1, frame: ScreenRect(x: 0, y: 0, width: 1440, height: 900))

    private let regions = [
        ScreenRect(x: 100, y: 80, width: 480, height: 320),
        ScreenRect(x: 0, y: 0, width: 300.5, height: 41),
    ]

    @Test
    func captureIsDeterministic() async throws {
        let capturer = FixtureCapturer(windows: windows)
        let first = try rgba(try await capturer.capture(region: regions[0], on: display))
        let second = try rgba(try await capturer.capture(region: regions[0], on: display))
        let another = try rgba(try await FixtureCapturer(windows: windows).capture(region: regions[0], on: display))
        #expect(first == second)
        #expect(first == another)
    }

    @Test
    func captureDependsOnlyOnRegionSize() async throws {
        // 範囲の位置やディスプレイが違っても、大きさが同じなら同じ画素（流した画面の配置に結果を左右させない）。
        let capturer = FixtureCapturer(windows: windows)
        let moved = ScreenRect(x: -1340, y: 500, width: 480, height: 320)
        let otherDisplay = ScreenDescriptor(id: 2, frame: ScreenRect(x: -1440, y: 0, width: 1440, height: 900))
        let first = try rgba(try await capturer.capture(region: regions[0], on: display))
        let second = try rgba(try await capturer.capture(region: moved, on: otherDisplay))
        #expect(first == second)
    }

    @Test(arguments: [1, 2, 3])
    func captureSizeIsRegionTimesScale(scale: Int) async throws {
        let capturer = FixtureCapturer(windows: windows, scale: scale)
        for region in regions {
            let image = try await capturer.capture(region: region, on: display)
            #expect(image.width == Int((region.width * Double(scale)).rounded()))
            #expect(image.height == Int((region.height * Double(scale)).rounded()))
        }
    }

    @Test
    func captureHasNoRedPixels() async throws {
        let capturer = FixtureCapturer(windows: windows)
        let image = try await capturer.capture(region: regions[0], on: display)
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
    func captureRejectsEmptyRegion() async throws {
        let capturer = FixtureCapturer(windows: windows)
        await #expect(throws: FixtureCapturer.FixtureError.emptyRegion) {
            try await capturer.capture(region: ScreenRect(x: 0, y: 0, width: 0, height: 10), on: display)
        }
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
