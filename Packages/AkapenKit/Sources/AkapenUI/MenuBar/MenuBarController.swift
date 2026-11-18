import AppKit
import SwiftUI
import AkapenCore
import AkapenAXID

/// メニューに出す値。メニューを開くたびに読み直す。
public struct MenuBarStatus: Equatable, Sendable {
    /// 未コピーの（確定済みの）注釈の件数。
    public var annotationCount: Int
    /// 表示の言語（`Settings.language`）。
    public var language: Language

    /// 値をそのまま持つ。
    public init(annotationCount: Int, language: Language) {
        self.annotationCount = annotationCount
        self.language = language
    }
}

/// メニューバーのアイコンとメニュー（App 05。標準の `NSStatusItem` と `NSMenu`。`DECISIONS.md` 9・14・16）。
///
/// メニューの中身は、見出し（アイコン＋ `akapen` ＋注釈の件数）、区切り、`Settings…`（`⌘,`）、区切り、`Quit akapen`（`⌘Q`）。
/// 件数と言語はメニューを開くたびに読み直す。
/// 項目が選ばれたら、コールバックで外に伝えるだけにする。自分では設定を開かず、アプリも終了しない
/// （終了の確認を出すかどうかは組み立ての側が決める）。
/// コールバックが入っていない項目は、使えない状態で出す。
///
/// 持っている間はメニューバーにアイコンが出る。手放すとアイコンも消える。
@MainActor public final class MenuBarController: NSObject, NSMenuDelegate {
    /// `Settings…` が選ばれたとき。
    public var onOpenSettings: (@MainActor () -> Void)? {
        didSet {
            updateItemStates()
        }
    }

    /// `Quit akapen` が選ばれたとき。終了の確認を出すか、そのまま終了するかは受け取った側が決める。
    public var onQuitRequested: (@MainActor () -> Void)? {
        didSet {
            updateItemStates()
        }
    }

    /// メニュー。
    let menu: NSMenu
    let headerView: NSHostingView<MenuHeaderView>
    let settingsItem: NSMenuItem
    let quitItem: NSMenuItem
    /// 最後に読んだ値。
    private(set) var status: MenuBarStatus
    private let statusSource: @MainActor () -> MenuBarStatus
    private var statusItem: NSStatusItem?

    /// `model` の注釈の件数と言語をメニューに出す。メニューバーにアイコンを置く。
    public convenience init(model: SessionModel) {
        self.init(
            status: { [weak model] in
                MenuBarStatus(
                    annotationCount: model?.annotations.count ?? 0,
                    language: model?.settings.language ?? Settings().language
                )
            },
            installsStatusItem: true
        )
    }

    /// テスト用。`status` はメニューを開くたびに呼ぶ。`installsStatusItem` が false なら、メニューバーにアイコンを置かない。
    init(status: @escaping @MainActor () -> MenuBarStatus, installsStatusItem: Bool) {
        statusSource = status
        let initial = status()
        self.status = initial
        let strings = UIStrings(language: initial.language)
        menu = NSMenu()
        headerView = NSHostingView(rootView: MenuHeaderView(annotationCount: initial.annotationCount, strings: strings))
        settingsItem = NSMenuItem(title: strings[.menuSettings], action: nil, keyEquivalent: ",")
        quitItem = NSMenuItem(title: strings[.menuQuit], action: nil, keyEquivalent: "q")
        super.init()
        buildMenu()
        if installsStatusItem {
            installStatusItem(strings: strings)
        }
        refresh()
    }

    /// 件数と言語を読み直して、メニューに映す。
    func refresh() {
        status = statusSource()
        let strings = UIStrings(language: status.language)
        headerView.rootView = MenuHeaderView(annotationCount: status.annotationCount, strings: strings)
        headerView.frame = NSRect(origin: .zero, size: headerView.fittingSize)
        settingsItem.title = strings[.menuSettings]
        quitItem.title = strings[.menuQuit]
        statusItem?.button?.setAccessibilityLabel(strings[.appName])
        updateItemStates()
    }

    // MARK: NSMenuDelegate

    /// メニューを開く直前に、件数と言語を読み直す。
    public func menuNeedsUpdate(_ menu: NSMenu) {
        refresh()
    }

    // MARK: 組み立て

    private func buildMenu() {
        menu.autoenablesItems = false
        menu.showsStateColumn = false
        menu.appearance = NSAppearance(named: .aqua)
        menu.delegate = self
        let header = NSMenuItem()
        header.view = headerView
        menu.addItem(header)
        menu.addItem(.separator())
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        settingsItem.action = #selector(openSettings(_:))
        settingsItem.setAccessibilityIdentifier(AXID.MenuBar.settings)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        quitItem.action = #selector(requestQuit(_:))
        quitItem.setAccessibilityIdentifier(AXID.MenuBar.quit)
        menu.addItem(quitItem)
    }

    private func installStatusItem(strings: UIStrings) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = MenuBarIconImage.make()
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel(strings[.appName])
            button.setAccessibilityIdentifier(AXID.MenuBar.icon)
        }
        item.menu = menu
        statusItem = item
    }

    private func updateItemStates() {
        settingsItem.isEnabled = onOpenSettings != nil
        quitItem.isEnabled = onQuitRequested != nil
    }

    @objc private func openSettings(_ sender: Any?) {
        onOpenSettings?()
    }

    @objc private func requestQuit(_ sender: Any?) {
        onQuitRequested?()
    }
}

/// メニューバーのアイコン。`assets/logo/akapen-menubar-template.png`（黒と透明の、手でペンを持つ絵）を縮めてリソースに入れたもの。
///
/// テンプレート画像として出し、メニューバーの明るさに合わせた色をシステムに任せる（ユーザーの指示で `DECISIONS.md` 16 から変えた）。
@MainActor enum MenuBarIconImage {
    /// 表示の大きさ（15×17pt）にした画像。読めないときは nil。
    static func make() -> NSImage? {
        guard let image = Bundle.module.image(forResource: "MenuBarIcon")?.copy() as? NSImage else {
            return nil
        }
        image.size = NSSize(width: Tokens.Menu.statusIconWidth, height: Tokens.Menu.statusIconHeight)
        image.isTemplate = true
        return image
    }
}
