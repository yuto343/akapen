import AppKit
import ImageIO
import XCTest

// 検証のヘルパー。UI に依存しない 3 つの検証点（e2e/README.md「検証点」）を確かめる。
//
// - クリップボードに入った文章: `copiedPrompt()`（定型文と「パス・コメント」の組に分ける）、`putOnPasteboard(_:)`
// - 保存された画像: `savedImage(at:)`（有無・画素の大きさ・赤い画素の外接矩形）、`imageFiles()`、`assertImage(at:showsFrame:)`
// - アプリの状態: `appState()`（`state.json` を型のある値で）、`waitForPhase(_:)`、`waitForCapturedDraft()`、`waitForState(_:_:)`、`waitForAppToQuit()`

/// akapen が書き出す `state.json`（v3）。形は `docs/FOUNDATION.md`「state.json v3」。
struct AppState: Decodable {
    /// 状態。spec の言葉との対応は e2e/README.md「spec の言葉とアプリの状態」。
    enum Phase: String, Decodable {
        /// 何も出ていない状態。
        case hidden
        /// 枠を描く状態（ボタン類が出ていて、画面全体を覆う面がマウスを受けている）。
        case drawing
        /// コメントを書いている状態。
        case commenting
        /// 一覧を開いている状態。
        case listOpen
        /// コピーを終えた状態（コピー完了の表示が出ている）。
        case copied
    }

