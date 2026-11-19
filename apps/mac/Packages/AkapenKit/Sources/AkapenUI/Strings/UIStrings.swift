import AkapenCore

/// 引数のない文言のキー。値は `EnglishStrings` と `JapaneseStrings` の表にある。
public enum StringKey: String, CaseIterable, Sendable {
    /// 「List」ボタン。
    case list
    /// 「Copy prompt」ボタン。
    case copyPrompt
    /// 「List」ボタンのショートカットのキー `L`（`⌘` と並べてチップで出す）。
    case listShortcutKey
    /// 「Copy prompt」ボタンのショートカットのキー `C`。
    case copyPromptShortcutKey
    /// キーのチップの `⌘`。
    case keyCommand
    /// キーのチップの `⇧`。
    case keyShift
    /// キーのチップの `↵`。
    case keyReturn
    /// キーのチップの `esc`。
    case keyEscape
    /// キーのチップに添える `Done`（コメントの確定）。
    case hintDone
    /// キーのチップに添える `New line`（改行）。
    case hintNewLine
    /// キーのチップに添える `Save`（一覧の編集の保存）。
    case hintSave
    /// キーのチップに添える `Cancel`（取りやめ）。
    case hintCancel
    /// 「List」ボタンのツールチップ。
    case listHelp
    /// 「Copy prompt」ボタンのツールチップ。
    case copyPromptHelp
    /// 終了確認の終了のボタン `Quit`。
    case quit
    /// 案内の表示の `Drag to frame`。
    case drawHint
    /// 案内の表示の `esc to cancel`。
    case drawCancel
    /// コメント入力のプレースホルダー。
    case commentPlaceholder
    /// 一覧の見出し。
    case listTitle
    /// 一覧が 0 件のときの表示。
    case listEmpty
    /// 一覧の鉛筆のボタンの読み上げ用の名前。
    case listEdit
    /// 一覧のゴミ箱のボタンの読み上げ用の名前。
    case listDelete
    /// コピー完了の表示の文言 `Prompt copied!`。
    case copiedTitle
    /// アプリの名前（メニューの見出しの 1 行目）。言語によらず `akapen`。
    case appName
    /// メニューの `Settings…`。
    case menuSettings
    /// メニューの `Quit akapen`。
    case menuQuit
    /// メニューの見出しの 2 行目（注釈が 0 件のとき。`DECISIONS.md` 20）。
    case menuNoAnnotations
    /// 終了確認の見出し `Quit akapen?`。
    case quitTitle
    /// 終了確認の `Cancel`。終了のボタンは `quit`。
    case quitCancel
    /// 設定のウィンドウのタイトル `akapen Settings`。
    case settingsTitle
    /// 設定の行 `Language`。
    case settingsLanguage
    /// 言語の選択肢 `English`。どの言語でもその言語の名前で出す。
    case languageEnglish
    /// 言語の選択肢 `日本語`。どの言語でもその言語の名前で出す。
    case languageJapanese
    /// 設定の行 `Hotkey`。
    case settingsHotkey
    /// 設定の行 `Confirm comment with`。
    case settingsConfirmKey
    /// 確定キーの選択肢 `↵ Enter`。
    case confirmKeyEnter
    /// 確定キーの選択肢 `⌘ ↵ Enter`。
    case confirmKeyCommandEnter
    /// 設定の見出し `Prompt header`。
    case settingsPromptHeader
    /// 定型文の見出しの右の補足（いま選んでいる言語の定型文を編集していること。`DECISIONS.md` 24）。
    case settingsPromptNote
    /// 定型文の入力欄の下の補足。
    case settingsPromptCaption
    /// 設定の行 `Keep images for`。
    case settingsRetention
    /// キーの記録欄の未割り当ての表示 `Record shortcut`。
    case recorderPlaceholder
    /// キーの記録欄で記録を待っている表示 `Type shortcut…`（`DECISIONS.md` 24）。
    case recorderRecording
    /// 記録したキーが登録できなかったときの知らせ（`DECISIONS.md` A8）。
    case recorderUnavailable
    /// 記録したキーが、もう 1 つの欄で使われているときの知らせ。
    case recorderInUse
    /// セットアップ 1 ページ目の見出し `Choose your hotkey`。
    case setupHotkeyTitle
    /// セットアップ 1 ページ目の説明文。
    case setupHotkeyBody
    /// セットアップのキーの記録欄の案内。
    case setupRecorderHint
    /// セットアップの重複の注意書き（文言は固定。`DECISIONS.md` 25）。
    case setupConflictNote
    /// セットアップの `Continue`。
    case setupContinue
    /// セットアップ 2 ページ目の見出し `Allow Screen Recording`。
    case setupPermissionTitle
    /// セットアップ 2 ページ目の説明文。
    case setupPermissionBody
    /// 許可の手順 1。
    case setupStepOpenSettings
    /// 許可の手順 2。
    case setupStepTurnOn
    /// 許可の手順 3。
    case setupStepComeBack
    /// 許可を待っている表示 `Waiting…`。
    case setupWaiting
    /// 許可が取れた表示 `Granted`（`DECISIONS.md` 25）。
    case setupGranted
    /// セットアップの `Back`。
    case setupBack
    /// セットアップの `Open System Settings`。
    case setupOpenSystemSettings
    /// セットアップを終えるボタン `Done`。
    case setupDone
    /// 画面を撮影できなかったときの案内。
    case noticeCaptureFailed
    /// 撮った画像を保存できなかったときの案内。
    case noticeImageSaveFailed
    /// プロンプトをクリップボードに入れられなかったときの案内。
    case noticePasteboardFailed
    /// 設定を保存できなかったときの案内。
    case noticeSettingsSaveFailed
    /// メインメニューの `Edit`（画面の上には出ない）。
    case menuEdit
    /// メインメニューの `Undo`。
    case menuUndo
    /// メインメニューの `Redo`。
    case menuRedo
    /// メインメニューの `Cut`。
    case menuCut
    /// メインメニューの `Copy`。
    case menuCopy
    /// メインメニューの `Paste`。
    case menuPaste
    /// メインメニューの `Select All`。
    case menuSelectAll
}

