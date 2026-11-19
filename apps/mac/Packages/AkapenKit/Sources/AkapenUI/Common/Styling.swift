import AppKit
import SwiftUI

extension View {
    /// 文字のスタイルを当てる。資料の行の高さに合わせるため、フォントそのものの行の高さとの差を、行の上下と行間に振り分ける。
    func textStyle(_ style: TextStyle) -> some View {
        modifier(TextStyleModifier(style: style))
    }

    /// CSS の `box-shadow`（外側の影）を、角の丸い四角の外にだけ描く。
    ///
    /// CSS と同じく、影は部品の内側には描かない。半透明の地の下に影が透けて見えることはない。
    func boxShadow(_ shadows: [ShadowToken], cornerRadius: CGFloat) -> some View {
        background {
            BoxShadowLayer(shadows: shadows, cornerRadius: cornerRadius)
        }
    }

    /// 内側の輪郭線（CSS の `box-shadow: 0 0 0 Npx inset`）。
    func insetOutline(_ color: ColorToken, width: CGFloat, cornerRadius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
                .strokeBorder(color.color, lineWidth: width)
                .allowsHitTesting(false)
        }
    }

    /// akapen のパネルの見た目はライトに固定する（`DECISIONS.md` 28）。
    func lightAppearance() -> some View {
        environment(\.colorScheme, .light)
    }
}

/// `textStyle(_:)` の中身。
struct TextStyleModifier: ViewModifier {
    let style: TextStyle

    func body(content: Content) -> some View {
        let extra = max(0, style.lineHeight - TextMetrics.lineHeight(of: style))
        content
            .font(style.font)
            .tracking(style.trackingPoints)
            .lineSpacing(extra)
            .padding(.vertical, extra / 2)
    }
}

/// SwiftUI の `Text` の 1 行の高さ。
///
/// SwiftUI の行の高さはフォントの値（`NSFont` の ascender・descender）からは決まらない（大きさごとに丸め方が違う）ので、
/// スタイルごとに一度だけ実際に測って控えておく。
@MainActor enum TextMetrics {
    private static var cache: [TextStyle: CGFloat] = [:]

    static func lineHeight(of style: TextStyle) -> CGFloat {
        if let cached = cache[style] {
            return cached
        }
        let probe = NSHostingView(rootView: Text(verbatim: "Hg").font(style.font).fixedSize())
        let height = probe.fittingSize.height
        cache[style] = height
        return height
    }
}

/// 外側の影を描く層。部品と同じ大きさに置き、影がはみ出す分だけ外へ広げて描く。
struct BoxShadowLayer: View {
    let shadows: [ShadowToken]
    let cornerRadius: CGFloat

    var body: some View {
        let margin = (shadows.map(\.extent).max() ?? 0) + Tokens.Stroke.hairline
        Canvas { context, size in
            let box = CGRect(
                x: margin,
                y: margin,
                width: max(0, size.width - margin * 2),
                height: max(0, size.height - margin * 2)
            )
            // CSS では先に書いた影が手前に来るので、後ろの層から描く。
            for shadow in shadows.reversed() {
                draw(shadow, around: box, in: context)
            }
            var eraser = context
            eraser.blendMode = .clear
            eraser.fill(roundedRectPath(box, cornerRadius: cornerRadius), with: .color(.black))
        }
        .padding(-margin)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ shadow: ShadowToken, around box: CGRect, in context: GraphicsContext) {
        var layer = context
        let shape = box.insetBy(dx: -shadow.spread, dy: -shadow.spread)
        let path = roundedRectPath(shape, cornerRadius: cornerRadius + shadow.spread)
        if shadow.blur > 0 {
            // CSS のぼかしの値は、ガウスぼかしの標準偏差の 2 倍。GraphicsContext の blur の半径は標準偏差そのもの。
            // （GraphicsContext の shadow フィルタは、細い形で影が薄くなるので使わない。Paper の画像の影の濃さと比べて確かめた。）
            layer.addFilter(.blur(radius: shadow.blur / 2))
        }
        layer.fill(path.offsetBy(dx: shadow.x, dy: shadow.y), with: .color(shadow.color.color))
    }
}

/// 角丸の四角。角丸が短い辺の半分を超えるときは、両端が丸い形にする（CSS の `border-radius: 999px` と同じ）。
func roundedRectPath(_ rect: CGRect, cornerRadius: CGFloat) -> Path {
    let limit = min(rect.width, rect.height) / 2
    return Path(roundedRect: rect, cornerRadius: max(0, min(cornerRadius, limit)), style: .circular)
}

/// 角の丸い四角（CSS と同じ円弧の角）。`strokeBorder` で線を内側に描ける。
struct RoundedBox: InsettableShape {
    let cornerRadius: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        roundedRectPath(rect.insetBy(dx: insetAmount, dy: insetAmount), cornerRadius: cornerRadius - insetAmount)
    }

    func inset(by amount: CGFloat) -> RoundedBox {
        RoundedBox(cornerRadius: cornerRadius, insetAmount: insetAmount + amount)
    }
}


extension View {
    /// 背景をぼかし、白い面と細い光の縁を重ねる。
    func glassSurface(radius: CGFloat, tint: ColorToken = Tokens.Glass.panel) -> some View {
        background {
            RoundedBox(cornerRadius: radius).fill(.ultraThinMaterial)
                .overlay(RoundedBox(cornerRadius: radius).fill(tint.color))
        }
        .insetOutline(Tokens.Glass.ring, width: Tokens.Glass.ringWidth, cornerRadius: radius)
    }
}


/// パネルの段階に合わせ、部品を順番に出す。静止画では既定の shown を使う。
private struct StaggeredEntrance: ViewModifier {
    let delay: Double
    @Environment(\.panelPhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(phase == .shown ? 1 : 0)
            .offset(y: phase == .shown || reduceMotion ? 0 : Tokens.Motion.entranceRise)
            .animation(reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.panelSpring.delay(delay), value: phase)
    }
}

extension View {
    /// 親パネルより少し遅らせた出入り。
    func staggeredEntrance(delay: Double) -> some View {
        modifier(StaggeredEntrance(delay: delay))
    }
}


extension View {
    /// 上から下へ白が薄くなる、ツールバー用のガラス。
    func glassBar() -> some View {
        background {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Tokens.Glass.bar))
        }
        .insetOutline(Tokens.Glass.ring, width: Tokens.Glass.ringWidth, cornerRadius: Tokens.Radius.pill)
    }
}
