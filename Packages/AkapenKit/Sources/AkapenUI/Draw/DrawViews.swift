import SwiftUI
import AkapenCore
import AkapenAXID

/// 画面上端の案内の表示（`Drag to frame` と `esc to cancel`。App 01）。
///
/// 直前の操作が失敗したときは、1 つ目の文言を失敗の知らせ（`Couldn’t capture the screen` など）に替える。
public struct DrawHintView: View {
    private let strings: UIStrings
    private let notice: SessionFailure?
    private let showsCancel: Bool

    /// - Parameters:
    ///   - notice: 知らせる失敗。nil なら `Drag to frame`。
    ///   - showsCancel: `esc to cancel` を出すか（`Esc` が効く、枠を描く状態のときだけ）。
    public init(strings: UIStrings, notice: SessionFailure? = nil, showsCancel: Bool = true) {
        self.strings = strings
        self.notice = notice
        self.showsCancel = showsCancel
    }

    public var body: some View {
        HStack(spacing: Tokens.Hint.gap) {
            Circle()
                .fill(Tokens.Hint.dot.color)
                .frame(width: Tokens.Hint.dotSize, height: Tokens.Hint.dotSize)
            Text(notice.map(strings.failureMessage) ?? strings[.drawHint])
                .textStyle(Tokens.Typography.control)
                .foregroundStyle(Tokens.Hint.title.color)
            if showsCancel {
                Text(strings[.drawCancel])
                    .textStyle(Tokens.Typography.meta)
                    .foregroundStyle(Tokens.Hint.meta.color)
            }
        }
        .padding(.horizontal, Tokens.Hint.paddingX)
        .frame(height: Tokens.Hint.height)
        .background(Capsule().fill(Tokens.Hint.background.color))
        .boxShadow(Tokens.Hint.shadows, cornerRadius: Tokens.Radius.pill)
        .fixedSize()
        .lightAppearance()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AXID.Draw.hint)
    }
}

/// 赤枠（3pt の線を枠の内側に、accent 15% のにじみを外側に 4pt。App 01・02）。大きさは置かれた枠の大きさ。
public struct RedFrameView: View {
    /// 中身はない。大きさは親が決める。
    public init() {}

    public var body: some View {
        RoundedBox(cornerRadius: Tokens.Radius.frame)
            .strokeBorder(Tokens.Frame.stroke.color, lineWidth: Tokens.Stroke.frame)
            .boxShadow([Tokens.Frame.glow], cornerRadius: Tokens.Radius.frame)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityIdentifier(AXID.Draw.frame)
    }
}

/// 大きさの表示（`332 × 88`。App 01）。
public struct SizeLabelView: View {
    private let text: String

    /// 表示する文字列（`UIStrings.sizeLabel(width:height:)` で作る）を受け取る。
    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .textStyle(Tokens.Typography.meta)
            .foregroundStyle(Tokens.SizeLabel.text.color)
            .padding(.horizontal, Tokens.SizeLabel.paddingX)
            .frame(height: Tokens.SizeLabel.height)
            .background(Capsule().fill(Tokens.SizeLabel.background.color))
            .fixedSize()
            .lightAppearance()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AXID.Draw.sizeLabel)
    }
}

/// 枠を描く面の上に重ねる表示の値。座標はすべて画面全体を通した左上原点（`ScreenRect` と同じ）。
public struct OverlayState: Equatable, Sendable {
    /// 面を出している画面。
    public var screen: ScreenInfo
    /// 上端の案内を出すか（`drawing` のときだけ）。
    public var showsHint: Bool
    /// 赤枠。ドラッグ中の枠か、コメントを書いている間の枠。
    public var frame: ScreenRect?
    /// ドラッグ中のカーソルの位置。nil なら大きさの表示を出さない。
    public var cursor: CGPoint?
    /// 案内の表示で知らせる失敗。nil なら `Drag to frame`。
    public var notice: SessionFailure?
    /// 案内の表示に `esc to cancel` を出すか。
    public var showsCancel: Bool

