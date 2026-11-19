import AppKit
import SwiftUI
import Testing
import AkapenCore
@testable import AkapenUI

/// 部品を、いくつかの状態で `build/ui-snapshots/<言語>/` に PNG として書き出す。
///
/// 書き出した PNG は、Paper の画像（`.director/design/img/`）と人が見比べる。画素の一致は確かめない。
/// Paper と同じ 1280×800 の画面に並べたもの（`scene-app-0N.png`）と、Paper の画像と横に並べたもの（`compare/`）も書き出す。
@Suite(.serialized)
@MainActor
struct SnapshotTests {
    nonisolated static let languages: [Language] = [.en, .ja]

    private func comments(_ language: Language) -> (first: String, second: String) {
        switch language {
        case .en:
            ("Padding differs left and right", "Change this label to “Save”")
        case .ja:
            ("ボタンの余白が左右で違う", "ここの文言を「保存する」に")
        }
    }

    private func annotations(_ language: Language, count: Int = 2) -> [Annotation] {
        let texts = comments(language)
        let base = [
            Fixtures.annotation(texts.first, path: "/snapshot/01.png", rect: ScreenRect(x: 910, y: 468, width: 204, height: 56)),
            Fixtures.annotation(texts.second, path: "/snapshot/02.png", rect: ScreenRect(x: 380, y: 292, width: 560, height: 72)),
        ]
        return (0..<count).map { index in
            var annotation = base[index % base.count]
            annotation.id = UUID()
            annotation.imagePath = "/snapshot/\(index).png"
            return annotation
        }
    }

    private func thumbnails(for annotations: [Annotation]) -> StubThumbnails {
        let stub = StubThumbnails()
        for annotation in annotations {
            stub.images[annotation.imagePath] = SnapshotImages.thumbnail(for: annotation)
        }
        return stub
    }

    /// 影が見えるように、部品のまわりに余白と背景を付ける。
    private func framed<V: View>(_ view: V) -> some View {
        view
            .padding(Tokens.Spacing.s16)
            .background(Color(red: 0.90, green: 0.91, blue: 0.93))
    }

    private func toolbar(_ count: Int, listOpen: Bool, _ strings: UIStrings) -> ToolbarView {
        ToolbarView(
            state: ToolbarState(annotationCount: count, isListOpen: listOpen),
            strings: strings,
            onList: {},
            onCopy: {}
        )
    }

    private func commentEditor(text: String) -> GrowingTextController {
        let editor = CommentView.makeEditor()
        editor.setPlaceholder(UIStrings(language: .en)[.commentPlaceholder])
        editor.setText(text)
        return editor
    }

    private func listView(
        _ annotations: [Annotation],
        editing: ListEditingController = ListEditingController(),
        confirmKey: ConfirmKey = .enter,
        _ strings: UIStrings
    ) -> ListView {
        ListView(
            annotations: annotations,
            retentionDays: 7,
            confirmKey: confirmKey,
            strings: strings,
            timeZone: Fixtures.timeZone,
            editing: editing,
            thumbnails: thumbnails(for: annotations),
            onDelete: { _ in }
        )
    }

