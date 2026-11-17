import Testing
import AkapenCore

/// 修飾キーの全組み合わせ（4 ビット = 16 通り）。
private let allModifiers: [KeyModifiers] = (0..<16).map { KeyModifiers(rawValue: UInt32($0)) }

/// 変換中でないときの期待値の表。ここにない組み合わせは passThrough。
private func expected(_ modifiers: KeyModifiers, _ confirmKey: ConfirmKey) -> ConfirmKeyDecision {
    switch (confirmKey, modifiers) {
    case (.enter, []):
        .confirm
    case (.enter, .shift):
        .insertNewline
    case (.commandEnter, .command):
        .confirm
    case (.commandEnter, []):
        .insertNewline
    default:
        .passThrough
    }
}

@Test(arguments: [ConfirmKey.enter, .commandEnter])
func decidesEveryModifierCombination(confirmKey: ConfirmKey) {
    for modifiers in allModifiers {
        let decision = ConfirmKeyPolicy.decide(modifiers: modifiers, isComposing: false, confirmKey: confirmKey)
        #expect(decision == expected(modifiers, confirmKey), "modifiers: \(modifiers.rawValue)")
    }
}

@Test(arguments: [ConfirmKey.enter, .commandEnter])
func passesThroughWhileComposing(confirmKey: ConfirmKey) {
    for modifiers in allModifiers {
        let decision = ConfirmKeyPolicy.decide(modifiers: modifiers, isComposing: true, confirmKey: confirmKey)
        #expect(decision == .passThrough, "modifiers: \(modifiers.rawValue)")
    }
}

@Test
func representativeCombinations() {
    #expect(ConfirmKeyPolicy.decide(modifiers: [], isComposing: false, confirmKey: .enter) == .confirm)
    #expect(ConfirmKeyPolicy.decide(modifiers: .shift, isComposing: false, confirmKey: .enter) == .insertNewline)
    #expect(ConfirmKeyPolicy.decide(modifiers: .command, isComposing: false, confirmKey: .enter) == .passThrough)
    #expect(ConfirmKeyPolicy.decide(modifiers: .command, isComposing: false, confirmKey: .commandEnter) == .confirm)
    #expect(ConfirmKeyPolicy.decide(modifiers: [], isComposing: false, confirmKey: .commandEnter) == .insertNewline)
    #expect(ConfirmKeyPolicy.decide(modifiers: .shift, isComposing: false, confirmKey: .commandEnter) == .passThrough)
    #expect(ConfirmKeyPolicy.decide(modifiers: [.command, .shift], isComposing: false, confirmKey: .commandEnter) == .passThrough)
    #expect(ConfirmKeyPolicy.decide(modifiers: [], isComposing: true, confirmKey: .enter) == .passThrough)
}
