import AppKit
import AkapenUI

/// エントリポイントから起動されるアプリの組み立て役。
///
/// 起動設定を読み、`AppEnvironment` を組み立て（`AKAPEN_SEED` の前提づくりまで）、`AppController` で画面をつなぐ。
/// 組み立てに失敗したら、理由を残して終了する（E2E では `AKAPEN_STATE_DIR/startup-error.txt`）。
@MainActor public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?

    public override init() {
        super.init()
    }

    /// 起動設定を読み、組み立てを始める（前提づくりに待ちがあるので、続きは非同期で行う）。
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = LaunchConfiguration(environment: ProcessInfo.processInfo.environment)
        Task { @MainActor in
            await start(configuration)
        }
    }

    /// 終了の要求（メニュー・`⌘Q`・システム）。注釈が残っていれば確認を出し、いまは終了しない。
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else {
            return .terminateNow
        }
        return controller.shouldTerminate() ? .terminateNow : .terminateCancel
    }

    /// 終了する直前に、ホットキーの登録を外して画面を片付ける。
    public func applicationWillTerminate(_ notification: Notification) {
        controller?.willTerminate()
    }

    private func start(_ configuration: LaunchConfiguration) async {
        do {
            let environment = try await AppEnvironment.make(configuration)
            let controller = AppController(environment: environment)
            self.controller = controller
            controller.start()
        } catch {
            NSLog("akapen: 起動できなかった: %@", String(describing: error))
            AppEnvironment.reportStartupFailure(error, configuration: configuration)
            NSApp.terminate(nil)
        }
    }
}
