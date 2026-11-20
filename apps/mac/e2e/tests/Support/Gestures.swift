import AppKit
import ApplicationServices
import XCTest
import AkapenAXID

// 操作のヘルパー。識別子だけでは書きにくい操作（ホットキー、枠のドラッグ、入力欄へのキー、メニューバーのアイコン、
// キーの記録欄、ウィンドウを閉じる）をまとめる。
//
// 状態が変わるのを待つのは `Verify.swift` の `waitForPhase(_:)` / `waitForState(_:_:)` で行う。ここでは待たない
// （ただし、操作する要素が出るまでは待つ）。

extension AkapenUITestCase {
    // MARK: - ホットキー

    /// グローバルなホットキーを押す（既定は `⌘⇧6`）。押したあとの状態の変化は待たない（`waitForPhase(_:)` などで待つ）。
    ///
    /// XCTest の `typeKey` は、送り先のアプリがキーを受け取るまで待つ（受け取らなければ約 10 秒）。
    /// グローバルなホットキーとして登録されているキーは OS が横取りして akapen に届けるので、
    /// - akapen がそのキーをホットキーとして登録している（アプリの状態の `hotkeys`）ときは、akapen を送り先にする。
    ///   XCTest は送る前に akapen を前面にするが、ホットキーの働きは変わらない。
    /// - 登録していないときは、ふつうのキーとして前面のアプリに届くはずなので、SampleTarget を送り先にする。
    /// 登録しているはずなのに効かない（akapen にふつうのキーとして届く）場合は、状態が変わらないのでテストが落ちる。
    func pressHotkey(_ shortcut: Shortcut = .defaultHotkey) {
        let hotkeys = appState().hotkeys
        let isRegistered = !hotkeys.suspended && hotkeys.draw == shortcut
        if isRegistered {
            app.typeKey(shortcut.key, modifierFlags: shortcut.flags)
        } else {
            sample.typeKey(shortcut.key, modifierFlags: shortcut.flags)
        }
    }

    /// ホットキーで枠を描き始め、枠を描く状態になるまで待つ。
    func startDrawing(with shortcut: Shortcut = .defaultHotkey) {
        pressHotkey(shortcut)
        waitForPhase(.drawing)
        waitForElement(AXID.Draw.surface)
    }

    /// 枠を描き終えて、コメントの入力欄が出ているところまで進める（「コメントの入力欄が出ているところから始める」前提。
    /// 起動時の前提では作れないので、ホットキー（ボタン類が出ていれば押さない。一覧が開いていれば閉じる）と枠のドラッグで作る）。
    /// 入力欄は撮影の完了を待たずに出るが、前提を毎回同じにするため、書きかけの注釈の撮影と保存が終わるまで待つ。
    /// SampleTarget の要素を囲む枠を描き、描いた枠を返す。
    @discardableResult
    func startCommenting(around sampleIdentifier: String = AXID.Sample.button) -> CGRect {
        switch appState().phase {
        case .drawing:
            waitForElement(AXID.Draw.surface)
        case .listOpen:
            tapList()
            waitForPhase(.drawing)
        default:
            startDrawing()
        }
        let rect = drawFrame(around: sampleIdentifier)
        waitForPhase(.commenting)
        waitForElement(AXID.Comment.field)
        waitForCapturedDraft()
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

    /// 枠を描き（SampleTarget の要素を囲む）、コメントを書いて確定し、枠を描く状態に戻るまで待つ。
    /// 枠を描く状態になっていること。
    @discardableResult
    func annotate(around sampleIdentifier: String, comment: String, confirmKey: ConfirmKeySetting = .enter) -> CGRect {
        let rect = drawFrame(around: sampleIdentifier)
        waitForPhase(.commenting)
        typeComment(comment)
        confirmComment(confirmKey)
        waitForPhase(.drawing)
        return rect
    }

    // MARK: - ボタン類

    /// 「一覧」を押す（開いていれば閉じる）。
    func tapList() {
        waitForElement(AXID.Toolbar.list).click()
    }

    /// 「copy prompt」を押す。
    func tapCopyPrompt() {
        waitForElement(AXID.Toolbar.copyPrompt).click()
    }

    /// ボタン類が出ているあいだのショートカットを押す（akapen を送り先にする。押したあとの状態の変化は待たない）。
    func pressToolbarShortcut(_ shortcut: ToolbarShortcut) {
        app.typeKey(shortcut.rawValue, modifierFlags: .command)
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
    ///
    /// 座標でクリックすると、内蔵ディスプレイのノッチの裏にアイコンが隠れているとき（メニューバーの項目が多いとき）に押せない。
    /// そこで、テストの実行役（AkapenE2E-Runner）にアクセシビリティの許可があれば、「押す」操作（`AXPress`）をアイコンへ直接送る。
    /// 許可がない（既定）ときや押せなかったときは、これまでどおりクリックする。
    func openMenuBarMenu() {
        let icon = app.statusItems.matching(identifier: AXID.MenuBar.icon).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5), "メニューバーのアイコンがない")
        if !MenuBarIconPress.press(bundleIdentifier: Self.akapenBundleIdentifier, identifier: AXID.MenuBar.icon) {
            icon.click()
        }
        waitForElement(AXID.MenuBar.settings)
    }