/// 件数で単数・複数を出し分ける文言のキー（`DECISIONS.md` 21）。日本語は出し分けない。
public enum PluralKey: String, CaseIterable, Sendable {
    /// 一覧の見出しの件数（`2 ITEMS`）。
    case listItems
    /// 一覧のフッター（`Images are kept for 7 days`）。数は設定の日数。
    case listRetention
    /// コピー完了の表示の読み上げの文言の後半（`2 annotations · paste it into your AI agent`）。画面には出さない。
    case copiedSummary
    /// メニューの見出しの 2 行目（`2 annotations waiting`）。0 件のときは `UIStrings.menuStatus(count:)` が `menuNoAnnotations` を返す。
    case menuWaiting
    /// 終了確認の説明文（`2 annotations haven’t been copied yet.` と `They will be discarded.` の 2 行。資料の絵の改行の位置）。
    case quitMessage
    /// 画像を残す日数の単位（`days`）。数は設定の日数。
    case retentionUnit
}

/// キーのチップと、それに添える文言の組（`↵` `Done`）。
public struct KeyHint: Equatable, Sendable {
    /// チップで並べるキー。
    public var keys: [String]
    /// 添える文言。
    public var label: String

    /// キーと文言から作る。
    public init(keys: [String], label: String) {
        self.keys = keys
        self.label = label
    }

    /// 読み上げと、テストで見比べるための 1 行の書き方（`⇧↵ New line`）。
    public var spoken: String {
        keys.joined() + " " + label
    }
}

/// 1 つの言語の文言の表。
protocol StringTable: Sendable {
    func text(_ key: StringKey) -> String

    func plural(_ key: PluralKey, count: Int) -> String

    func sizeLabel(width: Int, height: Int) -> String

    func annotationMeta(appName: String, time: String) -> String

    func setupStep(current: Int, total: Int) -> String
}

/// 表示の文言。言語はシステムの言語ではなく、アプリの設定（`Settings.language`）で選ぶ。
///
/// 文言そのものは `EnglishStrings.swift` と `JapaneseStrings.swift` の表に置く。
/// 文字列カタログを使わないのは、`swift test` と `xcodebuild` で結果を同じにするため（カタログは `swift test` ではコンパイルされない）。
public struct UIStrings: Sendable {
    public let language: Language

