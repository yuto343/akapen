import SwiftUI
import AkapenCore
import AkapenAXID

/// 終了確認の箱（アイコン、`Quit akapen?`、件数入りの説明、赤い `Quit` と `Cancel`。App 09）。
public struct QuitConfirmView: View {
    private let annotationCount: Int
    private let strings: UIStrings
    private let onQuit: () -> Void
    private let onCancel: () -> Void

    /// 未コピーの注釈の件数、文言の言語、押されたときのコールバックを受け取る。
    public init(
        annotationCount: Int,
        strings: UIStrings,
        onQuit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.annotationCount = annotationCount
        self.strings = strings
        self.onQuit = onQuit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: Tokens.QuitAlert.gap) {
            AppIconView(size: Tokens.QuitAlert.iconSize)
            VStack(spacing: Tokens.QuitAlert.textGap) {
                Text(strings[.quitTitle])
                    .textStyle(Tokens.Typography.alertTitle)
                    .foregroundStyle(Tokens.QuitAlert.title.color)
                Text(strings.plural(.quitMessage, count: annotationCount))
                    .textStyle(Tokens.Typography.alertBody)
                    .foregroundStyle(Tokens.QuitAlert.body.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AXID.QuitConfirm.message)
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
        .background(RoundedBox(cornerRadius: Tokens.Radius.alert).fill(Tokens.QuitAlert.background.color))
        .boxShadow(Tokens.QuitAlert.shadows, cornerRadius: Tokens.Radius.alert)
        .lightAppearance()
    }

    private var quitButton: some View {
        Button(action: onQuit) {
            Text(strings[.quit])
                .textStyle(Tokens.Typography.alertButton)
                .foregroundStyle(Tokens.QuitAlert.quitText.color)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.QuitAlert.buttonHeight)
                .background(RoundedBox(cornerRadius: Tokens.Radius.keycap).fill(Tokens.QuitAlert.quitBackground.color))
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.keycap))
        .accessibilityIdentifier(AXID.QuitConfirm.confirm)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(strings[.quitCancel])
                .textStyle(Tokens.Typography.alertButton)
                .foregroundStyle(Tokens.QuitAlert.cancelText.color)
                .frame(maxWidth: .infinity)
                .frame(height: Tokens.QuitAlert.buttonHeight)
                .background(RoundedBox(cornerRadius: Tokens.Radius.keycap).fill(Tokens.QuitAlert.cancelBackground.color))
                .insetOutline(Tokens.QuitAlert.cancelOutline, width: Tokens.Stroke.outline, cornerRadius: Tokens.Radius.keycap)
                .boxShadow(Tokens.QuitAlert.cancelShadows, cornerRadius: Tokens.Radius.keycap)
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.keycap))
        .accessibilityIdentifier(AXID.QuitConfirm.cancel)
    }
}

/// 終了確認のパネルの中身。メニューバーより下の画面全体を暗くし、確認の箱を画面の中央よりやや上に置く。
///
/// 大きさは `PanelPlacement.dimmedArea(screen:)` の範囲。箱の置き場所は `PanelPlacement.alert(size:screen:)` で決める。
struct QuitConfirmOverlay: View {
    let screen: ScreenInfo
    let annotationCount: Int
    let strings: UIStrings
    let onQuit: () -> Void
    let onCancel: () -> Void
    /// 出ているか。nil なら出ている見た目で描く（見比べ用の画像）。
    var presentation: PanelPresentation?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        QuitConfirmLayout(screen: screen) {
            Rectangle()
                .fill(Tokens.QuitAlert.dim.color)
                .opacity(isPresented ? 1 : 0)
                .layoutValue(key: QuitConfirmRole.self, value: .dim)
                .accessibilityHidden(true)
            QuitConfirmView(
                annotationCount: annotationCount,
                strings: strings,
                onQuit: onQuit,
                onCancel: onCancel
            )
            .opacity(isPresented ? 1 : 0)
            .scaleEffect(isPresented || reduceMotion ? 1 : Tokens.Motion.panelEntranceScale)
            .layoutValue(key: QuitConfirmRole.self, value: .alert)
        }
        .lightAppearance()
    }

    private var isPresented: Bool {
        presentation?.isPresented ?? true
    }
}

/// 終了確認のパネルの中の役割。
enum QuitConfirmRole: LayoutValueKey {
    case dim
    case alert

    static let defaultValue = QuitConfirmRole.dim
}

/// 暗転を範囲いっぱいに、箱を `PanelPlacement.alert` の位置に置く。画面全体の座標から、範囲の中の座標へは範囲の左上を引いて直す。
struct QuitConfirmLayout: Layout {
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
            switch subview[QuitConfirmRole.self] {
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