    /// 画面全体を通した、左上が原点の矩形（pt）。
    struct Rect: Decodable, Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }

    /// 確定済みの注釈。
    struct Annotation: Decodable, Equatable {
        var id: String
        /// 画像ファイルの絶対パス。
        var imagePath: String
        /// コメント。
        var comment: String
        /// 描いた枠。
        var rect: Rect
        /// 枠内に見えていたウィンドウのアプリ名（見えている面積の大きい順に `, ` でつなぐ。なければ空文字）。
        var sourceAppName: String
        /// 撮影した時刻（ISO 8601）。
        var createdAt: String
        /// 撮った範囲（画像全体に当たる矩形。名前はウィンドウ 1 つを撮っていたころのまま）。
        var windowFrame: Rect
    }

    /// 書きかけの注釈。枠を描き終えた時点でできる。画像のパス・アプリ名・撮った範囲は、撮影と保存が終わるまで nil。
    struct Draft: Decodable, Equatable {
        var id: String
        /// 描いた枠。
        var rect: Rect
        /// 枠を描き終えた時刻（ISO 8601）。
        var createdAt: String
        /// 画像ファイルの絶対パス。撮影と保存が終わるまで nil。
        var imagePath: String?
        /// 枠内に見えていたウィンドウのアプリ名。撮影と保存が終わるまで nil。
        var sourceAppName: String?
        /// 撮った範囲。撮影と保存が終わるまで nil。
        var windowFrame: Rect?

        /// 撮影と保存が終わっていれば、その書きかけ。
        var captured: CapturedDraft? {
            guard let imagePath, let sourceAppName, let windowFrame else {
                return nil
            }
            return CapturedDraft(
                id: id,
                rect: rect,
                createdAt: createdAt,
                imagePath: imagePath,
                sourceAppName: sourceAppName,
                windowFrame: windowFrame
            )
        }
    }

    /// 撮影と保存が終わった書きかけの注釈（画像のパス・アプリ名・撮った範囲がある）。
    struct CapturedDraft: Equatable {
        var id: String
        /// 描いた枠。
        var rect: Rect
        /// 枠を描き終えた時刻（ISO 8601）。
        var createdAt: String
        /// 画像ファイルの絶対パス。
        var imagePath: String
        /// 枠内に見えていたウィンドウのアプリ名。
        var sourceAppName: String
        /// 撮った範囲。
        var windowFrame: Rect
    }

    /// 設定。
    struct Settings: Decodable {
        var language: AppLanguage
        var hotkey: Shortcut
        var confirmKey: ConfirmKeySetting
        /// 言語ごとの定型文（書き換えていない言語は既定文）。キーは `en` / `ja`。
        var boilerplates: [String: String]
        var imageRetentionDays: Int
        /// セットアップ済みか。
        var setupCompleted: Bool

        /// 言語の定型文。
        func boilerplate(_ language: AppLanguage) -> String? {
            boilerplates[language.rawValue]
        }
    }

    /// 画像の置き場と、いまの回。
    struct Storage: Decodable {
        /// 画像の置き場の根。
        var imagesDirectory: String
        /// いまの回の ID（`yyyyMMdd-HHmm`）。まだ回を始めていなければ nil。
        var sessionID: String?
        /// この回のフォルダ。まだ回を始めていなければ nil。
        var sessionDirectory: String?
    }

    /// 出ている画面。
    struct Windows: Decodable {
        /// セットアップのページ。
        enum SetupPage: String, Decodable {
            case hotkey
            case permission
        }

        var settings: Bool
        var setup: Bool
        var setupPage: SetupPage?
        var quitConfirm: Bool
    }

    /// 実際に登録しているグローバルなホットキー。
    struct Hotkeys: Decodable {
        var draw: Shortcut?
        /// キーの記録欄が記録を待っているあいだは true（登録を外している）。
        var suspended: Bool
        /// 直前の登録に失敗した役（`draw`）。
        var failed: [String]
    }

    var schemaVersion: Int
    var phase: Phase
    /// ボタン類が出ているか。
    var isToolbarVisible: Bool
    /// 確定済みの注釈（確定した順）。書きかけは含まない。
    var annotations: [Annotation]
    /// 書きかけの注釈（コメントが未確定）。撮影と保存が終わるまでは、画像のパスがない。
    var draft: Draft?
    /// 最後に描いた枠。
    var lastDrawnRect: Rect?
    /// 直前にコピーした件数。
    var lastCopiedCount: Int
    /// 直前の操作の失敗（`captureFailed` / `imageSaveFailed` / `pasteboardFailed` / `settingsSaveFailed`）。
    var lastFailure: String?
    var settings: Settings
    var storage: Storage
    var windows: Windows
    var hotkeys: Hotkeys

    /// 撮影と保存が終わった書きかけの注釈。書きかけがないか、撮影がまだ終わっていなければ nil。
    var capturedDraft: CapturedDraft? {
        draft?.captured
    }

    /// 確定済みの注釈のコメント（確定した順）。
    var comments: [String] {
        annotations.map(\.comment)
    }

    /// 確定済みの注釈の画像のパス（確定した順）。
    var imagePaths: [String] {
        annotations.map(\.imagePath)
    }

    /// コピーを終えた状態か（コピー完了の表示が出ているか、それが消えたあとの何も出ていない状態）。
    var isCopyFinished: Bool {
        (phase == .copied || phase == .hidden) && annotations.isEmpty && !isToolbarVisible
    }

    /// `state.json` を読めなかったときに返す、中身のない状態（テストはその時点で落ちている）。
    static let unreadable: AppState = {
        let json = """
            {"schemaVersion": 0, "phase": "hidden", "isToolbarVisible": false, "annotations": [], "draft": null,
             "lastDrawnRect": null, "lastCopiedCount": 0, "lastFailure": null,
             "settings": {"language": "en", "hotkey": {"keyCode": 41, "modifiers": 1},
                          "confirmKey": "enter", "boilerplates": {}, "imageRetentionDays": 0, "setupCompleted": false},
             "storage": {"imagesDirectory": "", "sessionID": null, "sessionDirectory": null},
             "windows": {"settings": false, "setup": false, "setupPage": null, "quitConfirm": false},
             "hotkeys": {"draw": null, "suspended": false, "failed": []}}
            """
        // 決まった文なので必ず読める。
        return try! JSONDecoder().decode(AppState.self, from: Data(json.utf8))
    }()
}

/// クリップボードに入った文章を、定型文と「パス → コメント」の組に分けたもの。
struct CopiedPrompt: Equatable {
    /// 「パス → コメント」の 1 組。
    struct Entry: Equatable {
        var path: String
        var comment: String
    }

    /// クリップボードの文章そのもの。
    var text: String
    /// 冒頭の定型文。なければ nil。
    var boilerplate: String?
    /// 「パス → コメント」の組（並んでいる順）。
    var entries: [Entry]

