import AppKit
import AkapenCore
import AkapenAXID

/// アプリのメインメニュー（`NSApp.mainMenu`）。
///
/// akapen は Dock に出ない（`LSUIElement`）ので、画面の上にこのメニューは出ない。
/// それでも、akapen のウィンドウやパネルにキー入力が来ているあいだの、次のキーを効かせるために置く。
/// - `⌘Q`（終了を求める。確認を出すかは組み立ての側が決める）と `⌘,`（設定を開く）。
/// - 入力欄の編集のキー（`⌘Z`・`⇧⌘Z`・`⌘X`・`⌘C`・`⌘V`・`⌘A`）。コメント・一覧・定型文の入力欄で使う。
///
/// 項目が選ばれたら、コールバックで外に伝えるだけにする（`MenuBarController` と同じ）。
@MainActor public final class MainMenuController: NSObject {
    /// `Settings…`（`⌘,`）が選ばれたとき。
    public var onOpenSettings: (@MainActor () -> Void)?

    /// `Quit akapen`（`⌘Q`）が選ばれたとき。終了の確認を出すか、そのまま終了するかは受け取った側が決める。
    public var onQuitRequested: (@MainActor () -> Void)?

    /// メインメニュー。
    let menu: NSMenu
    private let appItem: NSMenuItem
    private let editItem: NSMenuItem
    private let settingsItem: NSMenuItem
    private let quitItem: NSMenuItem
    /// 編集の項目と、その文言のキー。
    private let editItems: [(item: NSMenuItem, key: StringKey)]
    /// いまの文言の言語。
    private(set) var language: Language

    /// 文言の言語を受け取って組み立てる。`install()` を呼ぶまでアプリには付けない。
    public init(language: Language) {
        self.language = language
        menu = NSMenu()
        appItem = NSMenuItem()
        editItem = NSMenuItem()
        settingsItem = NSMenuItem(title: "", action: nil, keyEquivalent: ",")
        quitItem = NSMenuItem(title: "", action: nil, keyEquivalent: "q")
        editItems = [
            (Self.editItem(action: Selector(("undo:")), key: "z", modifiers: .command, identifier: AXID.MainMenu.undo), .menuUndo),
            (Self.editItem(action: Selector(("redo:")), key: "z", modifiers: [.command, .shift], identifier: AXID.MainMenu.redo), .menuRedo),
            (Self.editItem(action: #selector(NSText.cut(_:)), key: "x", modifiers: .command, identifier: AXID.MainMenu.cut), .menuCut),
            (Self.editItem(action: #selector(NSText.copy(_:)), key: "c", modifiers: .command, identifier: AXID.MainMenu.copy), .menuCopy),
            (Self.editItem(action: #selector(NSText.paste(_:)), key: "v", modifiers: .command, identifier: AXID.MainMenu.paste), .menuPaste),
            (Self.editItem(action: #selector(NSText.selectAll(_:)), key: "a", modifiers: .command, identifier: AXID.MainMenu.selectAll), .menuSelectAll),
        ]
        super.init()
        buildMenu()
        setLanguage(language)
    }

    /// アプリのメインメニューにする。
    public func install() {
        NSApp.mainMenu = menu
    }

    /// 文言の言語を切り替える。
    public func setLanguage(_ language: Language) {
        self.language = language
        let strings = UIStrings(language: language)
        appItem.title = strings[.appName]
        appItem.submenu?.title = strings[.appName]
        settingsItem.title = strings[.menuSettings]
        quitItem.title = strings[.menuQuit]
        editItem.title = strings[.menuEdit]
        editItem.submenu?.title = strings[.menuEdit]
        for (item, key) in editItems {
            item.title = strings[key]
        }
    }

    // MARK: - 組み立て

    private func buildMenu() {
        let appMenu = NSMenu()
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        settingsItem.action = #selector(openSettings(_:))
        settingsItem.setAccessibilityIdentifier(AXID.MainMenu.settings)
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        quitItem.action = #selector(requestQuit(_:))
        quitItem.setAccessibilityIdentifier(AXID.MainMenu.quit)
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editMenu = NSMenu()
        for (index, entry) in editItems.enumerated() {
            if index == 2 {
                editMenu.addItem(.separator())
            }
            editMenu.addItem(entry.item)
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
    }

    /// 宛先を決めない（キー入力を受け取っている入力欄に届ける）編集の項目。
    private static func editItem(
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags,
        identifier: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.setAccessibilityIdentifier(identifier)
        return item
    }

    @objc private func openSettings(_ sender: Any?) {
        onOpenSettings?()
    }

    @objc private func requestQuit(_ sender: Any?) {
        onQuitRequested?()
    }
}
