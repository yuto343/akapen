import SwiftUI
import AkapenAXID

/// コピー完了の表示（App 04）。画面下のボタン類と同じ白いピルの中に、緑のチェックと `Prompt copied!` の黒いピルを置く。
///
/// 出入りの動き（`Tokens.Motion` の `toast*`）はこの部品が付ける。パネル（`PanelRoot`）から渡される段階（`PanelPhase`）に合わせて動く。
/// - 出るとき: 箱が少し小さく・ぼけた・少し下の状態から、ばねで等倍・くっきりへ。少し遅れてチェックの印が描かれ、続いて文言が現れる。
/// - 消えるとき: 出るときより速く、わずかに縮み、ぼけながら消える。
/// - 「視差効果を減らす」がオンのときは、不透明度だけで出入りする。
///
/// 件数（`SessionModel.lastCopiedCount`）は画面には出さず、読み上げの文言に入れる。
public struct CopiedView: View {
    private let count: Int
    private let strings: UIStrings
    /// 決まった見た目で止めて描くとき（見比べの PNG で、動きの途中のコマを描く）。nil なら段階に合わせて動く。
    private let frozen: ToastAppearance?
    @Environment(\.panelPhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// コピーした注釈の件数と、文言の言語を受け取る。
    public init(count: Int, strings: UIStrings) {
        self.init(count: count, strings: strings, frozen: nil)
    }

    /// 見た目を止めて描く。テスト用。
    init(count: Int, strings: UIStrings, frozen: ToastAppearance?) {
        self.count = count
        self.strings = strings
        self.frozen = frozen
    }

    public var body: some View {
        let look = appearance
        HStack(spacing: Tokens.Toast.gap) {
            checkCircle(trim: look.checkTrim)
            Text(strings[.copiedTitle])
                .textStyle(Tokens.Typography.control)
                .foregroundStyle(Tokens.Toast.title.color)
                .fixedSize()
                .opacity(look.labelOpacity)
                .offset(x: look.labelOffsetX)
                .animation(labelAnimation, value: phase)
        }
        .padding(.leading, Tokens.Toast.pillPaddingLeading)
        .padding(.trailing, Tokens.Toast.pillPaddingTrailing)
        .frame(height: Tokens.Toast.pillHeight)
        .background(Capsule().fill(Tokens.Glass.ink))
        .padding(Tokens.Toast.padding)
        .glassBar()
        .boxShadow(Tokens.Toast.shadows, cornerRadius: Tokens.Radius.pill)
        .fixedSize()
        .scaleEffect(look.scale)
        .blur(radius: look.blur)
        .offset(y: look.offsetY)
        .opacity(look.opacity)
        .animation(boxAnimation, value: phase)
        .lightAppearance()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier(AXID.Copied.message)
    }

    /// 読み上げの文言。画面に出さない件数と次の行動も入れる（`Prompt copied! 2 annotations · paste it into your AI agent`）。
    private var accessibilityText: String {
        strings[.copiedTitle] + " " + strings.plural(.copiedSummary, count: count)
    }

    private func checkCircle(trim: CGFloat) -> some View {
        IconShape(glyph: .check)
            .trim(from: 0, to: trim)
            .stroke(
                Tokens.Toast.checkIcon.color,
                style: StrokeStyle(
                    lineWidth: Tokens.Stroke.checkIcon * Tokens.Toast.checkIconSize / IconGlyph.check.viewBox,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: Tokens.Toast.checkIconSize, height: Tokens.Toast.checkIconSize)
            .animation(checkAnimation, value: phase)
            .frame(width: Tokens.Toast.checkCircleSize, height: Tokens.Toast.checkCircleSize)
            .background(Circle().fill(Tokens.Glass.green))
            .accessibilityHidden(true)
    }

    private var appearance: ToastAppearance {
        frozen ?? ToastAppearance.of(phase, reduceMotion: reduceMotion)
    }

    /// 箱の動き。出るときはばね、消えるときは速めの ease-in。出る前へ戻すときは動かさない。
    private var boxAnimation: Animation? {
        guard frozen == nil else {
            return nil
        }
        switch phase {
        case .hidden:
            return nil
        case .shown:
            return reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.toastSpring
        case .leaving:
            return reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.toastExitAnimation
        }
    }

    /// チェックの印の描き順の動き。出るときだけ動かす。
    private var checkAnimation: Animation? {
        guard frozen == nil, phase == .shown, !reduceMotion else {
            return nil
        }
        return Tokens.Motion.toastCheckAnimation
    }

    /// 文言の動き。出るときだけ動かす。
    private var labelAnimation: Animation? {
        guard frozen == nil, phase == .shown, !reduceMotion else {
            return nil
        }
        return Tokens.Motion.toastLabelAnimation
    }
}

/// コピー完了の表示の、ある瞬間の見た目。
struct ToastAppearance: Equatable {
    /// 箱の大きさ（1 が等倍）。
    var scale: CGFloat
    /// 箱のぼかし（pt）。
    var blur: CGFloat
    /// 箱を下へずらす量（pt）。
    var offsetY: CGFloat
    /// 箱の不透明度。
    var opacity: Double
    /// チェックの印を描き終えた割合（0〜1）。
    var checkTrim: CGFloat
    /// 文言の不透明度。
    var labelOpacity: Double
    /// 文言を横へずらす量（pt。負なら左）。
    var labelOffsetX: CGFloat

    /// 出ている。
    static let shown = ToastAppearance(scale: 1, blur: 0, offsetY: 0, opacity: 1, checkTrim: 1, labelOpacity: 1, labelOffsetX: 0)

    /// 出しはじめ。少し小さく、ぼけて、少し下。チェックはまだ描かれておらず、文言も見えない。
    static let entering = ToastAppearance(
        scale: Tokens.Motion.toastEntranceScale,
        blur: Tokens.Motion.toastEntranceBlur,
        offsetY: Tokens.Motion.toastRise,
        opacity: 0,
        checkTrim: 0,
        labelOpacity: 0,
        labelOffsetX: -Tokens.Motion.toastLabelShift
    )

    /// 消え終わり。わずかに縮み、ぼけて、見えない。
    static let leaving = ToastAppearance(
        scale: Tokens.Motion.toastExitScale,
        blur: Tokens.Motion.toastExitBlur,
        offsetY: 0,
        opacity: 0,
        checkTrim: 1,
        labelOpacity: 1,
        labelOffsetX: 0
    )

    /// 「視差効果を減らす」がオンのときの、出しはじめと消え終わり（不透明度だけ）。
    static let faded = ToastAppearance(scale: 1, blur: 0, offsetY: 0, opacity: 0, checkTrim: 1, labelOpacity: 1, labelOffsetX: 0)

    /// 段階ごとの見た目。
    static func of(_ phase: PanelPhase, reduceMotion: Bool) -> ToastAppearance {
        switch phase {
        case .shown:
            shown
        case .hidden:
            reduceMotion ? faded : entering
        case .leaving:
            reduceMotion ? faded : leaving
        }
    }
}
