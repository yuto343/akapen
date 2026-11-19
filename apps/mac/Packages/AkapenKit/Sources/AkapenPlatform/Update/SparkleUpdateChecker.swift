import Sparkle
import AkapenCore

/// Sparkle で更新を確かめる。
///
/// 作った時点で Sparkle の更新役を動かし始め、`Info.plist` の `SUFeedURL`・`SUPublicEDKey`・`SUEnableAutomaticChecks` に従って
/// 裏で定期的に確かめる。更新の画面は Sparkle の標準のまま（`Tokens` に合わせない）。
/// ネットワークに出るので、E2E と結合テストでは作らない（`CountingUpdateChecker` を使う）。
@MainActor public final class SparkleUpdateChecker: UpdateChecking {
    private let controller: SPUStandardUpdaterController

    /// Sparkle の更新役を作って動かし始める。
    public init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Sparkle の「アップデートを確認」を走らせる。結果は Sparkle が画面に出す。
    public func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
