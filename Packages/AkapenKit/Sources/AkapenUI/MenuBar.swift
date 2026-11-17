import AppKit

/// 組み立て（`AkapenApp`）が `MenuBarController` に移るまでの互換用。新しいコードでは使わない。
///
/// いまの `AppDelegate` は `MenuBar()` を呼んでいるので、その呼び出しのまま、メニューバーのアイコンと
/// 新しいメニューが出るようにしている。`SessionModel` につながっていないので、件数は 0 件、言語は英語のまま。
/// `Settings…` は使えない状態で出す。`Quit akapen` は確認なしで終了する。
/// TODO(app): 組み立ての作業で `MenuBarController(model:)` に置き換え、この型を消す。
@MainActor public final class MenuBar {
    private let controller: MenuBarController

    /// メニューバーにアイコンを置く。
    public init() {
        controller = MenuBarController(
            status: {
                MenuBarStatus(annotationCount: 0, language: .en)
            },
            installsStatusItem: true
        )
        controller.onQuitRequested = {
            NSApp.terminate(nil)
        }
    }
}
