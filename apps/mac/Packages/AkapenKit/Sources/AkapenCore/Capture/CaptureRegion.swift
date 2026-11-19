/// 描いた枠から決めた、撮る範囲。
///
/// 決まりは `DESIGN.md`「キャプチャ」のとおり。枠内に見えているウィンドウ全体をまとめて囲む矩形を、
/// 枠を描いたディスプレイの中に切り詰めたものを撮る。見えているウィンドウがなければ、枠のまわりに余白を足す。
public struct CaptureRegion: Sendable, Equatable {
    /// 撮る範囲（画面全体の座標、pt）。必ず枠を描いたディスプレイの中にあり、幅と高さは整数の pt。
    public let rect: ScreenRect

    /// 撮る範囲を決めたウィンドウ。枠内に見えている面積の大きい順（同じなら手前のもの）。なければ空。
    public let windows: [CaptureWindow]

    /// 見えている面積が枠の面積のこの割合に満たないウィンドウは、範囲に入れない（端がかすっただけのもの）。
    public static let minimumVisibleShare = 0.05

    /// 見えているウィンドウがないときに、枠の上下左右に足す余白（pt）。
    public static let marginWithoutWindow = 200.0

    /// 範囲とウィンドウを直接渡す。ふつうは `resolve(frame:screen:windows:)` で作る。
    public init(rect: ScreenRect, windows: [CaptureWindow]) {
        self.rect = rect
        self.windows = windows
    }

    /// 一覧に出すアプリ名。見えている面積の大きい順に、重複と空の名前を除いて `, ` でつなぐ。ウィンドウがなければ空文字。
    public var sourceAppName: String {
        var names: [String] = []
        for window in windows where !window.appName.isEmpty && !names.contains(window.appName) {
            names.append(window.appName)
        }
        return names.joined(separator: ", ")
    }

    /// 描いた枠と、手前から並んだウィンドウの一覧から、撮る範囲を決める。
    ///
    /// - Parameters:
    ///   - frame: 描いた枠（画面全体の座標、pt）。
    ///   - screen: 枠を描いたディスプレイ。範囲はこの中に切り詰める（ディスプレイをまたいでは撮らない）。
    ///   - windows: `WindowCapturing.windows()` と同じく、手前から順に並んだウィンドウ。
    ///
    /// 1. 手前から順に、枠のうち「まだ手前のウィンドウに隠されていない部分」と重なる面積を数える。
    /// 2. その面積が枠の面積の 5% 未満のウィンドウは外す。
    /// 3. 残ったウィンドウをまとめて囲む矩形を範囲にする。残らなければ、枠の上下左右に 200pt 足した矩形にする。
    /// 4. 範囲を整数の pt に外側へ丸め、ディスプレイの中に切り詰める。
    public static func resolve(frame: ScreenRect, screen: ScreenDescriptor, windows: [CaptureWindow]) -> CaptureRegion {
        let visible = visibleWindows(frame: frame, from: windows)
        let bounds: ScreenRect
        if let first = visible.first {
            bounds = visible.dropFirst().reduce(first.frame) { $0.union($1.frame) }
        } else {
            bounds = frame.insetBy(-marginWithoutWindow)
        }
        // 枠がディスプレイの外にしかない（ふつうは起きない）ときは、ディスプレイ全体を撮る。
        let clipped = bounds.integralOutward.intersection(screen.frame) ?? screen.frame
        return CaptureRegion(rect: clipped, windows: visible)
    }

    /// 枠内に見えている面積が 5% 以上のウィンドウを、見えている面積の大きい順（同じなら手前のもの）に返す。
    private static func visibleWindows(frame: ScreenRect, from windows: [CaptureWindow]) -> [CaptureWindow] {
        guard frame.area > 0 else {
            return []
        }
        let threshold = frame.area * minimumVisibleShare
        var uncovered = [frame]
        var found: [(window: CaptureWindow, area: Double)] = []
        for window in windows {
            if uncovered.isEmpty {
                break
            }
            var visibleArea = 0.0
            var remaining: [ScreenRect] = []
            for piece in uncovered {
                guard let overlap = piece.intersection(window.frame) else {
                    remaining.append(piece)
                    continue
                }
                visibleArea += overlap.area
                remaining.append(contentsOf: piece.subtracting(overlap))
            }
            uncovered = remaining
            if visibleArea >= threshold {
                found.append((window, visibleArea))
            }
        }
        // 安定な並べ替えにして、同じ面積なら手前のものを先にする。
        return found.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.area != rhs.element.area {
                    return lhs.element.area > rhs.element.area
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element.window)
    }
}

extension ScreenRect {
    /// 2 つの矩形をまとめて囲む矩形。
    func union(_ other: ScreenRect) -> ScreenRect {
        let left = Swift.min(x, other.x)
        let top = Swift.min(y, other.y)
        let right = Swift.max(maxX, other.maxX)
        let bottom = Swift.max(maxY, other.maxY)
        return ScreenRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// 上下左右に `amount` ずつ縮めた矩形（負の値なら広げる）。
    func insetBy(_ amount: Double) -> ScreenRect {
        ScreenRect(
            x: x + amount,
            y: y + amount,
            width: Swift.max(0, width - amount * 2),
            height: Swift.max(0, height - amount * 2)
        )
    }

    /// 端を整数の pt に外側へ丸めた矩形。
    var integralOutward: ScreenRect {
        let left = x.rounded(.down)
        let top = y.rounded(.down)
        let right = maxX.rounded(.up)
        let bottom = maxY.rounded(.up)
        return ScreenRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// 矩形から、その内側にある `inner` を取り除いた残り（最大 4 つの矩形）。
    func subtracting(_ inner: ScreenRect) -> [ScreenRect] {
        var pieces: [ScreenRect] = []
        // 上の帯。
        if inner.y > y {
            pieces.append(ScreenRect(x: x, y: y, width: width, height: inner.y - y))
        }
        // 下の帯。
        if inner.maxY < maxY {
            pieces.append(ScreenRect(x: x, y: inner.maxY, width: width, height: maxY - inner.maxY))
        }
        // 左の帯（上下の帯にはさまれた高さ）。
        if inner.x > x {
            pieces.append(ScreenRect(x: x, y: inner.y, width: inner.x - x, height: inner.height))
        }
        // 右の帯。
        if inner.maxX < maxX {
            pieces.append(ScreenRect(x: inner.maxX, y: inner.y, width: maxX - inner.maxX, height: inner.height))
        }
        return pieces
    }
}
