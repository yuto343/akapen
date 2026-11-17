import AkapenCore

/// 終了を求められたときに、確認を出すかを決める（`DECISIONS.md` A4）。
public enum QuitPolicy {
    /// 終了の確認に出す件数。確定済みの注釈の件数に、書きかけの注釈があれば 1 を足す。0 なら確認を出さずに終了する。
    @MainActor public static func pendingCount(_ model: SessionModel) -> Int {
        pendingCount(annotationCount: model.annotations.count, hasDraft: model.draft != nil)
    }

    /// 終了の確認に出す件数。
    public static func pendingCount(annotationCount: Int, hasDraft: Bool) -> Int {
        annotationCount + (hasDraft ? 1 : 0)
    }
}