    /// 指定した言語の文言を引く。
    public init(language: Language) {
        self.language = language
    }

    private var table: any StringTable {
        switch language {
        case .en:
            EnglishStrings()
        case .ja:
            JapaneseStrings()
        }
    }

    /// 引数のない文言。
    public subscript(_ key: StringKey) -> String {
        table.text(key)
    }

    /// 件数で単数・複数を出し分ける文言。
    public func plural(_ key: PluralKey, count: Int) -> String {
        table.plural(key, count: count)
    }

    /// 大きさの表示（`332 × 88`）。
    public func sizeLabel(width: Int, height: Int) -> String {
        table.sizeLabel(width: width, height: height)
    }

    /// 一覧の行のメタ情報（`Sample App · 14:32`）。
    public func annotationMeta(appName: String, time: String) -> String {
        table.annotationMeta(appName: appName, time: time)
    }

    /// 「List」ボタンに添えるショートカットのキー（`⌘` `L`）。
    public var listShortcutKeys: [String] {
        [self[.keyCommand], self[.listShortcutKey]]
    }

    /// 「Copy prompt」ボタンに添えるショートカットのキー（`⌘` `C`）。
    public var copyPromptShortcutKeys: [String] {
        [self[.keyCommand], self[.copyPromptShortcutKey]]
    }

    /// 確定のキー。確定キーの設定で変わる（`Enter` なら `↵`、`⌘Enter` なら `⌘` `↵`）。
    private func confirmKeys(_ confirmKey: ConfirmKey) -> [String] {
        switch confirmKey {
        case .enter:
            [self[.keyReturn]]
        case .commandEnter:
            [self[.keyCommand], self[.keyReturn]]
        }
    }

    /// 改行のキー。確定キーの設定で変わる（`Enter` で確定なら `⇧` `↵`、`⌘Enter` で確定なら `↵`）。
    private func newLineKeys(_ confirmKey: ConfirmKey) -> [String] {
        switch confirmKey {
        case .enter:
            [self[.keyShift], self[.keyReturn]]
        case .commandEnter:
            [self[.keyReturn]]
        }
    }

    /// 取りやめの案内（`esc` `Cancel`）。
    public var cancelHint: KeyHint {
        KeyHint(keys: [self[.keyEscape]], label: self[.hintCancel])
    }

    /// コメント入力の下の左側の案内（`↵ Done`・`⇧↵ New line`）。確定キーの設定で変わる（`DECISIONS.md` 22）。
    public func commentHints(for confirmKey: ConfirmKey) -> [KeyHint] {
        [
            KeyHint(keys: confirmKeys(confirmKey), label: self[.hintDone]),
            KeyHint(keys: newLineKeys(confirmKey), label: self[.hintNewLine]),
        ]
    }

    /// 一覧の編集中の行の下の案内（`↵ Save`・`esc Cancel`）。確定キーの設定で変わる。
    public func listEditHints(for confirmKey: ConfirmKey) -> [KeyHint] {
        [
            KeyHint(keys: confirmKeys(confirmKey), label: self[.hintSave]),
            cancelHint,
        ]
    }

    /// 直前の操作の失敗を知らせる文言（案内の表示に出す）。
    public func failureMessage(_ failure: SessionFailure) -> String {
        switch failure {
        case .captureFailed:
            self[.noticeCaptureFailed]
        case .imageSaveFailed:
            self[.noticeImageSaveFailed]
        case .pasteboardFailed:
            self[.noticePasteboardFailed]
        case .settingsSaveFailed:
            self[.noticeSettingsSaveFailed]
        }
    }

    /// メニューの見出しの 2 行目。0 件のときは `No annotations`（`DECISIONS.md` 20）。
    public func menuStatus(count: Int) -> String {
        count == 0 ? self[.menuNoAnnotations] : plural(.menuWaiting, count: count)
    }

    /// セットアップのページの位置（`STEP 1 OF 2`）。
    public func setupStep(current: Int, total: Int) -> String {
        table.setupStep(current: current, total: total)
    }

    /// キーを文字列で指定して引く。キーが表にないときは、キーをそのまま返す。
    public static func text(_ key: String, language: Language = .en) -> String {
        guard let known = StringKey(rawValue: key) else {
            return key
        }
        return UIStrings(language: language)[known]
    }
}
