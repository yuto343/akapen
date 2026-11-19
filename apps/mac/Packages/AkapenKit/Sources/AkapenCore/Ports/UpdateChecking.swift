/// アプリの更新の確認。メニューバーの「アップデートを確認…」から呼ぶ。
///
/// 本番は Sparkle（`SparkleUpdateChecker`）、E2E では何もせず呼ばれた回数だけを数える実装（`CountingUpdateChecker`）。
/// どちらを使うかは `AppEnvironment` が決める。
@MainActor public protocol UpdateChecking: AnyObject {
    /// 更新があるかをいま確かめる。結果の画面（更新の案内・最新です・失敗）は実装が出す。
    func checkForUpdates()
}
