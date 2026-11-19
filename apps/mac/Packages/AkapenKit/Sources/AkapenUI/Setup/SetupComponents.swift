import SwiftUI
import AkapenAXID

/// 黒い丸ボタン＋赤い丸のアイコン（`Continue`・`Open System Settings`・`Done`。`components.md` の主ボタン）。
struct SetupPrimaryButton: View {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let glyph: IconGlyph
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Setup.buttonInnerGap) {
                Text(title)
                    .textStyle(Tokens.Typography.setupButton)
                    .foregroundStyle(Tokens.Setup.buttonText.color)
                    .lineLimit(1)
                IconView(
                    glyph: glyph,
                    size: Tokens.Setup.buttonIconSize,
                    color: Tokens.Setup.buttonIcon,
                    lineWidth: Tokens.Stroke.arrowIcon
                )
                .frame(width: Tokens.Setup.buttonCircleSize, height: Tokens.Setup.buttonCircleSize)
                .background(Circle().fill(Tokens.Glass.red))
                .offset(x: hovering && !reduceMotion ? Tokens.Motion.arrowShift : 0)
                .animation(reduceMotion ? Tokens.Motion.reducedFadeAnimation : Tokens.Motion.hoverAnimation, value: hovering)
            }
            .padding(.leading, Tokens.Setup.buttonPaddingLeading)
            .padding(.trailing, Tokens.Setup.buttonPaddingTrailing)
            .frame(height: Tokens.Setup.buttonHeight)
            .background(Capsule().fill(Tokens.Glass.ink))
            .insetOutline(Tokens.Palette.cleanBackground, width: Tokens.Glass.dotRingWidth, cornerRadius: Tokens.Radius.pill)
            .boxShadow(Tokens.Setup.buttonShadows, cornerRadius: Tokens.Radius.pill)
            .onHover { hovering = $0 }
            .fixedSize()
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityIdentifier(identifier)
    }
}

/// 輪郭だけの丸ボタン（`Back`）。
struct SetupSecondaryButton: View {
    let title: String
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(Tokens.Typography.setupButton)
                .foregroundStyle(Tokens.Setup.secondaryButtonText.color)
                .lineLimit(1)
                .padding(.horizontal, Tokens.Setup.buttonPaddingLeading)
                .frame(height: Tokens.Setup.buttonHeight)
                .background(Capsule().fill(Tokens.Glass.white))
                .boxShadow(Tokens.Shadows.segmentSelected, cornerRadius: Tokens.Radius.pill)
                .insetOutline(Tokens.Setup.secondaryButtonOutline, width: Tokens.Stroke.hairline, cornerRadius: Tokens.Radius.pill)
                .fixedSize()
        }
        .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.pill))
        .accessibilityIdentifier(identifier)
    }
}

/// ページの位置を示す点（いまのページは横長の黒、ほかは小さな灰色）。
struct SetupPageDots: View {
    let current: Int
    let count: Int

    var body: some View {
        HStack(spacing: Tokens.Setup.pageDotGap) {
            ForEach(1...count, id: \.self) { index in
                RoundedBox(cornerRadius: Tokens.Radius.dot)
                    .fill(index == current ? Tokens.Setup.pageDotCurrent.color : Tokens.Setup.pageDot.color)
                    .frame(
                        width: index == current ? Tokens.Setup.pageDotCurrentWidth : Tokens.Setup.pageDotSize,
                        height: Tokens.Setup.pageDotSize
                    )
            }
        }
        .animation(Tokens.Motion.panelSpring, value: current)
        .accessibilityHidden(true)
    }
}

/// セットアップの見出しまわり（`STEP 1 OF 2`、見出し、説明文）。
struct SetupHeading: View {
    let step: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Tokens.Setup.headingGap) {
            Text(step)
                .textStyle(Tokens.Typography.metaLabel)
                .foregroundStyle(Tokens.Setup.step.color)
            Text(title)
                .textStyle(Tokens.Typography.setupTitle)
                .foregroundStyle(Tokens.Setup.title.color)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .textStyle(Tokens.Typography.setupBody)
                .foregroundStyle(Tokens.Setup.body.color)
                .multilineTextAlignment(.center)
                .frame(width: Tokens.Setup.bodyWidth)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// キーキャップ 1 つ（白い地、下端の内側に 2pt の濃い帯、外側に 1pt の輪郭。幅は 56 から文字なりに伸びる）。
struct SetupKeycap: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(Tokens.Typography.setupKey)
            .foregroundStyle(Tokens.Setup.keyText.color)
            .lineLimit(1)
            .padding(.horizontal, Tokens.Setup.keyPaddingX)
            .frame(minWidth: Tokens.Setup.keyWidth)
            .background {
                RoundedBox(cornerRadius: Tokens.Radius.box)
                    .fill(Tokens.Setup.keyEdge.color)
                    .overlay {
                        RoundedBox(cornerRadius: Tokens.Radius.box)
                            .fill(Tokens.Setup.keyBackground.color)
                            .offset(y: -Tokens.Setup.keyEdgeHeight)
                    }
                    .clipShape(RoundedBox(cornerRadius: Tokens.Radius.box))
            }
            .boxShadow(Tokens.Shadows.setupKeyOutline, cornerRadius: Tokens.Radius.box)
            .fixedSize()
    }
}