    /// 文章を分ける。パスの行は、空行のあと（または先頭）にある、`imagesDirectory` の下を指す `.png` の絶対パスの行。
    /// 組と組の間の空行は 1 行。コメントの中の改行はそのまま残す。
    init(text: String, imagesDirectory: String) {
        self.text = text
        let lines = text.components(separatedBy: "\n")
        let root = imagesDirectory.hasSuffix("/") ? imagesDirectory : imagesDirectory + "/"
        let starts = lines.indices.filter { index in
            let line = lines[index]
            let afterBlank = index == 0 || lines[index - 1].isEmpty
            return afterBlank && line.hasPrefix(root) && line.hasSuffix(".png")
        }
        guard let first = starts.first else {
            boilerplate = text.isEmpty ? nil : text
            entries = []
            return
        }
        boilerplate = first == 0 ? nil : lines[0..<max(0, first - 1)].joined(separator: "\n")
        var entries: [Entry] = []
        for (position, start) in starts.enumerated() {
            let end = position + 1 < starts.count ? starts[position + 1] - 1 : lines.count
            let comment = lines[(start + 1)..<max(start + 1, end)].joined(separator: "\n")
            entries.append(Entry(path: lines[start], comment: comment))
        }
        self.entries = entries
    }

    /// DESIGN.md の形の文章を組み立てる（定型文、空行、「パス（改行）コメント」を空行で区切って並べる。末尾に改行なし）。
    static func expectedText(boilerplate: String?, entries: [Entry]) -> String {
        let blocks = entries.map { $0.path + "\n" + $0.comment }
        let head = boilerplate.map { [$0] } ?? []
        return (head + blocks).joined(separator: "\n\n")
    }
}

/// 定型文の既定値（`AkapenCore/Prompt/Boilerplate.swift` と同じ文）。
enum DefaultBoilerplate {
    static let english = """
        I annotated the screen. Please address the comments below.
        Open every image and check the area marked with the red frame before you start.
        """

    static let japanese = """
        画面に注釈を付けました。以下のコメントに対応してください。
        作業前にすべての画像を開き、赤枠の箇所を確認してください。
        """

    /// 言語の既定文。
    static func text(_ language: AppLanguage) -> String {
        switch language {
        case .en:
            english
        case .ja:
            japanese
        }
    }
}

/// 保存された画像。
struct SavedImage {
    /// 赤枠の太さ（画面上の pt）と、その下限（px）。`AkapenCore/Capture/FrameRenderer.swift` と同じ値。
    static let strokeWidthInPoints: CGFloat = 3
    static let minimumStrokeWidthInPixels: CGFloat = 3

    let url: URL
    let pixelWidth: Int
    let pixelHeight: Int
    /// 赤い画素（赤枠の `#FF3E3E` に近い画素）の外接矩形（px、画像の左上が原点）。赤い画素がなければ nil。
    let redBounds: CGRect?

    /// 縦横の比（幅 ÷ 高さ）。
    var aspectRatio: CGFloat {
        CGFloat(pixelWidth) / CGFloat(max(1, pixelHeight))
    }

    /// 赤い画素の外接矩形を、撮った範囲に対する pt の矩形にする（`windowSize` は撮った範囲の大きさ。pt）。
    func redFrame(inWindowOfSize windowSize: CGSize) -> CGRect? {
        guard let redBounds, windowSize.width > 0 else {
            return nil
        }
        let scale = CGFloat(pixelWidth) / windowSize.width
        return CGRect(
            x: redBounds.minX / scale,
            y: redBounds.minY / scale,
            width: redBounds.width / scale,
            height: redBounds.height / scale
        )
    }

    /// 描いた枠 `drawn`（画面全体の座標）から見込む、赤い画素の外接矩形（撮った範囲 `window` に対する pt）。
    /// 赤枠は枠の外側に描かれるので、線の太さの分だけ広い。
    func expectedRedFrame(drawn: CGRect, window: CGRect) -> CGRect {
        let pixelsPerPoint = CGFloat(pixelWidth) / max(1, window.width)
        let stroke = max(Self.minimumStrokeWidthInPixels, (Self.strokeWidthInPoints * pixelsPerPoint).rounded()) / pixelsPerPoint
        let clipped = drawn.intersection(window)
        return CGRect(
            x: clipped.minX - window.minX,
            y: clipped.minY - window.minY,
            width: clipped.width,
            height: clipped.height
        ).insetBy(dx: -stroke, dy: -stroke).intersection(CGRect(origin: .zero, size: window.size))
    }
}

extension AkapenUITestCase {
    // MARK: - アプリの状態

    /// `state.json` を読む。読めなければテストを落とす。
    @discardableResult
    func appState(file: StaticString = #filePath, line: UInt = #line) -> AppState {
        do {
            return try readAppState()
        } catch {
            XCTFail("state.json を読めない: \(error)", file: file, line: line)
            return AppState.unreadable
        }
    }

