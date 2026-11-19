import AppKit
import SwiftUI
import AkapenAXID

/// 設定のウィンドウのタイトルバー（52pt。地 `#F6F6F8`、下に 1pt の線、タイトルは左右中央）。信号ボタンはシステムが上に描く。
struct SettingsTitleBar: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(Tokens.Typography.windowTitle)
            .foregroundStyle(Tokens.Settings.title.color)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Settings.titleBarHeight)
            .background(Tokens.Settings.titleBarBackground.color)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Tokens.Settings.titleBarDivider.color)
                    .frame(height: Tokens.Stroke.hairline)
            }
            .accessibilityAddTraits(.isHeader)
    }
}

/// グループの箱の 1 行（高さ 48、左右 16、名前と操作を両端に置く）。区切り線は行の下端の内側に引く（最後の行には引かない）。
///
/// `expanded` のときは、上下に余白を足して高さを中身なりに伸ばす（記録欄の下に知らせを出すとき）。
struct SettingsRow<Leading: View, Trailing: View>: View {
    let showsDivider: Bool
    let expanded: Bool
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        showsDivider: Bool,
        expanded: Bool = false,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.showsDivider = showsDivider
        self.expanded = expanded
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Spacing.s2) {
                leading
                Spacer(minLength: Tokens.Spacing.s2)
                trailing
            }
            .padding(.horizontal, Tokens.Settings.rowPaddingX)
            .padding(.vertical, expanded ? Tokens.Settings.rowMessagePaddingY : 0)
            .frame(minHeight: Tokens.Settings.rowHeight - (showsDivider ? Tokens.Stroke.hairline : 0))
            if showsDivider {
                Rectangle()
                    .fill(Tokens.Settings.rowDivider.color)
                    .frame(height: Tokens.Stroke.hairline)
            }
        }
    }
}

/// 行の名前（と、その下の補足）。
struct SettingsRowLabel: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .textStyle(Tokens.Typography.rowLabel)
                .foregroundStyle(Tokens.Settings.rowLabel.color)
            if let caption {
                Text(caption)
                    .textStyle(Tokens.Typography.rowCaption)
                    .foregroundStyle(Tokens.Settings.rowCaption.color)
            }
        }
    }
}

/// 2 つ以上の選択肢のセグメント（言語・確定キー）。選ばれている項目は白い地と影、ほかは地なし。項目の幅は文字なり。
struct SegmentedChoice<Value: Hashable>: View {
    /// 選択肢 1 つ。
    struct Option {
        let value: Value
        let label: String
        let identifier: String
    }

