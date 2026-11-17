/// Return キーが押されたときの扱い。
public enum ConfirmKeyDecision: Sendable {
    case confirm
    case insertNewline
    case passThrough
}

/// 押されたキーと設定から、コメント欄での Return の扱いを決める。
public enum ConfirmKeyPolicy {
    /// Return キーが押されたときに呼ぶ。変換中（isComposing）は常に passThrough。
    ///
    /// - `Enter` で確定: 修飾なしは確定、`Shift` だけは改行。
    /// - `⌘Enter` で確定: `⌘` だけは確定、修飾なしは改行。
    /// - それ以外の組み合わせは passThrough（入力欄に任せる）。
    public static func decide(
        modifiers: KeyModifiers,
        isComposing: Bool,
        confirmKey: ConfirmKey
    ) -> ConfirmKeyDecision {
        if isComposing {
            return .passThrough
        }
        switch confirmKey {
        case .enter:
            if modifiers.isEmpty {
                return .confirm
            }
            if modifiers == .shift {
                return .insertNewline
            }
            return .passThrough
        case .commandEnter:
            if modifiers == .command {
                return .confirm
            }
            if modifiers.isEmpty {
                return .insertNewline
            }
            return .passThrough
        }
    }
}
