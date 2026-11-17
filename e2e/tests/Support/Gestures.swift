import XCTest
import AkapenAXID

// 操作のヘルパー。識別子だけでは書きにくい操作（ホットキー、枠のドラッグ、入力欄へのキー、メニューバーのアイコン、
// キーの記録欄、ウィンドウを閉じる）をまとめる。
//
// 状態が変わるのを待つのは `Verify.swift` の `waitForPhase(_:)` / `waitForState(_:_:)` で行う。ここでは待たない
// （ただし、操作する要素が出るまでは待つ）。

extension AkapenUITestCase {
    // MARK: - ホットキー

    /// グローバルなホットキーを押す（既定は `⌘;`）。SampleTarget にキーを送り、akapen は前面にしない。
    func pressHotkey(_ shortcut: Shortcut = .commandSemicolon) {
        sample.typeKey(shortcut.key, modifierFlags: shortcut.flags)
    }

    /// ホットキーで枠を描き始め、枠を描く状態になるまで待つ。
    func startDrawing(with shortcut: Shortcut = .commandSemicolon) {
        pressHotkey(shortcut)
        waitForPhase(.drawing)
        waitForElement(AXID.Draw.surface)
    }

    /// 枠を描き終えて、コメントの入力欄が出ているところまで進める（「コメントの入力欄が出ているところから始める」前提。
    /// 起動時の前提では作れないので、ホットキー（注釈があってボタン類が出ていれば「+」）と枠のドラッグで作る）。
    /// SampleTarget の要素を囲む枠を描き、描いた枠を返す。
    @discardableResult
    func startCommenting(around sampleIdentifier: String = AXID.Sample.button) -> CGRect {
        if appState().isToolbarVisible {
            tapAdd()
            waitForPhase(.drawing)
        } else {
            startDrawing()
        }
        let rect = drawFrame(around: sampleIdentifier)
        waitForPhase(.commenting)
        waitForElement(AXID.Comment.field)
        return rect
    }

    // MARK: - 枠

    /// SampleTarget の要素を、`outset` pt 外側に広げて囲む枠を描く。描いた枠（画面全体を通した、左上が原点の矩形）を返す。
    /// 枠を描く状態になっていること。撮影が終わるのは待たない。
    @discardableResult
    func drawFrame(around sampleIdentifier: String, outset: CGFloat = 12) -> CGRect {
        let target = sampleElement(sampleIdentifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "SampleTarget の要素がない: \(sampleIdentifier)")
        return drawFrame(target.frame.insetBy(dx: -outset, dy: -outset))
    }

    /// 画面全体を通した、左上が原点の矩形 `rect` の左上から右下へドラッグする。描いた枠を返す。
    ///
    /// ドラッグの宛先は akapen の枠を描く面にする（下のアプリを宛先にすると、XCTest がそのアプリを前面に出してしまう）。
    @discardableResult
    func drawFrame(_ rect: CGRect) -> CGRect {
        let surface = waitForElement(AXID.Draw.surface)
        let origin = surface.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let start = origin.withOffset(CGVector(dx: rect.minX - surface.frame.minX, dy: rect.minY - surface.frame.minY))
        let end = start.withOffset(CGVector(dx: rect.width, dy: rect.height))
        start.press(forDuration: 0.1, thenDragTo: end)
        return rect
    }

    /// SampleTarget の要素の中ほどで、ほとんど動かさずに（`distance` pt だけ）ドラッグして離す。
    @discardableResult
    func dragBarely(on sampleIdentifier: String, distance: CGFloat = 2) -> CGRect {
        let target = sampleElement(sampleIdentifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "SampleTarget の要素がない: \(sampleIdentifier)")
        let center = CGPoint(x: target.frame.midX, y: target.frame.midY)
        return drawFrame(CGRect(x: center.x, y: center.y, width: distance, height: distance))
    }

    // MARK: - コメント

    /// コメントの入力欄。
    var commentField: XCUIElement {
        element(AXID.Comment.field)
    }

    /// コメントの入力欄に文字を打つ（改行を含めない。改行は `newLineInComment(_:)`）。入力欄が出るまで待つ。
    func typeComment(_ text: String) {
        XCTAssertFalse(text.contains("\n"), "改行は newLineInComment(_:) で入れる")
        let field = waitForElement(AXID.Comment.field)
        field.typeText(text)
    }

