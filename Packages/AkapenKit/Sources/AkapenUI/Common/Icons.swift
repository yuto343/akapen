import SwiftUI

/// 画面で使うアイコン。形は Paper の SVG を写したもの（`components.md`・`app-03-list.md`、2026-11-19 の調節分は `.director/design-v2/changes.md`）。
///
/// viewBox は鉛筆とゴミ箱が 24×24、それ以外は 14×14。
enum IconGlyph {
    /// 「+」。
    case plus
    /// 「List」の 3 本線と点。
    case list
    /// 右上向きの矢印（Open System Settings）。
    case arrowUpRight
    /// 重なった 2 枚の四角（Copy prompt）。
    case copy
    /// 右向きの矢印（Continue）。
    case arrowRight
    /// チェックの印（コピー完了の表示。セットアップを終える `Done` にも使う）。
    case check
    /// 鉛筆（一覧の編集）。
    case pencil
    /// ゴミ箱（一覧の削除）。
    case trash

    /// SVG の viewBox の一辺。
    var viewBox: CGFloat {
        switch self {
        case .pencil, .trash:
            24
        case .plus, .list, .arrowUpRight, .copy, .arrowRight, .check:
            14
        }
    }

    /// 鉛筆（Paper の SVG の `d`。viewBox 24）。
    private static let pencilData = "M21.17 6.81a2.82 2.82 0 0 0-3.99-3.99L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.36a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z M15 5l4 4"

    /// ゴミ箱（Paper の SVG の `d`。viewBox 24）。
    private static let trashData = "M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M10 11v6M14 11v6"

    /// コピーの後ろの 1 枚（Paper の SVG の `d`。前の 1 枚は角丸の四角で描く）。
    private static let copyBackData = "M9.25 4.75V3.4c0-.9-.7-1.6-1.6-1.6H3.4c-.9 0-1.6.7-1.6 1.6v4.25c0 .9.7 1.6 1.6 1.6h1.35"

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
        case .copy:
            path.addRoundedRect(
                in: CGRect(x: 4.75, y: 4.75, width: 7.5, height: 7.5),
                cornerSize: CGSize(width: 1.6, height: 1.6)
            )
            path.addPath(SVGPath.parse(Self.copyBackData))
        case .check:
            path.move(to: CGPoint(x: 3, y: 7.5))
            path.addLine(to: CGPoint(x: 6, y: 10.5))
            path.addLine(to: CGPoint(x: 11, y: 4))
        case .pencil:
            path = SVGPath.parse(Self.pencilData)
        case .trash:
            path = SVGPath.parse(Self.trashData)
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

    /// 線の端。どのアイコンも丸い。
    var lineCap: CGLineCap {
        .round
    }

    var lineJoin: CGLineJoin {
        switch self {
        case .plus, .list, .copy:
            .miter
        case .arrowUpRight, .arrowRight, .check, .pencil, .trash:
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
            let scale = canvasSize.width / glyph.viewBox
            context.scaleBy(x: scale, y: scale)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: glyph.lineCap, lineJoin: glyph.lineJoin)
            context.stroke(glyph.strokePath, with: .color(color.color), style: style)
            context.fill(glyph.fillPath, with: .color(color.color))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// アイコンの線を描く形。`trim` で線の描き順の動き（チェックの印を描く）に使う。
struct IconShape: Shape {
    let glyph: IconGlyph

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / glyph.viewBox
        return glyph.strokePath.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: rect.minX / scale, y: rect.minY / scale))
    }
}

/// アプリのアイコン（タイル付き）。`assets/logo/akapen-logo-short-tile.png` を縮めてリソースに入れたもの。
@MainActor enum AppIconImage {
    static let image: NSImage? = Bundle.module.image(forResource: "AppIcon")
}

/// アプリのアイコンを指定の大きさで描く。画像が読めないときは、同じ大きさの空きにする。
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let image = AppIconImage.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Color.clear
                .frame(width: size, height: size)
        }
    }
}
