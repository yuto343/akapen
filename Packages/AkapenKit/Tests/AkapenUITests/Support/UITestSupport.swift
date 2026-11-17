import AppKit
import Foundation
import AkapenCore
@testable import AkapenUI

/// 決まった画面とカーソルの位置を返す偽物。実際の画面の大きさや枚数に結果が左右されないようにする。
@MainActor final class FakeScreens: ScreenProviding {
    var screens: [ScreenInfo]
    var mouseLocation: CGPoint
    let primaryTop: CGFloat

    init(screens: [ScreenInfo], mouseLocation: CGPoint, primaryTop: CGFloat) {
        self.screens = screens
        self.mouseLocation = mouseLocation
        self.primaryTop = primaryTop
    }

    /// Paper のアートボードと同じ 1280×800 の主画面。上 28pt がメニューバー。
    nonisolated static let primary = ScreenInfo(
        id: 1,
        frame: ScreenRect(x: 0, y: 0, width: 1280, height: 800),
        visibleFrame: ScreenRect(x: 0, y: 28, width: 1280, height: 772)
    )

    /// 主画面の左上にある副画面（原点が負の座標）。
    nonisolated static let secondary = ScreenInfo(
        id: 2,
        frame: ScreenRect(x: -1440, y: -100, width: 1440, height: 900),
        visibleFrame: ScreenRect(x: -1440, y: -75, width: 1440, height: 875)
    )

    static func single() -> FakeScreens {
        FakeScreens(screens: [primary], mouseLocation: CGPoint(x: 640, y: 400), primaryTop: 800)
    }

    static func dual() -> FakeScreens {
        FakeScreens(screens: [primary, secondary], mouseLocation: CGPoint(x: 640, y: 400), primaryTop: 800)
    }
}

/// 決まった画像を返すサムネイルの偽物。
@MainActor final class StubThumbnails: ThumbnailProviding {
    var images: [String: NSImage] = [:]

    func thumbnail(for annotation: Annotation) -> NSImage? {
        images[annotation.imagePath]
    }

    func retain(_ annotations: [Annotation]) {}
}

/// 送られた入力の記録。
@MainActor final class EventLog {
    private(set) var events: [SessionEvent] = []

    func append(_ event: SessionEvent) {
        events.append(event)
    }

    /// 送られた入力の名前（`SessionEvent` は比べられないので、名前で比べる）。
    var names: [String] {
        events.map { event in
            switch event {
            case .hotkeyPressed:
                "hotkeyPressed"
            case .addTapped:
                "addTapped"
            case .escapePressed:
                "escapePressed"
            case .dragEnded:
                "dragEnded"
            case .commentConfirmed:
                "commentConfirmed"
            case .commentCancelled:
                "commentCancelled"
            case .listToggled:
                "listToggled"
            case .annotationEdited:
                "annotationEdited"
            case .annotationDeleted:
                "annotationDeleted"
            case .copyPromptTapped:
                "copyPromptTapped"
            case .copiedExpired:
                "copiedExpired"
            case .toolbarToggled:
                "toolbarToggled"
            case .settingsChanged:
                "settingsChanged"
            case .setupCompleted:
                "setupCompleted"
            }
        }
    }
}

/// テストで使う注釈と時刻。
enum Fixtures {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo")!

    /// 2026-11-17 14:32（東京）。
    static let createdAt = Date(timeIntervalSince1970: 1_794_893_520)

    static func annotation(_ comment: String, path: String = "/nonexistent/01.png", rect: ScreenRect? = nil) -> Annotation {
        Annotation(
            imagePath: path,
            comment: comment,
            rect: rect ?? ScreenRect(x: 910, y: 468, width: 204, height: 56),
            sourceAppName: "Sample App",
            createdAt: createdAt,
            windowFrame: ScreenRect(x: 140, y: 64, width: 1000, height: 660)
        )
    }

    /// Paper の App 03 の 2 件。
    static let twoAnnotations = [
        annotation("Padding differs left and right", path: "/nonexistent/01.png"),
        annotation("Change this label to “Save”", path: "/nonexistent/02.png", rect: ScreenRect(x: 380, y: 292, width: 560, height: 72)),
    ]
}

/// キー入力のイベントを作る。
@MainActor func keyEvent(_ keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
    )!
}