    /// コメントの入力欄で改行する。確定キーの設定に合わせて、`Shift+Enter`（`Enter` で確定）か `Enter`（`⌘Enter` で確定）を押す。
    func newLineInComment(_ confirmKey: ConfirmKeySetting = .enter) {
        let field = waitForElement(AXID.Comment.field)
        switch confirmKey {
        case .enter:
            field.typeKey(.return, modifierFlags: .shift)
        case .commandEnter:
            field.typeKey(.return, modifierFlags: [])
        }
    }

    /// コメントを確定する。確定キーの設定に合わせて、`Enter` か `⌘Enter` を押す。
    func confirmComment(_ confirmKey: ConfirmKeySetting = .enter) {
        let field = waitForElement(AXID.Comment.field)
        switch confirmKey {
        case .enter:
            field.typeKey(.return, modifierFlags: [])
        case .commandEnter:
            field.typeKey(.return, modifierFlags: .command)
        }
    }

    /// `Enter`（修飾キーなし）を押す。どの確定キーの設定でも、修飾キーなしの `Enter` を確かめたいときに使う。
    func pressReturnInComment(modifiers: XCUIElement.KeyModifierFlags = []) {
        let field = waitForElement(AXID.Comment.field)
        field.typeKey(.return, modifierFlags: modifiers)
    }

    /// コメントを行ごとに打ち、行の間で改行して、最後に確定する。
    func writeComment(_ lines: [String], confirmKey: ConfirmKeySetting = .enter) {
        for (index, line) in lines.enumerated() {
            if index > 0 {
                newLineInComment(confirmKey)
            }
            if !line.isEmpty {
                typeComment(line)
            }
        }
        confirmComment(confirmKey)
    }

    /// コメントの入力欄に入っている文。
    func commentText() -> String {
        (waitForElement(AXID.Comment.field).value as? String) ?? ""
    }

    /// `Esc` を押す（枠を描く面・コメントの入力欄・一覧など、いまキー入力を受け取っている akapen の部品に届く）。
    func pressEscape() {
        app.typeKey(.escape, modifierFlags: [])
    }

    /// 枠を描き（SampleTarget の要素を囲む）、コメントを書いて確定し、ボタン類だけの状態になるまで待つ。
    /// 枠を描く状態になっていること。
    @discardableResult
    func annotate(around sampleIdentifier: String, comment: String, confirmKey: ConfirmKeySetting = .enter) -> CGRect {
        let rect = drawFrame(around: sampleIdentifier)
        waitForPhase(.commenting)
        typeComment(comment)
        confirmComment(confirmKey)
        waitForPhase(.idle)
        return rect
    }

    // MARK: - ボタン類

    /// 「+」（次の枠を描き始める）を押す。
    func tapAdd() {
        waitForElement(AXID.Toolbar.add).click()
    }

    /// 「一覧」を押す（開いていれば閉じる）。
    func tapList() {
        waitForElement(AXID.Toolbar.list).click()
    }

    /// 「copy prompt」を押す。
    func tapCopyPrompt() {
        waitForElement(AXID.Toolbar.copyPrompt).click()
    }

    // MARK: - 一覧

    /// ボタン類の「一覧」で一覧を開き、一覧を開いている状態になるまで待つ（起動時から開いておくなら `launch(open: .list)`）。
    func openList() {
        tapList()
        waitForPhase(.listOpen)
        waitForElement(AXID.List.panel)
    }

