import AppKit
import SwiftUI

/// akapen のボタンの共通の振る舞い（`DECISIONS.md` 19）。
///
/// - ホバー中は地をわずかに濃くする（`Tokens.Motion.hover` の ease-out で変える）。カーソルは指の形にする（アクティブでないときも）。
/// - 押している最中は不透明度を下げ、わずかに縮める。
/// - 使えない状態は不透明度を下げ、カーソルは矢印のまま。
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .overlay {
                RoundedBox(cornerRadius: cornerRadius)
                    .fill(Tokens.Motion.hoverOverlay.color)
                    .opacity(isHovering && isEnabled ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .contentShape(RoundedBox(cornerRadius: cornerRadius))
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(y: isHovering && isEnabled && !reduceMotion ? -Tokens.Motion.hoverLift : 0)
            .shadow(color: Tokens.Glass.shadow.color, radius: isHovering && !reduceMotion ? Tokens.Glass.hoverShadow : 0)
            .animation(Tokens.Motion.hoverAnimation, value: isHovering)
            .animation(reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.pressSpring, value: configuration.isPressed)
            .hoverCursor(.pointingHand, isEnabled: isEnabled)
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

    private var scale: CGFloat {
        guard isEnabled, configuration.isPressed, !reduceMotion else {
            return 1
        }
        return Tokens.Motion.pressedScale
    }
}
