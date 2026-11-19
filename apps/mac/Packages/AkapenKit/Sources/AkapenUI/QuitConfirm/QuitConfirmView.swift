import SwiftUI
import AkapenCore
import AkapenAXID

/// 終了確認の箱（アイコン、`Quit akapen?`、件数入りの説明、赤い `Quit` と `Cancel`。App 09）。
public struct ConfirmationView: View {
    private let purpose: ConfirmationPurpose
    private let annotationCount: Int
    private let strings: UIStrings
    private let onQuit: () -> Void
    private let onCancel: () -> Void

    /// 未コピーの注釈の件数、文言の言語、押されたときのコールバックを受け取る。
    public init(
        annotationCount: Int,
        purpose: ConfirmationPurpose = .quit,
        strings: UIStrings,
        onQuit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.purpose = purpose
        self.annotationCount = annotationCount
        self.strings = strings
        self.onQuit = onQuit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: Tokens.QuitAlert.gap) {
            AppIconView(size: Tokens.QuitAlert.iconSize)
            VStack(spacing: Tokens.QuitAlert.textGap) {
                Text(strings[purpose.titleKey])
                    .textStyle(Tokens.Typography.alertTitle)
                    .foregroundStyle(Tokens.QuitAlert.title.color)
                Text(strings.plural(purpose.messageKey, count: annotationCount))
                    .textStyle(Tokens.Typography.alertBody)
                    .foregroundStyle(Tokens.QuitAlert.body.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(purpose.messageID)
            }
            .multilineTextAlignment(.center)
            VStack(spacing: Tokens.QuitAlert.buttonGap) {
                quitButton
                cancelButton
            }
        }
        .padding(.top, Tokens.QuitAlert.paddingTop)
        .padding(.horizontal, Tokens.QuitAlert.paddingX)
        .padding(.bottom, Tokens.QuitAlert.paddingBottom)
        .frame(width: Tokens.QuitAlert.width)
        .glassSurface(radius: Tokens.Radius.alert, tint: Tokens.Glass.window)
        .boxShadow(Tokens.QuitAlert.shadows, cornerRadius: Tokens.Radius.alert)
        .lightAppearance()
    }

    private var quitButton: some View {
        Button(action: onQuit) {
            Text(strings[purpose.confirmKey])
                .textStyle(Tokens.Typography.alertButton)
                .foregroundStyle(Tokens.QuitAlert.quitText.color)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.QuitAlert.buttonHeight)
                .background(RoundedBox(cornerRadius: Tokens.Radius.pill).fill(Tokens.Glass.red))
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityIdentifier(purpose.confirmID)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(strings[.quitCancel])
                .textStyle(Tokens.Typography.alertButton)
                .foregroundStyle(Tokens.QuitAlert.cancelText.color)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.QuitAlert.buttonHeight)
                .background(RoundedBox(cornerRadius: Tokens.Radius.pill).fill(Tokens.Glass.white))
                .insetOutline(Tokens.QuitAlert.cancelOutline, width: Tokens.Stroke.outline, cornerRadius: Tokens.Radius.pill)
                .boxShadow(Tokens.QuitAlert.cancelShadows, cornerRadius: Tokens.Radius.pill)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityIdentifier(purpose.cancelID)
    }
}

/// 終了確認のパネルの中身。メニューバーより下の画面全体を暗くし、確認の箱を画面の中央よりやや上に置く。
///
/// 大きさは `PanelPlacement.dimmedArea(screen:)` の範囲。箱の置き場所は `PanelPlacement.alert(size:screen:)` で決める。
struct ConfirmationOverlay: View {
    let screen: ScreenInfo
    var purpose: ConfirmationPurpose = .quit
    let annotationCount: Int
    let strings: UIStrings
    let onQuit: () -> Void
    let onCancel: () -> Void
    /// 出ているか。nil なら出ている見た目で描く（見比べ用の画像）。
    var presentation: PanelPresentation?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ConfirmationLayout(screen: screen) {
            Rectangle()
                .fill(Tokens.QuitAlert.dim.color)
                .opacity(isPresented ? 1 : 0)
                .layoutValue(key: ConfirmationRole.self, value: .dim)
                .accessibilityHidden(true)
            ConfirmationView(
                annotationCount: annotationCount,
                purpose: purpose,
                strings: strings,
                onQuit: onQuit,
                onCancel: onCancel
            )
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented || reduceMotion ? 1 : Tokens.Motion.panelEntranceScale)
            .layoutValue(key: ConfirmationRole.self, value: .alert)
        }
        .lightAppearance()
    }

    private var isPresented: Bool {
        presentation?.isPresented ?? true
    }
}

/// 終了確認のパネルの中の役割。
enum ConfirmationRole: LayoutValueKey {
    case dim
    case alert

    static let defaultValue = ConfirmationRole.dim
}

/// 暗転を範囲いっぱいに、箱を `PanelPlacement.alert` の位置に置く。画面全体の座標から、範囲の中の座標へは範囲の左上を引いて直す。
struct ConfirmationLayout: Layout {
    let screen: ScreenInfo

    private var area: ScreenRect {
        PanelPlacement.dimmedArea(screen: screen)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: area.width, height: area.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let area = area
        for subview in subviews {
            let rect: ScreenRect
            switch subview[ConfirmationRole.self] {
            case .dim:
                rect = area
            case .alert:
                rect = PanelPlacement.alert(size: subview.sizeThatFits(.unspecified), screen: screen)
            }
            subview.place(
                at: CGPoint(x: bounds.minX + rect.x - area.x, y: bounds.minY + rect.y - area.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }
}

/// 終了確認の箱。共通の確認部品を終了用途で使う。
public typealias QuitConfirmView = ConfirmationView

/// 既存の終了確認の画像・配置テスト向けの共通部品の別名。
typealias QuitConfirmOverlay = ConfirmationOverlay