    /// 状態が `condition` を満たすまで待ち、満たした状態を返す。待ちきれなければ、最後の `state.json` を添えてテストを落とす。
    @discardableResult
    func waitForState(
        _ description: String,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping (AppState) -> Bool
    ) -> AppState {
        var matched: AppState?
        let found = poll(timeout: timeout) {
            guard let state = try? readAppState(), condition(state) else {
                return false
            }
            matched = state
            return true
        }
        if found, let matched {
            return matched
        }
        let last = (try? String(contentsOf: stateDirectory.appending(path: "state.json"), encoding: .utf8)) ?? "state.json なし"
        XCTFail("状態が変わらない（\(description)）。最後の state.json:\n\(last)", file: file, line: line)
        return appState(file: file, line: line)
    }

    /// `phase` が `phase` になるまで待ち、その状態を返す。
    @discardableResult
    func waitForPhase(
        _ phase: AppState.Phase,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> AppState {
        waitForState("phase が \(phase.rawValue) になる", timeout: timeout, file: file, line: line) { $0.phase == phase }
    }

    /// コメントを書いている状態で、書きかけの注釈の撮影と保存が終わる（`capturedDraft` が入る）まで待ち、その状態を返す。
    ///
    /// 入力欄は撮影の完了を待たずに出るので、書きかけの画像のパスや保存された画像を見るときは、これで待つ。
    @discardableResult
    func waitForCapturedDraft(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) -> AppState {
        waitForState("書きかけの注釈の撮影と保存が終わる", timeout: timeout, file: file, line: line) { state in
            state.phase == .commenting && state.capturedDraft != nil
        }
    }

    /// コピーを終えた状態（コピー完了の表示が出ているか、それが消えたあと）になるまで待つ。
    @discardableResult
    func waitForCopyFinished(timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line) -> AppState {
        waitForState("コピーを終える", timeout: timeout, file: file, line: line) { $0.isCopyFinished }
    }

    /// 状態が `duration` 秒のあいだ `condition` を満たし続けることを確かめる（「〜しても変わらない」を確かめるとき）。
    /// 途中で満たさなくなったらテストを落とす。最後の状態を返す。
    @discardableResult
    func assertStateStays(
        _ description: String,
        for duration: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping (AppState) -> Bool
    ) -> AppState {
        let changed = poll(timeout: duration) {
            guard let state = try? readAppState() else {
                return false
            }
            return !condition(state)
        }
        let state = appState(file: file, line: line)
        XCTAssertFalse(changed, "状態が変わってしまった（\(description)）", file: file, line: line)
        XCTAssertTrue(condition(state), "状態が変わってしまった（\(description)）", file: file, line: line)
        return state
    }

    /// akapen のプロセスが動いているか。
    var isAppRunning: Bool {
        app.state != .notRunning
    }

    /// akapen のプロセスが終了するまで待つ。終了しなければテストを落とす。
    func waitForAppToQuit(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.wait(for: .notRunning, timeout: timeout), "akapen が終了しない", file: file, line: line)
    }

    private func readAppState() throws -> AppState {
        let data = try Data(contentsOf: stateDirectory.appending(path: "state.json"))
        return try JSONDecoder().decode(AppState.self, from: data)
    }

    // MARK: - 表示の言語

    /// akapen の要素に出ている文（読み上げ用の値か、なければラベル）。言語が変わったかを確かめるのに使う。文言で要素を探さない。
    func displayedText(_ identifier: String) -> String {
        let found = waitForElement(identifier)
        if let value = found.value as? String, !value.isEmpty {
            return value
        }
        return found.label
    }

    /// 日本語の文字（ひらがな・カタカナ・漢字）を含むか。表示が日本語に切り替わったかを確かめるのに使う。
    func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    // MARK: - クリップボード

    /// テスト用のクリップボードの文章。空なら nil。
    func pasteboardText() -> String? {
        guard let pasteboardName else {
            return nil
        }
        return NSPasteboard(name: NSPasteboard.Name(pasteboardName)).string(forType: .string)
    }

    /// テスト用のクリップボードに、前もって別の文章を入れておく。
    func putOnPasteboard(_ text: String) {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(pasteboardName))
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// テスト用のクリップボードの文章を、定型文と「パス → コメント」の組に分けて返す。空なら nil。
    func copiedPrompt() -> CopiedPrompt? {
        pasteboardText().map { CopiedPrompt(text: $0, imagesDirectory: imagesDirectory.path(percentEncoded: false)) }
    }