    let options: [Option]
    let selection: Value
    /// 読み上げ用の名前（行の名前）。
    let label: String
    let identifier: String
    let onSelect: (Value) -> Void
    @Namespace private var selectionSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.identifier) { option in
                item(option, selected: option.value == selection)
            }
        }
        .padding(Tokens.Settings.segmentPadding)
        .background(RoundedBox(cornerRadius: Tokens.Radius.pill).fill(Tokens.Settings.segmentBackground.color))
        .animation(reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.panelSpring, value: selection)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func item(_ option: Option, selected: Bool) -> some View {
        Button {
            onSelect(option.value)
        } label: {
            Text(option.label)
                .textStyle(selected ? Tokens.Typography.segmentSelected : Tokens.Typography.segment)
                .foregroundStyle(selected ? Tokens.Settings.segmentSelectedText.color : Tokens.Settings.segmentText.color)
                .padding(.horizontal, Tokens.Settings.segmentItemPaddingX)
                .background {
                    if selected {
                        if reduceMotion {
                            Capsule().fill(Tokens.Settings.segmentSelectedBackground.color)
                        } else {
                            Capsule().fill(Tokens.Settings.segmentSelectedBackground.color)
                                .matchedGeometryEffect(id: "selection", in: selectionSpace)
                                .boxShadow(Tokens.Settings.segmentSelectedShadows, cornerRadius: Tokens.Radius.pill)
                        }
                    }
                }
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityIdentifier(option.identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 設定のキーの記録欄（`⌘ ;` の箱。App 06）。クリックで記録を待ち、記録できなかったときは箱の下に知らせを出す。
struct ShortcutChip: View {
    let recorder: KeyRecorderModel
    let shortcutText: ShortcutText
    let strings: UIStrings
    /// 読み上げ用の名前（行の名前）。
    let label: String
    let identifier: String
    let messageIdentifier: String

    var body: some View {
        VStack(alignment: .trailing, spacing: Tokens.Settings.recorderMessageGap) {
            Button {
                recorder.toggleRecording()
            } label: {
                chip
            }
            .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.keycap))
            .background(KeyCaptureField(recorder: recorder, isRecording: recorder.isRecording))
            .accessibilityLabel(label)
            .accessibilityValue(display)
            .accessibilityIdentifier(identifier)
            if let problem = recorder.problem {
                Text(strings.recorderMessage(problem))
                    .textStyle(Tokens.Typography.rowCaption)
                    .foregroundStyle(Tokens.Settings.recorderMessage.color)
                    .accessibilityIdentifier(messageIdentifier)
            }
        }
    }

    private var chip: some View {
        Text(display)
            .textStyle(showsShortcut ? Tokens.Typography.recorderKey : Tokens.Typography.recorderPlaceholder)
            .foregroundStyle(showsShortcut ? Tokens.Settings.recorderText.color : Tokens.Settings.recorderPlaceholder.color)
            .lineLimit(1)
            .padding(.horizontal, Tokens.Settings.recorderPaddingX)
            .background(RoundedBox(cornerRadius: Tokens.Radius.keycap).fill(Tokens.Settings.recorderBackground.color))
            .boxShadow(Tokens.Shadows.segmentSelected, cornerRadius: Tokens.Radius.keycap)
            .insetOutline(
                recorder.isRecording ? Tokens.Settings.recorderRecordingOutline : Tokens.Settings.recorderOutline,
                width: recorder.isRecording ? Tokens.Stroke.emphasis : Tokens.Stroke.hairline,
                cornerRadius: Tokens.Radius.keycap
            )
            .fixedSize()
    }

    /// 割り当て済みのキーを出しているか（記録を待っている間と未割り当てのときは false）。
    private var showsShortcut: Bool {
        !recorder.isRecording && recorder.shortcut != nil
    }

    private var display: String {
        if recorder.isRecording {
            return strings[.recorderRecording]
        }
        guard let shortcut = recorder.shortcut else {
            return strings[.recorderPlaceholder]
        }
        return shortcutText.string(shortcut)
    }
}

/// 画像を残す日数の入力欄（`7` の箱）。幅は数字なり。確定（`Return` かフォーカスが外れたとき）で 1〜365 に丸める。
struct RetentionField: View {
    let form: SettingsForm
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            "",
            text: Binding(
                get: {
                    form.retentionText
                },
                set: { text in
                    form.setRetentionText(text)
                }
            )
        )
        .textFieldStyle(.plain)
        .font(Tokens.Typography.retentionValue.font)
        .foregroundStyle(Tokens.Settings.retentionText.color)
        .multilineTextAlignment(.center)
        .focused($isFocused)
        .onSubmit {
            form.commitRetention()
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                form.commitRetention()
            }
        }
        .frame(width: textWidth)
        .padding(.horizontal, Tokens.Settings.recorderPaddingX)
        .frame(height: Tokens.Typography.retentionValue.lineHeight)
        .background(RoundedBox(cornerRadius: Tokens.Radius.keycap).fill(Tokens.Settings.recorderBackground.color))
            .boxShadow(Tokens.Shadows.segmentSelected, cornerRadius: Tokens.Radius.keycap)
        .insetOutline(Tokens.Settings.recorderOutline, width: Tokens.Stroke.hairline, cornerRadius: Tokens.Radius.keycap)
        .accessibilityIdentifier(AXID.Settings.imageRetentionDays)
    }

    /// 入っている数字の幅（空のときは 1 桁分）。入力欄の中の余白の分を足す。
    private var textWidth: CGFloat {
        let text = form.retentionText.isEmpty ? "0" : form.retentionText
        let font = Tokens.Typography.retentionValue.nsFont
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return ceil(width) + Tokens.Settings.retentionFieldSlack
    }
}
