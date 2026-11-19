import SwiftUI

/// キーの表示（チップ）の地の種類。
enum KeyChipTone {
    /// 白い地の上（「List」、コメント入力・一覧の案内）。
    case light
    /// 入力ヒント用の白いキー型。
    case keycap
    /// 黒い地の上（「Copy prompt」）。
    case dark

    var background: ColorToken {
        switch self {
        case .keycap:
            Tokens.Palette.cleanBackground
        case .light:
            Tokens.KeyChip.background
        case .dark:
            Tokens.KeyChip.darkBackground
        }
    }

    var outline: ColorToken {
        switch self {
        case .keycap:
            Tokens.ExtraColor.transparent
        case .light:
            Tokens.KeyChip.outline
        case .dark:
            Tokens.KeyChip.darkOutline
        }
    }

    var text: ColorToken {
        switch self {
        case .keycap:
            Tokens.Palette.ink2
        case .light:
            Tokens.KeyChip.text
        case .dark:
            Tokens.KeyChip.darkText
        }
    }
}

/// キーを 1 つずつ小さなチップで並べる（`⌘` `L`）。読み上げはしない（ボタンの名前やツールチップに任せる）。
struct KeyChipsView: View {
    let keys: [String]
    var tone: KeyChipTone = .light

    var body: some View {
        HStack(spacing: Tokens.KeyChip.keyGap) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                chip(key)
            }
        }
        .fixedSize()
        .accessibilityHidden(true)
    }

    private func chip(_ key: String) -> some View {
        Text(key)
            .textStyle(Tokens.Typography.keyChip)
            .foregroundStyle(tone.text.color)
            .padding(.horizontal, key.count > 1 ? Tokens.KeyChip.wordPaddingX : Tokens.KeyChip.paddingX)
            .frame(minWidth: Tokens.KeyChip.minWidth)
            .frame(height: Tokens.KeyChip.height)
            .background(RoundedBox(cornerRadius: Tokens.Radius.keyChip).fill(tone.background.color))
            .boxShadow(tone == .keycap ? Tokens.Shadows.segmentSelected : [], cornerRadius: Tokens.Radius.keyChip)
            .insetOutline(tone.outline, width: Tokens.Stroke.outline, cornerRadius: Tokens.Radius.keyChip)
    }
}

/// キーのチップと、それに添える文言（`↵` `Done`）。
struct KeyHintView: View {
    let hint: KeyHint

    var body: some View {
        HStack(spacing: Tokens.KeyChip.labelGap) {
            KeyChipsView(keys: hint.keys, tone: .keycap)
            Text(hint.label)
                .textStyle(Tokens.Typography.keyHintLabel)
                .foregroundStyle(Tokens.KeyChip.label.color)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hint.spoken)
    }
}

/// キーの案内を横に並べる。
struct KeyHintRow: View {
    let hints: [KeyHint]
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                KeyHintView(hint: hint)
            }
        }
    }
}
