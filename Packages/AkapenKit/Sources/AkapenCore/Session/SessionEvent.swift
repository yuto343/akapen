import Foundation

/// 状態機械の入力。画面・ホットキー・タイマーはこの入口に集約する。
public enum SessionEvent: Sendable {
    case hotkeyPressed
    case addTapped
    case escapePressed
    case dragEnded(rect: ScreenRect, screen: ScreenDescriptor)
    case commentConfirmed(text: String)
    case commentCancelled
    case listToggled
    case annotationEdited(id: UUID, text: String)
    case annotationDeleted(id: UUID)
    case copyPromptTapped
    case copiedExpired
    case toolbarToggled
    case settingsChanged(Settings)
    case setupCompleted
}
