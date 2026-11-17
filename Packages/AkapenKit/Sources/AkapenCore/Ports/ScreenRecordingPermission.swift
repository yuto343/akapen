/// 画面収録の事前確認と OS の許可要求。
@MainActor public protocol ScreenRecordingPermission {
    var isGranted: Bool { get }

    /// OS の許可要求を行い、現時点の許可状態を返す。
    func request() -> Bool
}
