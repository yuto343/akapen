/// グローバル入力の登録。再登録は以前の登録を置き換え、失敗は throws。
@MainActor public protocol HotkeyRegistering {
    /// 既存登録を解除して登録する。handler はメインアクターで呼ぶ。
    func register(_ shortcut: KeyboardShortcut, handler: @escaping @MainActor () -> Void) throws

    /// 登録とハンドラーを解放する。未登録時も安全に呼べる。
    func unregister()
}
