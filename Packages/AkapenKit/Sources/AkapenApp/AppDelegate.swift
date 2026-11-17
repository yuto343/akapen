import AppKit
import AkapenUI
/// エントリポイントから起動されるアプリの組み立て役。
@MainActor public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var windows: SessionWindows?
    private var menu: MenuBar?
    public override init() { super.init() }
    public func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let environment = try AppEnvironment.make(LaunchConfiguration(environment: ProcessInfo.processInfo.environment))
            self.environment = environment
            let windows = SessionWindows(model: environment.model); self.windows = windows
            menu = MenuBar()
            environment.model.onChange = { [weak environment, weak windows] in environment?.writeState(); windows?.render() }
            try environment.hotkey.register(environment.model.settings.hotkey) { [weak environment] in environment?.model.send(.hotkeyPressed) }
        } catch { NSLog("akapen startup failed: %@", String(describing: error)); NSApp.terminate(nil) }
    }
    public func applicationWillTerminate(_ notification: Notification) { environment?.hotkey.unregister(); windows?.hide() }
}
