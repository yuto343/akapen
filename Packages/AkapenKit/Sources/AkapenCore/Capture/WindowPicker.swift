/// 描いた枠から、撮影するウィンドウを選ぶ。
public enum WindowPicker {
    /// 枠との重なりの面積が最も大きいウィンドウを返す。
    ///
    /// - 重なりが 0 のウィンドウは選ばない。どれとも重ならなければ nil。
    /// - 面積が同じなら手前のもの（`windows` で先にあるもの）を選ぶ。
    ///   `windows` は `WindowCapturing.windows()` と同じく、手前から順に並んでいる前提。
    public static func pick(frame: ScreenRect, from windows: [CaptureWindow]) -> CaptureWindow? {
        var best: CaptureWindow?
        var bestArea = 0.0
        for window in windows {
            guard let overlap = window.frame.intersection(frame) else {
                continue
            }
            if overlap.area > bestArea {
                best = window
                bestArea = overlap.area
            }
        }
        return best
    }
}
