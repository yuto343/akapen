/// セッションの表示状態。遷移の所有者は SessionModel のみ。
///
/// ボタン類が出ているのは `drawing`・`commenting`・`listOpen` のあいだだけで、そのあいだは画面全体を覆う面がマウスを受ける。
public enum Phase: String, Codable, Sendable {
    /// 何も出ていない。確定済みの注釈は残っていることがある（回は `copy prompt` で終わるまで続く）。
    case hidden
    /// ボタン類が出ていて、枠を描ける。
    case drawing
    /// 撮影した枠にコメントを書いている。
    case commenting
    /// ボタン類の上に一覧を開いている。
    case listOpen
    /// コピー完了の表示だけが出ている。
    case copied
}
