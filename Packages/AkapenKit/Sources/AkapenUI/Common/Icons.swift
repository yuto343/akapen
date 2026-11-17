import SwiftUI

/// 画面で使うアイコン。形は Paper の SVG（viewBox 0 0 14 14）を写したもの（`components.md`・`app-03-list.md`）。
enum IconGlyph {
    /// 「+」。
    case plus
    /// 「List」の 3 本線と点。
    case list
    /// 右上向きの矢印（Copy prompt・Open System Settings）。
    case arrowUpRight
    /// 右向きの矢印（Continue）。
    case arrowRight
    /// 鉛筆（一覧の編集）。
    case pencil
    /// ゴミ箱（一覧の削除）。
    case trash

    /// SVG の viewBox の一辺。
    static let viewBox: CGFloat = 14

    /// 線で描く部分。
    var strokePath: Path {
        var path = Path()
        switch self {
        case .plus:
            path.move(to: CGPoint(x: 7, y: 2))
            path.addLine(to: CGPoint(x: 7, y: 12))
            path.move(to: CGPoint(x: 2, y: 7))
            path.addLine(to: CGPoint(x: 12, y: 7))
        case .list:
            for y in [3.5, 7, 10.5] {
                path.move(to: CGPoint(x: 5, y: y))
                path.addLine(to: CGPoint(x: 12, y: y))
            }
        case .arrowUpRight:
            path.move(to: CGPoint(x: 4, y: 10))
            path.addLine(to: CGPoint(x: 10, y: 4))
            path.move(to: CGPoint(x: 5, y: 4))
            path.addLine(to: CGPoint(x: 10, y: 4))
            path.addLine(to: CGPoint(x: 10, y: 9))
        case .arrowRight:
            path.move(to: CGPoint(x: 3, y: 7))
            path.addLine(to: CGPoint(x: 11, y: 7))
            path.move(to: CGPoint(x: 7.5, y: 3.5))
            path.addLine(to: CGPoint(x: 11, y: 7))
            path.addLine(to: CGPoint(x: 7.5, y: 10.5))
        case .pencil:
            path.move(to: CGPoint(x: 9.5, y: 2.5))
            path.addLine(to: CGPoint(x: 11.5, y: 4.5))
            path.addLine(to: CGPoint(x: 5, y: 11))
            path.addLine(to: CGPoint(x: 3, y: 11))
            path.addLine(to: CGPoint(x: 3, y: 9))
            path.closeSubpath()
        case .trash:
            path.move(to: CGPoint(x: 3, y: 4))
            path.addLine(to: CGPoint(x: 11, y: 4))
            path.move(to: CGPoint(x: 5.5, y: 4))
            path.addLine(to: CGPoint(x: 5.5, y: 2.5))
            path.addLine(to: CGPoint(x: 8.5, y: 2.5))
            path.addLine(to: CGPoint(x: 8.5, y: 4))
            path.move(to: CGPoint(x: 4, y: 4))
            path.addLine(to: CGPoint(x: 4.6, y: 11.5))
            path.addLine(to: CGPoint(x: 9.4, y: 11.5))
            path.addLine(to: CGPoint(x: 10, y: 4))
        }
        return path
    }

    /// 塗りで描く部分。
    var fillPath: Path {
        var path = Path()
        if self == .list {
            for y in [3.5, 7, 10.5] {
                path.addEllipse(in: CGRect(x: 1, y: y - 1, width: 2, height: 2))
            }
        }
        return path
    }

    var lineCap: CGLineCap {
        self == .pencil ? .butt : .round
    }

    var lineJoin: CGLineJoin {
        switch self {
        case .plus, .list:
            .miter
        case .arrowUpRight, .arrowRight, .pencil, .trash:
            .round
        }
    }
}

/// アイコンを指定の大きさで描く。線の太さは SVG と同じく viewBox の単位で指定し、大きさに合わせて縮む。
struct IconView: View {
    let glyph: IconGlyph
    let size: CGFloat
    let color: ColorToken
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / IconGlyph.viewBox
            context.scaleBy(x: scale, y: scale)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: glyph.lineCap, lineJoin: glyph.lineJoin)
            context.stroke(glyph.strokePath, with: .color(color.color), style: style)
            context.fill(glyph.fillPath, with: .color(color.color))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// アプリのアイコン（タイル付き）。`assets/logo/akapen-logo-short-tile.png` を縮めてリソースに入れたもの。
@MainActor enum AppIconImage {
    static let image: NSImage? = Bundle.module.image(forResource: "AppIcon")
}