    // MARK: - 保存された画像

    /// 画像を読む。ファイルがない・画像として読めないときは nil。
    func savedImage(at path: String) -> SavedImage? {
        let url = URL(filePath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return SavedImage(url: url, pixelWidth: image.width, pixelHeight: image.height, redBounds: Self.redBounds(of: image))
    }

    /// ファイルがあるか。
    func fileExists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// ファイルの中身（ないときは nil）。上書きされていないことを、前後の中身を比べて確かめるのに使う。
    func fileContents(_ path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    /// 画像の置き場にある PNG のパス（回のフォルダの下も含む。パスの順）。
    /// パスは、akapen に渡した置き場のパスにファイル名をつないだ形（state.json やクリップボードのパスと、そのまま比べられる）。
    func imageFiles() -> [String] {
        let root = imagesDirectory.path(percentEncoded: false)
        guard let names = FileManager.default.subpaths(atPath: root) else {
            return []
        }
        let base = root.hasSuffix("/") ? root : root + "/"
        return names
            .filter { $0.hasSuffix(".png") }
            .map { base + $0 }
            .sorted()
    }

    /// 画像の置き場の、いまの回のフォルダにある PNG のパス（いまの回が始まっていなければ空）。
    func imageFilesInCurrentSession() -> [String] {
        guard let folder = appState().storage.sessionDirectory else {
            return []
        }
        return imageFiles().filter { $0.hasPrefix(folder) }
    }

    /// 画像の置き場の、回のフォルダの名前（名前の順）。
    func sessionFolders() -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path(percentEncoded: false))) ?? []
        return names.filter { !$0.hasPrefix(".") }.sorted()
    }

    /// 画像が `drawn`（描いた枠。画面全体の座標）に当たる位置に赤枠が入った、撮った範囲全体の画像であることを確かめる。
    ///
    /// - ファイルがあり、画像として読める。
    /// - 縦横の比が、撮った範囲（`window`。既定は SampleTarget のウィンドウ。枠がその内側だけにあるときの範囲）と同じ（誤差 1%）。
    /// - 赤い画素の外接矩形が、描いた枠を線の太さの分だけ広げた矩形と、辺ごとに `tolerance` pt 以内で一致する。
    func assertImage(
        at path: String,
        showsFrame drawn: CGRect,
        window: CGRect = AkapenUITestCase.sampleFrame,
        tolerance: CGFloat = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let image = savedImage(at: path) else {
            XCTFail("画像がない、または読めない: \(path)", file: file, line: line)
            return
        }
        let windowRatio = window.width / window.height
        XCTAssertEqual(image.aspectRatio, windowRatio, accuracy: windowRatio * 0.01, "縦横の比がウィンドウと違う", file: file, line: line)
        guard let actual = image.redFrame(inWindowOfSize: window.size) else {
            XCTFail("赤枠が入っていない: \(path)", file: file, line: line)
            return
        }
        let expected = image.expectedRedFrame(drawn: drawn, window: window)
        XCTAssertEqual(actual.minX, expected.minX, accuracy: tolerance, "赤枠の左端がずれている", file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: tolerance, "赤枠の上端がずれている", file: file, line: line)
        XCTAssertEqual(actual.maxX, expected.maxX, accuracy: tolerance, "赤枠の右端がずれている", file: file, line: line)
        XCTAssertEqual(actual.maxY, expected.maxY, accuracy: tolerance, "赤枠の下端がずれている", file: file, line: line)
    }

    /// 2 つの矩形（画面全体の座標）が、辺ごとに `tolerance` pt 以内で一致することを確かめる。
    func assertRect(
        _ actual: CGRect?,
        matches expected: CGRect,
        tolerance: CGFloat = 4,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("矩形がない", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.minX, expected.minX, accuracy: tolerance, "左端がずれている", file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: tolerance, "上端がずれている", file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: tolerance, "幅がずれている", file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: tolerance, "高さがずれている", file: file, line: line)
    }

    /// 赤い画素の外接矩形（px、左上が原点）。
    private static func redBounds(of image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: buffer.baseAddress,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            return nil
        }
        var minX = Int.max
        var minY = Int.max
        var maxX = Int.min
        var maxY = Int.min
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard pixels[offset] >= 200, pixels[offset + 1] <= 110, pixels[offset + 2] <= 110 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard minX <= maxX else {
            return nil
        }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