/// セットアップのキーの記録欄（キーを 1 つずつキーキャップで出す箱。App 07）。設定と同じ `KeyRecorderModel` を使う。
///
/// キーの部分をクリックすると記録を待ち始める。記録を待っている間はキーの代わりに `Type shortcut…` を出し、箱の輪郭を赤くする。
/// 記録できなかったときは、案内の代わりに知らせを出す（`DECISIONS.md` A8）。
struct SetupKeyRecorder: View {
    let recorder: KeyRecorderModel
    let shortcutText: ShortcutText
    let strings: UIStrings

    var body: some View {
        VStack(spacing: Tokens.Setup.recorderGap) {
            Button {
                recorder.toggleRecording()
            } label: {
                keys
            }
            .buttonStyle(ControlButtonStyle(cornerRadius: Tokens.Radius.box))
            .background(KeyCaptureField(recorder: recorder, isRecording: recorder.isRecording))
            .accessibilityLabel(strings[.setupHotkeyTitle])
            .accessibilityValue(value)
            .accessibilityIdentifier(AXID.Setup.hotkey)
            if let problem = recorder.problem {
                Text(strings.recorderMessage(problem))
                    .textStyle(Tokens.Typography.setupHint)
                    .foregroundStyle(Tokens.Setup.recorderMessage.color)
                    .accessibilityIdentifier(AXID.Setup.hotkeyMessage)
            } else {
                Text(strings[.setupRecorderHint])
                    .textStyle(Tokens.Typography.setupHint)
                    .foregroundStyle(Tokens.Setup.hint.color)
            }
        }
        .padding(Tokens.Setup.recorderPadding)
        .frame(maxWidth: .infinity)
        .background(RoundedBox(cornerRadius: Tokens.Radius.media).fill(Tokens.Setup.recorderBackground.color))
        .insetOutline(
            recorder.isRecording ? Tokens.Setup.recorderRecordingOutline : Tokens.ExtraColor.transparent,
            width: Tokens.Stroke.emphasis,
            cornerRadius: Tokens.Radius.media
        )
    }

    @ViewBuilder private var keys: some View {
        if recorder.isRecording {
            Text(strings[.recorderRecording])
                .textStyle(Tokens.Typography.setupBody)
                .foregroundStyle(Tokens.Setup.hint.color)
                .frame(height: Tokens.Typography.setupKey.lineHeight)
        } else if let shortcut = recorder.shortcut {
            HStack(spacing: Tokens.Setup.keyGap) {
                ForEach(Array(shortcutText.parts(shortcut).enumerated()), id: \.offset) { _, part in
                    SetupKeycap(text: part)
                }
            }
        }
    }

    private var value: String {
        if recorder.isRecording {
            return strings[.recorderRecording]
        }
        return recorder.shortcut.map(shortcutText.string) ?? ""
    }
}

/// 重複の注意書き（赤い点と文言。文言は固定。`DECISIONS.md` 25）。
struct SetupConflictNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Setup.noteGap) {
            RoundedBox(cornerRadius: Tokens.Radius.dot)
                .fill(Tokens.Setup.noteDot.color)
                .frame(width: Tokens.Setup.noteDotSize, height: Tokens.Setup.noteDotSize)
                .padding(.top, Tokens.Setup.noteDotTop)
            Text(text)
                .textStyle(Tokens.Typography.setupNote)
                .foregroundStyle(Tokens.Setup.noteText.color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Tokens.Setup.notePaddingY)
        .padding(.horizontal, Tokens.Setup.notePaddingX)
        .background(RoundedBox(cornerRadius: Tokens.Radius.box).fill(Tokens.Glass.redTint.color))
        .insetOutline(Tokens.Setup.noteOutline, width: Tokens.Stroke.hairline, cornerRadius: Tokens.Radius.box)
    }
}

/// 許可の手順の 1 行（番号、手順の文、右端）。区切り線は行の下端の内側に引く（最後の行には引かない）。
struct SetupStepRow<Trailing: View>: View {
    let number: Int
    let text: String
    let showsDivider: Bool
    @ViewBuilder let trailing: Trailing

    init(number: Int, text: String, showsDivider: Bool, @ViewBuilder trailing: () -> Trailing) {
        self.number = number
        self.text = text
        self.showsDivider = showsDivider
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Tokens.Setup.stepRowGap) {
                Text(String(number))
                    .textStyle(Tokens.Typography.meta)
                    .foregroundStyle(Tokens.Setup.stepNumber.color)
                    .frame(width: Tokens.Setup.stepNumberWidth, alignment: .leading)
                Text(text)
                    .textStyle(Tokens.Typography.setupStep)
                    .foregroundStyle(Tokens.Setup.stepText.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.horizontal, Tokens.Setup.stepRowPaddingX)
            .frame(height: Tokens.Setup.stepRowHeight - (showsDivider ? Tokens.Stroke.hairline : 0))
            if showsDivider {
                Rectangle()
                    .fill(Tokens.Setup.stepRowDivider.color)
                    .frame(height: Tokens.Stroke.hairline)
            }
        }
    }
}

/// システム設定のスイッチの絵（オフ）。押しても何も起きない。
struct SetupSwitchPicture: View {
    var body: some View {
        Capsule()
            .fill(Tokens.Setup.switchOff.color)
            .frame(width: Tokens.Setup.switchWidth, height: Tokens.Setup.switchHeight)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(Tokens.Setup.switchKnob.color)
                    .frame(width: Tokens.Setup.switchKnobSize, height: Tokens.Setup.switchKnobSize)
                    .padding(.leading, Tokens.Setup.switchPadding)
            }
            .accessibilityHidden(true)
    }
}
