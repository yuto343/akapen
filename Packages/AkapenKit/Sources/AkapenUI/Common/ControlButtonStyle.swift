import SwiftUI

/// akapen のボタンの見た目の変化（`DECISIONS.md` 19）。
///
/// ホバーは地をわずかに濃くし、押している最中は不透明度 0.8、使えない状態は 0.4。地や形はラベルの側で描く。
struct ControlButtonStyle: ButtonStyle {
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        ControlButtonBody(configuration: configuration, cornerRadius: cornerRadius)
    }
}

private struct ControlButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let cornerRadius: CGFloat
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .overlay {
                if isHovering && isEnabled {
                    RoundedBox(cornerRadius: cornerRadius)
                        .fill(Tokens.Motion.hoverOverlay.color)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedBox(cornerRadius: cornerRadius))
            .opacity(opacity)
            .onHover { hovering in
                isHovering = hovering
            }
    }

    private var opacity: Double {
        if !isEnabled {
            return Tokens.Motion.disabledOpacity
        }
        return configuration.isPressed ? Tokens.Motion.pressedOpacity : 1
    }
}