    @Test(arguments: languages)
    func toolbarStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        try Snapshot.write(try await Snapshot.render(framed(toolbar(0, listOpen: false, strings))), to: "\(folder)/toolbar-0.png")
        try Snapshot.write(try await Snapshot.render(framed(toolbar(2, listOpen: false, strings))), to: "\(folder)/toolbar-2.png")
        try Snapshot.write(try await Snapshot.render(framed(toolbar(2, listOpen: true, strings))), to: "\(folder)/toolbar-list-open.png")
    }

    @Test(arguments: languages)
    func clearConfirmation(language: Language) async throws {
        let view = ConfirmationView(annotationCount: 2, purpose: .clear, strings: UIStrings(language: language), onQuit: {}, onCancel: {})
        try Snapshot.write(try await Snapshot.render(framed(view)), to: "\(language.rawValue)/clear-confirm.png")
    }

    @Test(arguments: languages)
    func drawStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        try Snapshot.write(try await Snapshot.render(framed(DrawHintView(strings: strings))), to: "\(folder)/draw-hint.png")
        let screen = ScreenInfo(
            id: 1,
            frame: ScreenRect(x: 0, y: 0, width: 480, height: 200),
            visibleFrame: ScreenRect(x: 0, y: 0, width: 480, height: 200)
        )
        let overlay = OverlayState(
            screen: screen,
            showsHint: false,
            frame: ScreenRect(x: 60, y: 40, width: 332, height: 88),
            cursor: CGPoint(x: 392, y: 128)
        )
        let view = OverlayView(state: overlay, strings: strings, animated: false)
            .background(Color(red: 0.90, green: 0.91, blue: 0.93))
        try Snapshot.write(try await Snapshot.render(view), to: "\(folder)/draw-frame-size.png")
    }

    @Test(arguments: languages)
    func commentStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        let empty = commentEditor(text: "")
        empty.setPlaceholder(strings[.commentPlaceholder])
        try Snapshot.write(
            try await Snapshot.render(framed(CommentView(editor: empty, confirmKey: .enter, strings: strings))),
            to: "\(folder)/comment-empty.png"
        )
        let filled = commentEditor(text: comments(language).first)
        try Snapshot.write(
            try await Snapshot.render(framed(CommentView(editor: filled, confirmKey: .enter, strings: strings))),
            to: "\(folder)/comment-text.png"
        )
        let command = commentEditor(text: comments(language).first)
        try Snapshot.write(
            try await Snapshot.render(framed(CommentView(editor: command, confirmKey: .commandEnter, strings: strings))),
            to: "\(folder)/comment-command-enter.png"
        )
        let long = commentEditor(text: (1...7).map { "\(comments(language).first) \($0)" }.joined(separator: "\n"))
        try Snapshot.write(
            try await Snapshot.render(framed(CommentView(editor: long, confirmKey: .enter, strings: strings))),
            to: "\(folder)/comment-five-lines.png"
        )
    }

    @Test(arguments: languages)
    func listStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        try Snapshot.write(try await Snapshot.render(framed(listView([], strings))), to: "\(folder)/list-0.png")
        let two = annotations(language)
        try Snapshot.write(try await Snapshot.render(framed(listView(two, strings))), to: "\(folder)/list-2.png")
        let editing = ListEditingController()
        editing.begin(two[1], index: 1)
        try Snapshot.write(try await Snapshot.render(framed(listView(two, editing: editing, strings))), to: "\(folder)/list-editing.png")
        let one = annotations(language, count: 1)
        try Snapshot.write(try await Snapshot.render(framed(listView(one, strings))), to: "\(folder)/list-1.png")
        let six = annotations(language, count: 6)
        try Snapshot.write(try await Snapshot.render(framed(listView(six, strings))), to: "\(folder)/list-6-scroll.png")
    }

    @Test(arguments: languages)
    func copiedStates(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        try Snapshot.write(try await Snapshot.render(framed(CopiedView(count: 2, strings: strings))), to: "\(folder)/copied.png")
    }

    /// コピー完了の表示の動きの途中のコマを、時刻の順に横に並べて書き出す（左から右へ）。
    @Test
    func copiedMotionFrames() async throws {
        let strings = UIStrings(language: .en)
        let entering: [Double] = [0, 0.04, 0.08, 0.12, 0.16, 0.2, 0.26, 0.34, 0.45, 0.7]
        let leaving: [Double] = [0, 0.05, 0.1, 0.15, 0.2]
        try Snapshot.write(
            try await Snapshot.render(motionStrip(entering.map(ToastTimeline.entering(at:)), times: entering, strings: strings)),
            to: "motion/copied-in.png"
        )
        try Snapshot.write(
            try await Snapshot.render(motionStrip(leaving.map(ToastTimeline.leaving(at:)), times: leaving, strings: strings)),
            to: "motion/copied-out.png"
        )
    }

    private func motionStrip(_ frames: [ToastAppearance], times: [Double], strings: UIStrings) -> some View {
        HStack(spacing: Tokens.Spacing.s3) {
            ForEach(Array(frames.enumerated()), id: \.offset) { index, frame in
                VStack(spacing: Tokens.Spacing.s2) {
                    CopiedView(count: 2, strings: strings, frozen: frame)
                        .frame(width: 200, height: 60)
                    Text(String(format: "%.2fs", times[index]))
                        .font(.system(size: 11, design: .monospaced))
                }
            }
        }
        .padding(Tokens.Spacing.s6)
        .background(Color(red: 0.90, green: 0.91, blue: 0.93))
    }

    /// Paper の App 01〜04 と同じ配置の画面。
    @Test(arguments: languages)
    func scenes(language: Language) async throws {
        let strings = UIStrings(language: language)
        let folder = language.rawValue
        let screen = FakeScreens.primary
        let two = annotations(language)
        // 一覧はボタン類の上に置く。ボタン類の高さは 48（幅は左右中央に置くので結果に効かない）。
        let toolbarFrame = PanelPlacement.bottomCenter(
            size: CGSize(width: 0, height: Tokens.Toolbar.controlHeight + Tokens.Toolbar.padding * 2),
            visibleFrame: screen.visibleFrame
        )

        let draw = SceneLayout(screen: screen) {
            SceneBackdrop()
            OverlayView(
                state: OverlayState(
                    screen: screen,
                    showsHint: true,
                    frame: ScreenRect(x: 370, y: 284, width: 332, height: 88),
                    cursor: CGPoint(x: 702, y: 372)
                ),
                strings: strings,
                animated: false
            )
            toolbar(2, listOpen: false, strings)
                .layoutValue(key: ScenePlacement.self, value: .bottomCenter)
        }
        let drawRep = try await Snapshot.render(draw)
        try Snapshot.write(drawRep, to: "\(folder)/scene-app-01.png")

        let frame = ScreenRect(x: 910, y: 468, width: 204, height: 56)
        let commentScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            OverlayView(state: OverlayState(screen: screen, showsHint: false, frame: frame), strings: strings, animated: false)
            CommentView(editor: commentEditor(text: comments(language).first), confirmKey: .enter, strings: strings)
                .layoutValue(key: ScenePlacement.self, value: .comment(frame: frame))
            toolbar(2, listOpen: false, strings)
                .layoutValue(key: ScenePlacement.self, value: .bottomCenter)
        }
        let commentRep = try await Snapshot.render(commentScene)
        try Snapshot.write(commentRep, to: "\(folder)/scene-app-02.png")

        let editing = ListEditingController()
        editing.begin(two[1], index: 1)
        let listScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            listView(two, editing: editing, strings)
                .layoutValue(key: ScenePlacement.self, value: .list(toolbar: toolbarFrame))
            toolbar(2, listOpen: true, strings)
                .layoutValue(key: ScenePlacement.self, value: .bottomCenter)
        }
        let listRep = try await Snapshot.render(listScene)
        try Snapshot.write(listRep, to: "\(folder)/scene-app-03.png")

        let copiedScene = SceneLayout(screen: screen) {
            SceneBackdrop()
            CopiedView(count: 2, strings: strings)
                .layoutValue(key: ScenePlacement.self, value: .bottomCenter)
        }
        let copiedRep = try await Snapshot.render(copiedScene)
        try Snapshot.write(copiedRep, to: "\(folder)/scene-app-04.png")

        if language == .en {
            try Snapshot.writeComparison(paper: "app-01.png", ours: drawRep, to: "compare/app-01.png")
            try Snapshot.writeComparison(paper: "app-02.png", ours: commentRep, to: "compare/app-02.png")
            try Snapshot.writeComparison(paper: "app-03.png", ours: listRep, to: "compare/app-03.png")
            try Snapshot.writeComparison(paper: "app-04.png", ours: copiedRep, to: "compare/app-04.png")
        }
    }
}
