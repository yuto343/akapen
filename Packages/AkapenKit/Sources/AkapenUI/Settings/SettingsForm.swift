import AppKit
import Observation
import AkapenCore
import AkapenAXID

/// 設定の画面の状態と、変更の組み立て。`SessionModel` を知らず、変えた設定を `onChange` で外に渡すだけにする。
///
/// 変更は、その場で `onChange` に新しい設定全体を渡す（保存ボタンはない）。
/// 新しい設定は、`base`（ふつうは `SessionModel.settings`）のいまの値に、変えた項目だけを当てて作る。
/// ほかの画面（セットアップ）が同時に変えた項目を、古い値で上書きしないため。
@MainActor @Observable final class SettingsForm {
    /// 画像を残す日数の範囲（`DECISIONS.md` 24・A10）。範囲の外は丸める。
    static let retentionRange = 1...365

    /// 画面に出している設定。
    private(set) var settings: Settings
    /// 日数の入力欄の文字。確定（`Return` かフォーカスが外れたとき）で丸めて設定に入れる。
    private(set) var retentionText: String
    /// ホットキーの記録欄（未割り当てを許さない）。
    let hotkey: KeyRecorderModel
    /// ボタン類の表示切り替えの記録欄（未割り当てを許す）。
    let toolbarShortcut: KeyRecorderModel
    /// 定型文の入力欄。いま選んでいる言語の定型文を編集する。
    @ObservationIgnored let boilerplate: GrowingTextController
    /// キーの表示。
    @ObservationIgnored let shortcutText: ShortcutText
    /// 変更のもとにする、いまの設定。nil なら画面に出している設定をもとにする。
    @ObservationIgnored var base: (@MainActor () -> Settings)?
    /// 設定を変えたとき。新しい設定全体を渡す。
    @ObservationIgnored var onChange: (@MainActor (Settings) -> Void)?
    /// キーの記録を待ち始めた（true）・やめた（false）とき。2 つの欄のどちらかが待っている間は true。
    @ObservationIgnored var onRecordingChange: (@MainActor (Bool) -> Void)?
    @ObservationIgnored private var notifiedRecording = false

    /// 定型文の入力欄の、文字が並ぶ幅（中身の幅から左右の余白を引いたもの）。
    static let boilerplateTextWidth = Tokens.Settings.width
        - Tokens.Settings.bodyPaddingX * 2
        - Tokens.Settings.boilerplatePaddingX * 2

    init(settings: Settings, shortcutText: ShortcutText = ShortcutText()) {
        self.settings = settings
        self.shortcutText = shortcutText
        retentionText = String(settings.imageRetentionDays)
        hotkey = KeyRecorderModel(shortcut: settings.hotkey, allowsNone: false)
        toolbarShortcut = KeyRecorderModel(shortcut: settings.toolbarShortcut, allowsNone: true)
        boilerplate = GrowingTextController(
            style: Tokens.Typography.boilerplate,
            maxLines: Tokens.Settings.boilerplateMaxLines,
            width: Self.boilerplateTextWidth,
            textColor: Tokens.Settings.boilerplateText,
            caretColor: Tokens.Settings.boilerplateCaret,
            placeholderColor: Tokens.Settings.caption
        )
        configureBoilerplate()
        configureRecorders()
    }

    /// 外から設定を入れ直す（ウィンドウを開いたとき）。記録の途中ならやめ、知らせも消す。
    func load(_ settings: Settings) {
        self.settings = settings
        retentionText = String(settings.imageRetentionDays)
        hotkey.load(settings.hotkey)
        toolbarShortcut.load(settings.toolbarShortcut)
        let text = settings.boilerplate(for: settings.language)
        if boilerplate.text != text {
            boilerplate.setText(text)
        }
    }

    /// ほかの所で変わった設定を映す。前に映していた値から変わった項目だけを入れ直す。
    ///
    /// 記録を待っている記録欄はそのままにする（記録の途中の操作を壊さない）。
    func sync(_ latest: Settings) {
        let previous = settings
        guard latest != previous else {
            return
        }
        settings = latest
        if latest.imageRetentionDays != previous.imageRetentionDays {
            retentionText = String(latest.imageRetentionDays)
        }
        if latest.hotkey != previous.hotkey, !hotkey.isRecording {
            hotkey.load(latest.hotkey)
        }
        if latest.toolbarShortcut != previous.toolbarShortcut, !toolbarShortcut.isRecording {
            toolbarShortcut.load(latest.toolbarShortcut)
        }
        let text = latest.boilerplate(for: latest.language)
        if text != previous.boilerplate(for: previous.language), boilerplate.text != text {
            boilerplate.setText(text)
        }
    }

