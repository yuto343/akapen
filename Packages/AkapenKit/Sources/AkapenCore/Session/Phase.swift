/// セッションの表示状態。遷移の所有者は SessionModel のみ。
public enum Phase: String, Codable, Sendable {
    case hidden
    case drawing
    case commenting
    case idle
    case listOpen
    case copied
}
