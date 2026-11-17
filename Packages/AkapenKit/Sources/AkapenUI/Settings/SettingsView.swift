import SwiftUI
import AkapenCore
import AkapenAXID

/// 設定のウィンドウの中身（App 06）。タイトルバー、General の箱（言語・ホットキー・ボタン類の表示切り替え・確定キー）、
/// 定型文、画像を残す日数。
///
/// 表示に要る値と変更の受け口は `SettingsForm` が持つ。`SessionModel` には触らない。
struct SettingsView: View {
    let form: SettingsForm

    var body: some View {
        let strings = UIStrings(language: form.settings.language)
        VStack(spacing: 0) {
            SettingsTitleBar(title: strings[.settingsTitle])
            VStack(spacing: Tokens.Settings.sectionGap) {
                generalGroup(strings)
                promptSection(strings)
                retentionGroup(strings)
            }
            .padding(.top, Tokens.Settings.bodyPaddingTop)
            .padding(.horizontal, Tokens.Settings.bodyPaddingX)
            .padding(.bottom, Tokens.Settings.bodyPaddingBottom)
        }
        .frame(width: Tokens.Settings.width)
        .background(Tokens.Window.background.color)
        .lightAppearance()
    }

    // MARK: - General

    private func generalGroup(_ strings: UIStrings) -> some View {
        VStack(spacing: 0) {
            SettingsRow(showsDivider: true) {
                SettingsRowLabel(title: strings[.settingsLanguage])
            } trailing: {
                SegmentedChoice(
                    options: [
                        .init(value: Language.en, label: strings[.languageEnglish], identifier: AXID.Settings.languageEnglish),
                        .init(value: Language.ja, label: strings[.languageJapanese], identifier: AXID.Settings.languageJapanese),
                    ],
                    selection: form.settings.language,
                    label: strings[.settingsLanguage],
                    identifier: AXID.Settings.language
                ) { language in
                    form.setLanguage(language)
                }
            }
            SettingsRow(showsDivider: true, expanded: form.hotkey.problem != nil) {
                SettingsRowLabel(title: strings[.settingsHotkey])
            } trailing: {
                ShortcutChip(
                    recorder: form.hotkey,
                    shortcutText: form.shortcutText,
                    strings: strings,
                    label: strings[.settingsHotkey],
                    identifier: AXID.Settings.hotkey,
                    messageIdentifier: AXID.Settings.hotkeyMessage
                )
            }
            SettingsRow(showsDivider: true, expanded: form.toolbarShortcut.problem != nil) {
                SettingsRowLabel(
                    title: strings[.settingsToolbarShortcut],
                    caption: strings[.settingsToolbarShortcutCaption]
                )
            } trailing: {
                ShortcutChip(
                    recorder: form.toolbarShortcut,
                    shortcutText: form.shortcutText,
                    strings: strings,
                    label: strings[.settingsToolbarShortcut],
                    identifier: AXID.Settings.toolbarShortcut,
                    messageIdentifier: AXID.Settings.toolbarShortcutMessage
                )
            }
            SettingsRow(showsDivider: false) {
                SettingsRowLabel(title: strings[.settingsConfirmKey])
            } trailing: {
                SegmentedChoice(
                    options: [
                        .init(value: ConfirmKey.enter, label: strings[.confirmKeyEnter], identifier: AXID.Settings.confirmKeyEnter),
                        .init(
                            value: ConfirmKey.commandEnter,
                            label: strings[.confirmKeyCommandEnter],
                            identifier: AXID.Settings.confirmKeyCommandEnter
                        ),
                    ],
                    selection: form.settings.confirmKey,
                    label: strings[.settingsConfirmKey],
                    identifier: AXID.Settings.confirmKey
                ) { confirmKey in
                    form.setConfirmKey(confirmKey)
                }
            }
        }
        .background(RoundedBox(cornerRadius: Tokens.Radius.media).fill(Tokens.Settings.groupBackground.color))
    }

    // MARK: - 定型文

    private func promptSection(_ strings: UIStrings) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Settings.headerGap) {
            HStack(alignment: .firstTextBaseline) {
                Text(strings[.settingsPromptHeader])
                    .textStyle(Tokens.Typography.sectionTitle)
                    .foregroundStyle(Tokens.Settings.sectionTitle.color)
                Spacer(minLength: Tokens.Spacing.s2)
                Text(strings[.settingsPromptNote])
                    .textStyle(Tokens.Typography.sectionNote)
                    .foregroundStyle(Tokens.Settings.sectionNote.color)
            }
            // 大きさの違う文字をベースラインで揃えると、行が 1pt 高くなる。資料（CSS）と同じく、行の高さは 1 行分にする。
            .frame(height: Tokens.Typography.sectionTitle.lineHeight)
            GrowingTextField(controller: form.boilerplate)
                .frame(width: SettingsForm.boilerplateTextWidth, height: form.boilerplate.height)
                .padding(.vertical, Tokens.Settings.boilerplatePaddingY)
                .padding(.horizontal, Tokens.Settings.boilerplatePaddingX)
                .insetOutline(Tokens.Settings.boilerplateOutline, width: Tokens.Stroke.hairline, cornerRadius: Tokens.Radius.box)
            Text(strings[.settingsPromptCaption])
                .textStyle(Tokens.Typography.caption)
                .foregroundStyle(Tokens.Settings.caption.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 画像を残す日数

    private func retentionGroup(_ strings: UIStrings) -> some View {
        SettingsRow(showsDivider: false) {
            SettingsRowLabel(title: strings[.settingsRetention])
        } trailing: {
            HStack(spacing: Tokens.Settings.retentionGap) {
                RetentionField(form: form)
                Text(strings.plural(.retentionUnit, count: form.settings.imageRetentionDays))
                    .textStyle(Tokens.Typography.rowLabel)
                    .foregroundStyle(Tokens.Settings.retentionUnit.color)
            }
        }
        .background(RoundedBox(cornerRadius: Tokens.Radius.media).fill(Tokens.Settings.groupBackground.color))
    }
}
