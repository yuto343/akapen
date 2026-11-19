import AppKit
import ImageIO
import AkapenCore

/// サムネイルの切り抜き方（`DECISIONS.md` 23）。
///
/// 撮影した画像を、サムネイルの縦横比で隙間なく埋まるように切り抜く。切り抜く位置は、赤枠の中心が中央に来るようにし、画像の外にははみ出さない。
enum ThumbnailCrop {
    /// 画像（ピクセル。左上原点）から切り抜く範囲。
    ///
    /// - Parameters:
    ///   - imageSize: 画像の大きさ（ピクセル）。
    ///   - windowFrame: 撮影したウィンドウの矩形（画像全体に当たる。画面全体を通した座標）。
    ///   - frame: 赤枠の矩形（画面全体を通した座標）。
    ///   - aspect: サムネイルの縦横比（幅 ÷ 高さ）。
    static func rect(imageSize: CGSize, windowFrame: ScreenRect, frame: ScreenRect, aspect: CGFloat) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, aspect > 0 else {
            return .zero
        }
        let size: CGSize
        if imageSize.width / imageSize.height > aspect {
            size = CGSize(width: imageSize.height * aspect, height: imageSize.height)
        } else {
            size = CGSize(width: imageSize.width, height: imageSize.width / aspect)
        }
        let scaleX = windowFrame.width > 0 ? imageSize.width / windowFrame.width : 1
        let scaleY = windowFrame.height > 0 ? imageSize.height / windowFrame.height : 1
        let focusX = (frame.centerX - windowFrame.x) * scaleX
        let focusY = (frame.centerY - windowFrame.y) * scaleY
        return CGRect(
            x: clamp(focusX - size.width / 2, upper: imageSize.width - size.width),
            y: clamp(focusY - size.height / 2, upper: imageSize.height - size.height),
            width: size.width,
            height: size.height
        )
    }

    private static func clamp(_ value: CGFloat, upper: CGFloat) -> CGFloat {
        max(0, min(value, upper))
    }
}

/// 一覧の行のサムネイルを用意する。テストでは決まった画像を返す偽物に差し替える。
@MainActor protocol ThumbnailProviding: AnyObject {
    /// 注釈のサムネイル（サムネイルの縦横比に切り抜いたもの）。画像が読めなければ nil。
    func thumbnail(for annotation: Annotation) -> NSImage?

    /// いまの注釈にない画像の控えを捨てる。
    func retain(_ annotations: [Annotation])
}

/// 保存された画像ファイルからサムネイルを作る。一度作ったものは控えておく。
@MainActor final class FileThumbnailProvider: ThumbnailProviding {
    private var cache: [String: NSImage?] = [:]

    func thumbnail(for annotation: Annotation) -> NSImage? {
        if let cached = cache[annotation.imagePath] {
            return cached
        }
        let image = load(annotation)
        cache[annotation.imagePath] = image
        return image
    }

    func retain(_ annotations: [Annotation]) {
        let paths = Set(annotations.map(\.imagePath))
        cache = cache.filter { paths.contains($0.key) }
    }

    private func load(_ annotation: Annotation) -> NSImage? {
        let url = URL(filePath: annotation.imagePath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let crop = ThumbnailCrop.rect(
            imageSize: CGSize(width: image.width, height: image.height),
            windowFrame: annotation.windowFrame,
            frame: annotation.rect,
            aspect: Tokens.List.thumbnailWidth / Tokens.List.thumbnailHeight
        )
        guard let cropped = image.cropping(to: crop) else {
            return nil
        }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }
}

/// 一覧の行のメタ情報の時刻（時:分、24 時間制）。
enum AnnotationTime {
    static func string(from date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        return String(format: "%02ld:%02ld", hour, minute)
    }
}