    /// 一覧の `index` 番目（表示順、0 始まり）の行に出ているコメント。
    func listComment(_ index: Int) -> String {
        let text = waitForElement(AXID.List.comment(index))
        return (text.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? text.label
    }

    /// 一覧に出ている行の数。
    func listRowCount() -> Int {
        var count = 0
        while element(AXID.List.row(count)).exists {
            count += 1
        }
        return count
    }

    /// 一覧の `index` 番目の行のサムネイルが指す画像のパス（サムネイルが出ていなければ空）。
    func listThumbnailPath(_ index: Int) -> String {
        (waitForElement(AXID.List.thumbnail(index)).value as? String) ?? ""
    }

    /// 一覧の下の、画像を残す期間の案内に出ている日数。
    func listRetentionDays() -> Int? {
        let note = waitForElement(AXID.List.retention)
        return (note.value as? String).flatMap(Int.init)
    }

    /// 一覧の `index` 番目の注釈のコメントを、`text` に書き換えて確定する（改行を含めない）。
    func editAnnotation(_ index: Int, to text: String, confirmKey: ConfirmKeySetting = .enter) {
        waitForElement(AXID.List.edit(index)).click()
        let field = waitForElement(AXID.List.field(index))
        field.typeKey("a", modifierFlags: .command)
        if text.isEmpty {
            field.typeKey(.delete, modifierFlags: [])
        } else {
            field.typeText(text)
        }
        switch confirmKey {
        case .enter:
            field.typeKey(.return, modifierFlags: [])
        case .commandEnter:
            field.typeKey(.return, modifierFlags: .command)
        }
    }

    /// 一覧の `index` 番目の注釈を消す。
    func deleteAnnotation(_ index: Int) {
        waitForElement(AXID.List.delete(index)).click()
    }

    // MARK: - メニューバー

    /// メニューバーの akapen のアイコンを押して、メニューを開く。
    func openMenuBarMenu() {
        let icon = app.statusItems.matching(identifier: AXID.MenuBar.icon).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5), "メニューバーのアイコンがない")
        icon.click()
        waitForElement(AXID.MenuBar.settings)
    }

    /// メニューバーのメニューの見出しの 2 行目（件数）。
    func menuBarStatusText() -> String {
        let status = waitForElement(AXID.MenuBar.status)
        return (status.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? status.label
    }

    /// メニューバーのメニューから設定を開き、設定のウィンドウが出るまで待つ。
    func openSettingsFromMenuBar() {
        openMenuBarMenu()
        element(AXID.MenuBar.settings).click()
        waitForElement(AXID.Settings.window)
    }

    /// メニューバーのメニューから終了を選ぶ（確認が出るかどうかはアプリが決める）。
    func chooseQuitFromMenuBar() {
        openMenuBarMenu()
        element(AXID.MenuBar.quit).click()
    }

    /// `⌘Q` を押す（akapen の設定かセットアップのウィンドウが前面にあるとき）。
    func pressCommandQ() {
        app.typeKey("q", modifierFlags: .command)
    }

    /// 終了の確認に答える。
    func answerQuitConfirm(quit: Bool) {
        waitForElement(quit ? AXID.QuitConfirm.confirm : AXID.QuitConfirm.cancel).click()
    }

    /// 終了の確認の説明文（件数入り）。
    func quitConfirmMessage() -> String {
        let message = waitForElement(AXID.QuitConfirm.message)
        return (message.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? message.label
    }

    // MARK: - キーの記録欄（設定とセットアップで共通）

    /// キーの記録欄（`AXID.Settings.hotkey`・`AXID.Settings.toolbarShortcut`・`AXID.Setup.hotkey`）を押して、
    /// `shortcut` を記録させる。記録を待っているあいだ、akapen はグローバルなホットキーの登録を外している。
    func recordShortcut(_ shortcut: Shortcut, in recorderIdentifier: String) {
        let recorder = waitForElement(recorderIdentifier)
        recorder.click()
        waitForState("記録を待ち始める") { $0.hotkeys.suspended }
        app.typeKey(shortcut.key, modifierFlags: shortcut.flags)
        waitForState("記録を終える") { !$0.hotkeys.suspended }
    }

    /// キーの記録欄を押して `Delete` を押し、割り当てを外す（外せる欄だけ）。
    func clearShortcut(in recorderIdentifier: String) {
        let recorder = waitForElement(recorderIdentifier)
        recorder.click()
        waitForState("記録を待ち始める") { $0.hotkeys.suspended }
        app.typeKey(.delete, modifierFlags: [])
        waitForState("記録を終える") { !$0.hotkeys.suspended }
    }

    /// キーの記録欄に出ているキーの表示（読み上げ用の値。キーボードの配列に従った文字）。
    func recorderText(_ recorderIdentifier: String) -> String {
        (waitForElement(recorderIdentifier).value as? String) ?? ""
    }

    // MARK: - 設定

    /// 設定のウィンドウ。
    var settingsWindow: XCUIElement {
        element(AXID.Settings.window)
    }

    /// 設定のウィンドウを閉じるボタンで閉じ、閉じたことがアプリの状態に入るまで待つ。
    func closeSettings() {
        let window = waitForElement(AXID.Settings.window)
        window.buttons[XCUIIdentifierCloseWindow].click()
        waitForState("設定のウィンドウが閉じる") { !$0.windows.settings }
    }

    /// 設定の言語を選ぶ。
    func chooseLanguage(_ language: AppLanguage) {
        switch language {
        case .en:
            waitForElement(AXID.Settings.languageEnglish).click()
        case .ja:
            waitForElement(AXID.Settings.languageJapanese).click()
        }
    }

    /// 設定の確定キーを選ぶ。
    func chooseConfirmKey(_ confirmKey: ConfirmKeySetting) {
        switch confirmKey {
        case .enter:
            waitForElement(AXID.Settings.confirmKeyEnter).click()
        case .commandEnter:
            waitForElement(AXID.Settings.confirmKeyCommandEnter).click()
        }
    }

    /// 設定の画像を残す日数の欄に `text` を入れて `Enter` で確定する（範囲の外の値も入れられる）。
    func enterRetentionDays(_ text: String) {
        let field = waitForElement(AXID.Settings.imageRetentionDays)
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
        field.typeKey(.return, modifierFlags: [])
    }

    /// 設定の定型文の入力欄（いま選んでいる言語の定型文）を、`text` に書き換える。`text` の改行はそのまま改行になる。
    func replaceBoilerplate(with text: String) {
        let field = waitForElement(AXID.Settings.boilerplate)
        field.click()
        field.typeKey("a", modifierFlags: .command)
        if text.isEmpty {
            field.typeKey(.delete, modifierFlags: [])
        } else {
            field.typeText(text)
        }
    }

    // MARK: - セットアップ

    /// セットアップのウィンドウ。
    var setupWindow: XCUIElement {
        element(AXID.Setup.window)
    }

    /// セットアップの 1 ページ目から 2 ページ目へ進む。
    func continueSetup() {
        waitForElement(AXID.Setup.next).click()
        waitForState("セットアップの 2 ページ目に進む") { $0.windows.setupPage == .permission }
    }

    /// セットアップを終える（許可が取れていて、終える手段が出ていること）。
    func finishSetup() {
        waitForElement(AXID.Setup.done).click()
        waitForState("セットアップを終える") { $0.settings.setupCompleted && !$0.windows.setup }
    }

    /// セットアップのウィンドウを閉じるボタンで閉じ（終えずに閉じる）、閉じたことがアプリの状態に入るまで待つ。
    func closeSetup() {
        let window = waitForElement(AXID.Setup.window)
        window.buttons[XCUIIdentifierCloseWindow].click()
        waitForState("セットアップのウィンドウが閉じる") { !$0.windows.setup }
    }

    // MARK: - SampleTarget

    /// SampleTarget の Submit を押す。
    func clickSampleSubmit() {
        let button = sampleElement(AXID.Sample.button)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "SampleTarget の Submit がない")
        button.click()
    }

    /// SampleTarget の Submit を押した回数の表示。
    func sampleSubmitCount() -> Int? {
        let count = sampleElement(AXID.Sample.count)
        XCTAssertTrue(count.waitForExistence(timeout: 5), "SampleTarget の回数の表示がない")
        return (count.value as? String).flatMap(Int.init)
    }

    /// SampleTarget の入力欄（`AXID.Sample.firstField` など）をクリックして、文字を打つ。
    func typeInSample(_ text: String, into sampleIdentifier: String) {
        let field = sampleElement(sampleIdentifier)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "SampleTarget の要素がない: \(sampleIdentifier)")
        field.click()
        field.typeText(text)
    }

    /// SampleTarget の入力欄に入っている文字。
    func sampleText(_ sampleIdentifier: String) -> String {
        (sampleElement(sampleIdentifier).value as? String) ?? ""
    }
}
