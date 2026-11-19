import AkapenCore

/// OS にもネットワークにも触らない更新の確認。E2E と結合テスト用。
///
/// 確かめる代わりに、呼ばれた回数を数えるだけにする。
@MainActor public final class CountingUpdateChecker: UpdateChecking {
    /// `checkForUpdates()` が呼ばれた回数。
    public private(set) var checkCount = 0

    /// 回数 0 で作る。
    public init() {}

    /// 回数を 1 増やすだけで、何も確かめない。
    public func checkForUpdates() {
        checkCount += 1
    }
}
