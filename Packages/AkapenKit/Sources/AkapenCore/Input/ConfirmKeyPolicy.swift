/// Return キーが押されたときの扱い。
public enum ConfirmKeyDecision: Sendable {
    case confirm
    case insertNewline
    case passThrough
}

/// 押されたキーと設定から、コメント欄での Return の扱いを決める。
public enum ConfirmKeyPolicy {
    /// Return キーが押されたときに呼ぶ。変換中（isComposing）は常に passThrough。
    public static func decide(
        modifiers: KeyModifiers,
        isComposing: Bool,
        confirmKey: ConfirmKey
    ) -> ConfirmKeyDecision {
        // TODO(core): 仮実装。網羅テストと細部の見直しは次の担当が行う。
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