    /// 言語を切り替える。画面の文言と、定型文の入力欄の中身（その言語の定型文）がすぐに切り替わる。
    func setLanguage(_ language: Language) {
        guard language != settings.language else {
            return
        }
        apply { settings in
            settings.language = language
        }
        boilerplate.setText(settings.boilerplate(for: language))
    }

    /// 確定キーを切り替える。
    func setConfirmKey(_ confirmKey: ConfirmKey) {
        guard confirmKey != settings.confirmKey else {
            return
        }
        apply { settings in
            settings.confirmKey = confirmKey
        }
    }

    /// 定型文の入力欄が書き換えられたとき。いま選んでいる言語の定型文だけを書き換える。
    func boilerplateEdited(_ text: String) {
        let language = settings.language
        guard text != settings.boilerplate(for: language) else {
            return
        }
        apply { settings in
            settings.setBoilerplate(text, for: language)
        }
    }

    /// 日数の入力欄の文字を入れる。数字以外は捨てる。
    func setRetentionText(_ text: String) {
        retentionText = text.filter(\.isASCIIDigitCharacter)
    }

    /// 日数の入力を確定する。1〜365 に丸めて設定に入れ、入力欄の文字も丸めた値にする。空なら元の値に戻す。
    func commitRetention() {
        let days: Int
        if retentionText.isEmpty {
            days = settings.imageRetentionDays
        } else {
            days = Self.clampRetention(Int(retentionText) ?? Self.retentionRange.upperBound)
        }
        retentionText = String(days)
        guard days != settings.imageRetentionDays else {
            return
        }
        apply { settings in
            settings.imageRetentionDays = days
        }
    }

    /// 日数を 1〜365 に丸める。
    static func clampRetention(_ days: Int) -> Int {
        min(max(days, retentionRange.lowerBound), retentionRange.upperBound)
    }

    /// 入力の途中のものを片付ける（ウィンドウを閉じるとき）。日数の入力を確定し、キーの記録をやめる。
    func finishEditing() {
        commitRetention()
        cancelRecording()
    }

    /// キーの記録をやめる（ウィンドウがキーでなくなったとき）。
    func cancelRecording() {
        hotkey.cancelRecording()
        toolbarShortcut.cancelRecording()
    }

    // MARK: - 下請け

    private func apply(_ change: (inout Settings) -> Void) {
        var next = base?() ?? settings
        change(&next)
        settings = next
        onChange?(next)
    }

    private func configureBoilerplate() {
        boilerplate.setText(settings.boilerplate(for: settings.language))
        // 定型文はふつうの複数行の入力欄。Return は改行にし（日本語の変換中は変換の確定に任せる）、Esc では何もしない。
        boilerplate.textView.router.decide = { _, isComposing, _ in
            isComposing ? .passThrough : .insertNewline
        }
        boilerplate.textView.setAccessibilityIdentifier(AXID.Settings.boilerplate)
        boilerplate.onEdit = { [weak self] text in
            self?.boilerplateEdited(text)
        }
    }

    private func configureRecorders() {
        hotkey.isTaken = { [weak self] candidate in
            self?.toolbarShortcut.shortcut == candidate
        }
        toolbarShortcut.isTaken = { [weak self] candidate in
            self?.hotkey.shortcut == candidate
        }
        hotkey.onCommit = { [weak self] value in
            guard let value else {
                return
            }
            self?.apply { settings in
                settings.hotkey = value
            }
        }
        toolbarShortcut.onCommit = { [weak self] value in
            self?.apply { settings in
                settings.toolbarShortcut = value
            }
        }
        for recorder in [hotkey, toolbarShortcut] {
            recorder.onRecordingChange = { [weak self, weak recorder] began in
                guard let self, let recorder else {
                    return
                }
                recordingChanged(recorder, began: began)
            }
        }
    }

    /// 片方が記録を待ち始めたら、もう片方はやめる。2 つ合わせた状態が変わったときだけ知らせる。
    private func recordingChanged(_ recorder: KeyRecorderModel, began: Bool) {
        if began {
            for other in [hotkey, toolbarShortcut] where other !== recorder {
                other.cancelRecording()
            }
        }
        let isRecording = hotkey.isRecording || toolbarShortcut.isRecording
        guard isRecording != notifiedRecording else {
            return
        }
        notifiedRecording = isRecording
        onRecordingChange?(isRecording)
    }
}

private extension Character {
    /// `0`〜`9`。全角の数字などは数えない。
    var isASCIIDigitCharacter: Bool {
        isASCII && isNumber
    }
}