    /// メニューバーのメニューの項目を押す（メニューが開いていること）。
    ///
    /// `AXPress` で開いたメニューは、XCUITest が項目へ座標でマウスを動かすと閉じてしまい、項目の座標が取れずに落ちる
    /// （`point.x != INFINITY`）。そこで、許可があれば項目にも `AXPress` を送る。許可がないときは、これまでどおりクリックする。
    func pressMenuBarItem(_ identifier: String) {
        let item = waitForElement(identifier)
        if !MenuBarIconPress.pressMenuItem(bundleIdentifier: Self.akapenBundleIdentifier, iconIdentifier: AXID.MenuBar.icon, identifier: identifier) {
            item.click()
        }
    }

    /// テストする akapen のバンドル ID。
    static var akapenBundleIdentifier: String {
        "com.yuto343.akapen"
    }

    /// メニューバーのメニューの見出しの 2 行目（件数）。
    func menuBarStatusText() -> String {
        let status = waitForElement(AXID.MenuBar.status)
        return (status.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? status.label
    }

    /// メニューバーのメニューから設定を開き、設定のウィンドウが出るまで待つ。
    func openSettingsFromMenuBar() {
        openMenuBarMenu()
        pressMenuBarItem(AXID.MenuBar.settings)
        waitForElement(AXID.Settings.window)
    }

    /// メニューバーのメニューから終了を選ぶ（確認が出るかどうかはアプリが決める）。
    func chooseQuitFromMenuBar() {
        openMenuBarMenu()
        pressMenuBarItem(AXID.MenuBar.quit)
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

    /// キーの記録欄（`AXID.Settings.hotkey`・`AXID.Setup.hotkey`）を押して、
    /// `shortcut` を記録させる。記録を待っているあいだ、akapen はグローバルなホットキーの登録を外している。
    func recordShortcut(_ shortcut: Shortcut, in recorderIdentifier: String) {
        let recorder = waitForElement(recorderIdentifier)
        recorder.click()
        waitForState("記録を待ち始める") { $0.hotkeys.suspended }
        app.typeKey(shortcut.key, modifierFlags: shortcut.flags)
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
    ///
    /// 打った文字が欄に入ったのを確かめてから `Enter` を押す。
    ///
    /// メニューバーから設定を開いた直後は、まれに（10 回に 1 回ほど）XCTest の `Enter` が akapen に届かない
    /// （`typeKey` が届くのを約 5 秒待ってあきらめる。入力ソースも前面のアプリも変わっていない。2 回目の `Enter` は届く）。
    /// 道具の側の取りこぼしなので、`typeKey` がその待ちに当たったとき（`undeliveredKeyThreshold` 秒以上かかったとき）に限って、
    /// `Enter` をもう 1 回送る。akapen が `Enter` を受け取ったうえで確定しない不具合は、送り直さないので隠れない。
    func enterRetentionDays(_ text: String) {
        let field = waitForElement(AXID.Settings.imageRetentionDays)
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
        // 欄は数字だけを受け取る（数字以外は捨てる）ので、数字だけにしたものと比べる。
        let digits = text.filter { ("0"..."9").contains($0) }
        _ = poll(timeout: 2) {
            (field.value as? String) == digits
        }
        let started = ProcessInfo.processInfo.systemUptime
        field.typeKey(.return, modifierFlags: [])
        if ProcessInfo.processInfo.systemUptime - started >= Self.undeliveredKeyThreshold {
            field.typeKey(.return, modifierFlags: [])
        }
    }

    /// `typeKey` がこの秒数以上かかったら、キーが送り先に届かなかったとみなす（届かないと、XCTest は約 5 秒待ってあきらめる）。
    static var undeliveredKeyThreshold: TimeInterval {
        3
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

/// ボタン類が出ているあいだに使えるショートカット（`Command` と一緒に押す）。
enum ToolbarShortcut: String {
    /// `⌘C`: プロンプトをコピーする。
    case copyPrompt = "c"
    /// `⌘L`: 一覧を開く・閉じる。
    case list = "l"
}

/// メニューバーのアイコンへ、アクセシビリティの「押す」操作を送る（`openMenuBarMenu()` が使う）。
///
/// ほかのアプリの要素へ操作を送るには、テストの実行役にアクセシビリティの許可が要る（システム設定 → プライバシーとセキュリティ →
/// アクセシビリティ）。XCUITest の操作はこの許可なしで動くので、既定では許可はなく、この操作は送れない（false を返す）。
enum MenuBarIconPress {
    /// 押せたら true。許可がない、アプリやアイコンが見つからない、操作が送れないときは false。
    static func press(bundleIdentifier: String, identifier: String) -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }
        guard let running = applicationUnderTest(bundleIdentifier: bundleIdentifier) else {
            return false
        }
        guard let item = statusItem(of: running, identifier: identifier) else {
            return false
        }
        // メニューを開くとメニューの操作が終わるまで返らないことがあるので、待つのは短くする。
        AXUIElementSetMessagingTimeout(item, 1)
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        // メニューが開いて返りが遅れたとき（`cannotComplete`）も、押せたことにする（メニューが出たかは呼び出し側が待つ）。
        return result == .success || result == .cannotComplete
    }

    /// 開いているメニューの項目 `identifier` を押す。押せたら true。許可がない、項目が見つからない、操作が送れないときは false。
    static func pressMenuItem(bundleIdentifier: String, iconIdentifier: String, identifier: String) -> Bool {
        guard AXIsProcessTrusted() else {
            return false
        }
        guard let running = applicationUnderTest(bundleIdentifier: bundleIdentifier) else {
            return false
        }
        guard let icon = statusItem(of: running, identifier: iconIdentifier) else {
            return false
        }
        guard let item = descendant(of: icon, identifier: identifier, depth: 4) else {
            return false
        }
        AXUIElementSetMessagingTimeout(item, 1)
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        return result == .success || result == .cannotComplete
    }

    /// テストする akapen のメニューバーのアイコン（`AXExtrasMenuBar` の項目）。
    private static func statusItem(of running: NSRunningApplication, identifier: String) -> AXUIElement? {
        let application = AXUIElementCreateApplication(running.processIdentifier)
        guard let extras = attribute(application, "AXExtrasMenuBar") else {
            return nil
        }
        return children(of: extras as! AXUIElement).first { matches($0, identifier: identifier) }
    }

    /// `element` の子孫（`depth` 段まで）から、識別子が `identifier` の要素を探す。
    private static func descendant(of element: AXUIElement, identifier: String, depth: Int) -> AXUIElement? {
        guard depth > 0 else {
            return nil
        }
        for child in children(of: element) {
            if (attribute(child, kAXIdentifierAttribute) as? String) == identifier {
                return child
            }
            if let found = descendant(of: child, identifier: identifier, depth: depth - 1) {
                return found
            }
        }
        return nil
    }

    /// テストが起動した akapen。
    ///
    /// 同じバンドル ID の akapen がほかにも動いている（手元で普段使いの akapen を起動している、など）と、
    /// そちらのアイコンを押してしまい、テストの akapen のメニューが開かない。
    /// そこで、テストの実行役（AkapenE2E-Runner.app）と同じビルドの置き場にある akapen.app を選ぶ。見つからなければ、最後に起動したもの。
    private static func applicationUnderTest(bundleIdentifier: String) -> NSRunningApplication? {
        let candidates = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        let products = Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath()
        let built = candidates.first { candidate in
            candidate.bundleURL?.deletingLastPathComponent().resolvingSymlinksInPath() == products
        }
        if let built {
            return built
        }
        return candidates.max { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    /// 自分か子の識別子が一致するか（識別子はステータス項目のボタンに付いている）。
    private static func matches(_ element: AXUIElement, identifier: String) -> Bool {
        if (attribute(element, kAXIdentifierAttribute) as? String) == identifier {
            return true
        }
        return children(of: element).contains { (attribute($0, kAXIdentifierAttribute) as? String) == identifier }
    }
}
