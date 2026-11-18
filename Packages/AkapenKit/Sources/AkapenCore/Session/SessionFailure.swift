/// 直前の操作が失敗した理由。
public enum SessionFailure: Sendable, Equatable {
    case captureFailed
    case imageSaveFailed
    case pasteboardFailed
    case settingsSaveFailed
}
