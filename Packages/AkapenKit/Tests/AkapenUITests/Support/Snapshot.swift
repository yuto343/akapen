import AppKit
import SwiftUI
import AkapenCore
@testable import AkapenUI

/// 見比べ用の PNG の書き出し。書き出すだけで、画素の一致は確かめない。
@MainActor enum Snapshot {
    /// リポジトリの `build/ui-snapshots/`。
    static let directory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("build/ui-snapshots")

    /// Paper から書き出した画像（`.director/design/img/`）。ないときは並べ比べを作らない。
    static let paperDirectory: URL = directory
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(".director/design/img")

    /// SwiftUI の部品を画面外のウィンドウに置いて描き、ビットマップにする。
    static func render<V: View>(_ view: V, size: CGSize? = nil) async throws -> NSBitmapImageRep {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: view.lightAppearance())
        host.sizingOptions = [.intrinsicContentSize]
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        for _ in 0..<3 {
            let target = size ?? host.intrinsicContentSize
            window.setFrame(NSRect(x: -20_000, y: -20_000, width: target.width, height: target.height), display: false)
            host.frame = NSRect(origin: .zero, size: target)
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(80))
        }
        host.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw SnapshotError.renderFailed
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep
    }

    /// 実際のウィンドウを、タイトルバー（信号ボタン）ごと描く。ウィンドウは画面の外へ動かしてから描く。
    ///
    /// 信号ボタンはシステムが描くので、アプリが前面にないテストの中では灰色（使えない見た目）になる。
    /// ウィンドウの角丸と影はウィンドウサーバーが描くので、ここには入らない（並べるときに `WindowSnapshot` で付ける）。
    static func renderWindow(_ window: NSWindow) async throws -> NSBitmapImageRep {
        _ = NSApplication.shared
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        for _ in 0..<4 {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(80))
        }
        guard let frameView = window.contentView?.superview else {
            throw SnapshotError.renderFailed
        }
        frameView.display()
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else {
            throw SnapshotError.renderFailed
        }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        return rep
    }

    /// 書き出す。戻り値は書き出したファイル。
    @discardableResult
    static func write(_ rep: NSBitmapImageRep, to name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw SnapshotError.encodeFailed
        }
        try data.write(to: url)
        return url
    }

    /// Paper の画像（左）と、こちらの画面（右）を並べた画像を書き出す。
    static func writeComparison(paper name: String, ours: NSBitmapImageRep, to output: String) throws {
        let paperURL = paperDirectory.appendingPathComponent(name)
        guard let paper = NSImage(contentsOf: paperURL) else {
            return
        }
        let width = 1280
        let height = 800
        guard let canvas = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width * 2,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw SnapshotError.renderFailed
        }
        canvas.size = NSSize(width: width * 2, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
        NSGraphicsContext.current?.imageInterpolation = .high
        paper.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        ours.draw(in: NSRect(x: width, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        try write(canvas, to: output)
    }
}

enum SnapshotError: Error {
    case renderFailed
    case encodeFailed
}

/// テスト用の画像。
enum SnapshotImages {
    /// Sample App 風のウィンドウの画像（PNG）。`frame` の外側に赤枠を描く（撮影した画像の代わり）。
    static func mockWindowPNG(size: CGSize, frame: CGRect) -> Data {
        let width = Int(size.width)
        let height = Int(size.height)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: 52))
        context.fill(CGRect(x: 0, y: 52, width: 200, height: size.height - 52))
        context.setFillColor(CGColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1))
        for row in 0..<4 {
            context.fill(CGRect(x: 240, y: 100 + CGFloat(row) * 110, width: 420, height: 30))
        }
        context.setFillColor(CGColor(red: 0.17, green: 0.38, blue: 0.80, alpha: 1))
        context.fill(CGRect(x: size.width - 132, y: size.height - 230, width: 92, height: 30))
        context.setStrokeColor(CGColor(red: 1, green: 0.243, blue: 0.243, alpha: 1))
        context.setLineWidth(6)
        context.stroke(frame.insetBy(dx: -3, dy: -3))
        let image = context.makeImage()!
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])!
    }

    /// 撮影した画像の代わりのサムネイル（切り抜き済み）。
    static func thumbnail(for annotation: Annotation) -> NSImage {
        let windowSize = CGSize(width: annotation.windowFrame.width, height: annotation.windowFrame.height)
        let frame = CGRect(
            x: annotation.rect.x - annotation.windowFrame.x,
            y: annotation.rect.y - annotation.windowFrame.y,
            width: annotation.rect.width,
            height: annotation.rect.height
        )
        let data = mockWindowPNG(size: windowSize, frame: frame)
        let source = CGImageSourceCreateWithData(data as CFData, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let crop = ThumbnailCrop.rect(
            imageSize: windowSize,
            windowFrame: annotation.windowFrame,
            frame: annotation.rect,
            aspect: Tokens.List.thumbnailWidth / Tokens.List.thumbnailHeight
        )
        let cropped = image.cropping(to: crop)!
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }
}

/// 画面の中での置き方（見比べ用の画面を組むのに使う）。
enum ScenePlacement: LayoutValueKey {
    case fill
    case bottomCenter
    case list(toolbar: ScreenRect)
    case comment(frame: ScreenRect)
    /// 左上を決まった位置に置く（Paper の座標）。
    case at(x: Double, y: Double)

    static let defaultValue = ScenePlacement.fill
}

/// Paper のアートボードと同じ 1280×800 の画面に、部品を `PanelPlacement` の決まりで置く。
struct SceneLayout: Layout {
    let screen: ScreenInfo

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: screen.frame.width, height: screen.frame.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let rect: ScreenRect
            switch subview[ScenePlacement.self] {
            case .fill:
                rect = screen.frame
            case .bottomCenter:
                rect = PanelPlacement.bottomCenter(size: size, visibleFrame: screen.visibleFrame)
            case let .list(toolbar):
                rect = PanelPlacement.list(size: size, toolbar: toolbar, visibleFrame: screen.visibleFrame)
            case let .comment(frame):
                rect = PanelPlacement.comment(size: size, frame: frame, visibleFrame: screen.visibleFrame)
            case let .at(x, y):
                rect = ScreenRect(x: x, y: y, width: size.width, height: size.height)
            }
            subview.place(
                at: CGPoint(x: bounds.minX + rect.x - screen.frame.x, y: bounds.minY + rect.y - screen.frame.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }
}

/// 見比べ用の背景（Paper の絵の、デスクトップと Sample App のウィンドウに似せたもの）。
struct SceneBackdrop: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.93, blue: 0.95), Color(red: 0.86, green: 0.87, blue: 0.91)],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(Color(red: 0.98, green: 0.98, blue: 0.98))
                .frame(height: 28)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
                .frame(width: 1000, height: 660)
                .offset(x: 140, y: 64)
        }
        .frame(width: 1280, height: 800)
    }
}

/// 描いたウィンドウの画像に、ウィンドウの角丸（12）と影（`Tokens.Window.shadows`）を付けて並べる。
struct WindowSnapshot: View {
    let rep: NSBitmapImageRep

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .frame(width: rep.size.width, height: rep.size.height)
            .clipShape(RoundedBox(cornerRadius: Tokens.Radius.media))
            .boxShadow(Tokens.Window.shadows, cornerRadius: Tokens.Radius.media)
            .fixedSize()
    }

    private var image: NSImage {
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
