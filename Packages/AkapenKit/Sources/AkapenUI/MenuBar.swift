import AppKit
import AkapenAXID

/// 常駐アイコンと終了操作。所有中はメニューバーに残る。
@MainActor public final class MenuBar {
    private let item: NSStatusItem

    public init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "akapen")
        let menu = NSMenu()
        let quit = NSMenuItem(
            title: UIStrings.text("quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.setAccessibilityIdentifier(AXID.MenuBar.quit)
        menu.addItem(quit)
        item.menu = menu
    }
}