    /// 画面だけを決めた、何も描いていない状態から作る。
    public init(
        screen: ScreenInfo,
        showsHint: Bool,
        frame: ScreenRect? = nil,
        cursor: CGPoint? = nil,
        notice: SessionFailure? = nil,
        showsCancel: Bool = true
    ) {
        self.screen = screen
        self.showsHint = showsHint
        self.frame = frame
        self.cursor = cursor
        self.notice = notice
        self.showsCancel = showsCancel
    }
}

/// 枠を描く面の上の表示（案内・赤枠・大きさの表示）。画面全体の大きさで描き、置き場所は `PanelPlacement` で決める。
///
/// 動きを付けるのは案内の出入りだけ（出るときはばねで、わずかに小さい大きさから）。赤枠と大きさの表示は動かさない
/// （赤枠の出入りに動きを付けると、前の枠が薄く残って見える）。
public struct OverlayView: View {
    /// 映している値。
    let state: OverlayState
    private let strings: UIStrings
    private let animated: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `animated` が false なら、案内の出入りをアニメーションしない（テスト用）。
    public init(state: OverlayState, strings: UIStrings, animated: Bool = true) {
        self.state = state
        self.strings = strings
        self.animated = animated
    }

    public var body: some View {
        OverlayLayout(state: state) {
            if let frame = state.frame {
                RedFrameView()
                    .layoutValue(key: OverlayRole.self, value: .frame)
                if state.cursor != nil {
                    SizeLabelView(text: strings.sizeLabel(
                        width: Int(frame.width.rounded()),
                        height: Int(frame.height.rounded())
                    ))
                    .layoutValue(key: OverlayRole.self, value: .sizeLabel)
                }
            }
            DrawHintView(strings: strings, notice: state.notice, showsCancel: state.showsCancel)
                .opacity(state.showsHint ? 1 : 0)
                .scaleEffect(hintScale, anchor: .top)
                .animation(hintAnimation, value: state.showsHint)
                .accessibilityHidden(!state.showsHint)
                .layoutValue(key: OverlayRole.self, value: .hint)
        }
        .frame(width: state.screen.frame.width, height: state.screen.frame.height)
        .lightAppearance()
    }

    private var hintScale: CGFloat {
        state.showsHint || reduceMotion ? 1 : Tokens.Motion.panelEntranceScale
    }

    private var hintAnimation: Animation? {
        guard animated else {
            return nil
        }
        return state.showsHint ? Tokens.Motion.panelSpring : Tokens.Motion.exitAnimation
    }
}

/// 面の上の表示の役割。置き場所の決め方を選ぶのに使う。
enum OverlayRole: LayoutValueKey {
    case hint
    case frame
    case sizeLabel

    static let defaultValue = OverlayRole.frame
}

/// 面の上の表示を、`PanelPlacement` の決まりで置く。画面全体の座標から、面の中の座標へは画面の左上を引いて直す。
struct OverlayLayout: Layout {
    let state: OverlayState

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: state.screen.frame.width, height: state.screen.frame.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            guard let rect = rect(for: subview) else {
                continue
            }
            let origin = CGPoint(
                x: bounds.minX + rect.x - state.screen.frame.x,
                y: bounds.minY + rect.y - state.screen.frame.y
            )
            subview.place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }

    private func rect(for subview: LayoutSubview) -> ScreenRect? {
        switch subview[OverlayRole.self] {
        case .hint:
            let size = subview.sizeThatFits(.unspecified)
            return PanelPlacement.hint(size: size, visibleFrame: state.screen.visibleFrame)
        case .frame:
            return state.frame
        case .sizeLabel:
            guard let cursor = state.cursor else {
                return nil
            }
            let size = subview.sizeThatFits(.unspecified)
            return PanelPlacement.sizeLabel(size: size, cursor: cursor, visibleFrame: state.screen.visibleFrame)
        }
    }
}
