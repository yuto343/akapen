import Foundation

/// 状態機械の入力。画面・ホットキー・タイマーはこの入口に集約する。
public enum SessionEvent: Sendable {
    /// ホットキー。ボタン類を出す・隠すのトグルを兼ねる。
    case hotkeyPressed
    case escapePressed
    case dragEnded(rect: ScreenRect, screen: ScreenDescriptor)
    case commentConfirmed(text: String)
    case commentCancelled
    case listToggled
    case annotationEdited(id: UUID, text: String)
    case annotationDeleted(id: UUID)
    /// 確定済みの注釈と画像をすべて消す。
    case annotationsCleared
    case copyPromptTapped
    case copiedExpired
    /// 浮く部品を下げる（設定やセットアップのウィンドウを開くとき。画面全体を覆う面がウィンドウを隠さないように）。
    case dismissRequested
    case settingsChanged(Settings)
    case setupCompleted
}
