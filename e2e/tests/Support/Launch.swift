import XCTest
import AkapenAXID

// 前提の指定と、akapen の起動。
//
// 前提は UI 操作で作らず、起動時の環境変数（`AKAPEN_*`）で作る。`AKAPEN_SEED` の JSON の形は
// `Packages/AkapenKit/Sources/AkapenApp/LaunchSeed.swift` と `docs/FOUNDATION.md` にある。ここでは型のある値で指定する。
//
// 例:
//   launch(.setupDone)                                            // セットアップ済み・注釈 0 件・何も出ていない
//   launch(.firstRun)                                             // セットアップがまだ（セットアップのウィンドウが出る）
//   launch(.setupDone, settings: LaunchSettings(language: .ja))   // 設定の一部を指定する
//   launch(.setupDone, annotations: SeedAnnotation.samples(2))    // 確定済みの注釈 2 件。ボタン類だけが出ている
//   launch(.setupDone, open: .toolbar)                            // 注釈 0 件で、ボタン類だけが出ている
//   launch(.setupDone, annotations: SeedAnnotation.samples(2), open: .list)  // 一覧を開いている
//   launch(.setupDone, screenRecording: .denied)                  // 画面収録の許可なし
//   placeOldSession(daysBeforeNow: 5)                             // 置き場に古い回を置いてから
//   launch(.setupDone)                                            // 起動する（起動時の掃除の前提）
//   relaunch()                                                    // 同じ置き場のまま、もう一度起動する

/// セットアップを終えているか。
enum LaunchState {
    /// セットアップ済み（`settings.setupCompleted` が true）。セットアップのウィンドウは出ない。
    case setupDone
    /// 初回の起動（`settings.setupCompleted` が false）。セットアップのウィンドウが出る。
    case firstRun
}

/// 起動後に出しておくもの（省くと、注釈が 0 件なら何も出ていない状態、注釈があればボタン類だけが出ている状態）。
enum OpenView: String {
    /// ボタン類だけが出ている状態（注釈が 0 件でも）。
    case toolbar
    /// 一覧を開いている状態。
    case list
}

/// 画面収録の許可。偽の撮影（`make e2e`）のときだけ効く。`denied` だと撮影が失敗する。
enum ScreenRecording: String {
    case granted
    case denied
}

/// アプリの言語（`settings.language`）。
enum AppLanguage: String, Codable, CaseIterable {
    case en
    case ja
}

/// コメントの確定キー（`settings.confirmKey`）。
enum ConfirmKeySetting: String, Codable {
    /// `Enter` で確定、`Shift+Enter` で改行（既定）。
    case enter
    /// `⌘Enter` で確定、`Enter` で改行。
    case commandEnter
}

/// キーの組み合わせ（`settings.hotkey` などと同じ形。キーコードは Carbon の仮想キーコード）。
struct Shortcut: Codable, Equatable, CustomStringConvertible {
    /// 修飾キーのビット（akapen の `KeyModifiers` と同じ）。
    struct Modifiers: OptionSet, Codable, Equatable {
        let rawValue: UInt32

        static let command = Modifiers(rawValue: 1)
        static let shift = Modifiers(rawValue: 2)
        static let option = Modifiers(rawValue: 4)
        static let control = Modifiers(rawValue: 8)
    }

    var keyCode: UInt32
    var modifiers: Modifiers

    /// 既定のホットキー `⌘;`。
    static let commandSemicolon = Shortcut(key: ";", modifiers: .command)

    /// キーコードと修飾キーから作る。
    init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// キーの文字（`a`〜`z`、`0`〜`9`、`;` など US 配列の記号）と修飾キーから作る。表にない文字はテストを落とす。
    init(key: String, modifiers: Modifiers) {
        guard let code = Self.keyCodes[key.lowercased()] else {
            XCTFail("キーコードの表にない文字: \(key)")
            self.init(keyCode: 0, modifiers: modifiers)
            return
        }
        self.init(keyCode: code, modifiers: modifiers)
    }

    /// `typeKey` に渡すキーの文字。
    var key: String {
        Self.keyCodes.first { $0.value == keyCode }?.key ?? ""
    }

    /// `typeKey` に渡す修飾キー。
    var flags: XCUIElement.KeyModifierFlags {
        var flags: XCUIElement.KeyModifierFlags = []
        if modifiers.contains(.command) {
            flags.insert(.command)
        }
        if modifiers.contains(.shift) {
            flags.insert(.shift)
        }
        if modifiers.contains(.option) {
            flags.insert(.option)
        }
        if modifiers.contains(.control) {
            flags.insert(.control)
        }
        return flags
    }

    var description: String {
        "keyCode \(keyCode) modifiers \(modifiers.rawValue) (\(key))"
    }

    /// US 配列の文字と、Carbon の仮想キーコード。
    private static let keyCodes: [String: UInt32] = [
        "a": 0,
        "s": 1,
        "d": 2,
        "f": 3,
        "h": 4,
        "g": 5,
        "z": 6,
        "x": 7,
        "c": 8,
        "v": 9,
        "b": 11,
        "q": 12,
        "w": 13,
        "e": 14,
        "r": 15,
        "y": 16,
        "t": 17,
        "1": 18,
        "2": 19,
        "3": 20,
        "4": 21,
        "6": 22,
        "5": 23,
        "=": 24,
        "9": 25,
        "7": 26,
        "-": 27,
        "8": 28,
        "0": 29,
        "]": 30,
        "o": 31,
        "u": 32,
        "[": 33,
        "i": 34,
        "p": 35,
        "l": 37,
        "j": 38,
        "'": 39,
        "k": 40,
        ";": 41,
        "\\": 42,
        ",": 43,
        "/": 44,
        "n": 45,
        "m": 46,
        ".": 47,
        "`": 50,
    ]
}

/// 起動時に入れる設定の一部。nil の項目は既定値（または、起動し直す前に保存された値）のまま。
struct LaunchSettings {
    var language: AppLanguage?
    var hotkey: Shortcut?
    /// ボタン類の表示を切り替えるキー。`.some(nil)` で未割り当て（既定も未割り当て）。
    var toolbarShortcut: Shortcut??
    var confirmKey: ConfirmKeySetting?
    /// 書き換えておく定型文（言語ごと）。書いていない言語は既定文のまま。
    var boilerplates: [AppLanguage: String]
    /// 画像を残す日数（既定 7。アプリが 1〜365 に丸める）。
    var imageRetentionDays: Int?

    init(
        language: AppLanguage? = nil,
        hotkey: Shortcut? = nil,
        toolbarShortcut: Shortcut?? = nil,
        confirmKey: ConfirmKeySetting? = nil,
        boilerplates: [AppLanguage: String] = [:],
        imageRetentionDays: Int? = nil
    ) {
        self.language = language
        self.hotkey = hotkey
        self.toolbarShortcut = toolbarShortcut
        self.confirmKey = confirmKey
        self.boilerplates = boilerplates
        self.imageRetentionDays = imageRetentionDays
    }

    /// `AKAPEN_SEED` の `settings` の JSON。
    fileprivate func json(setupCompleted: Bool) -> [String: Any] {
        var json: [String: Any] = ["setupCompleted": setupCompleted]
        if let language {
            json["language"] = language.rawValue
        }
        if let hotkey {
            json["hotkey"] = Self.json(hotkey)
        }
        if let toolbarShortcut {
            json["toolbarShortcut"] = toolbarShortcut.map(Self.json) ?? NSNull()
        }
        if let confirmKey {
            json["confirmKey"] = confirmKey.rawValue
        }
        if !boilerplates.isEmpty {
            json["boilerplates"] = Dictionary(uniqueKeysWithValues: boilerplates.map { ($0.key.rawValue, $0.value) })
        }
        if let imageRetentionDays {
            json["imageRetentionDays"] = imageRetentionDays
        }
        return json
    }

    private static func json(_ shortcut: Shortcut) -> [String: Any] {
        ["keyCode": shortcut.keyCode, "modifiers": shortcut.modifiers.rawValue]
    }
}

/// 起動時に作っておく、確定済みの注釈。画像は起動時に偽の撮影から作られ、置き場に保存される。
struct SeedAnnotation {
    /// コメント。
    var comment: String
    /// 描いた枠（画面全体を通した、左上が原点の矩形。pt）。nil なら SampleTarget の要素を囲む枠を順に使う
    /// （1 件目は Submit、2 件目は 1 つ目の入力欄、3 件目は 2 つ目の入力欄、4 件目は 3 つ目の入力欄、5 件目は Cancel）。
    var rect: CGRect?

    init(_ comment: String, rect: CGRect? = nil) {
        self.comment = comment
        self.rect = rect
    }

    /// 1 行の、互いに違うコメントの注釈を `count` 件。
    static func samples(_ count: Int) -> [SeedAnnotation] {
        (0..<count).map { index in
            SeedAnnotation(sampleComments[index % sampleComments.count] + (index < sampleComments.count ? "" : " \(index + 1)"))
        }
    }

    /// `samples(_:)` のコメント。
    static let sampleComments = [
        "The padding differs between left and right",
        "Change this label to Save",
        "This field should be wider",
        "Align this field with the one above",
        "Make this button secondary",
    ]

    /// 枠を省いたときに順に囲む、SampleTarget の要素。
    static let defaultTargets = [
        AXID.Sample.button,
        AXID.Sample.firstField,
        AXID.Sample.secondField,
        AXID.Sample.thirdField,
        AXID.Sample.cancel,
    ]
}

extension AkapenUITestCase {
    /// 前提を選んで akapen を起動し、起動が済むまで（`state.json` が書き出されるまで）待つ。
    ///
    /// 時刻は `fixedNow` に固定する。偽の撮影が返すウィンドウは SampleTarget のウィンドウと同じ位置・大きさ。
    /// `.setupDone` のときは、起動のあと SampleTarget を前面に戻す（ホットキーを押す・下のアプリを操作する前提）。
    /// 起動に失敗したら（`AKAPEN_SEED` の書き間違いなど）、理由を出してテストを落とす。
    ///
    /// - Parameters:
    ///   - state: セットアップを終えているか。
    ///   - settings: 設定の一部（言語・ホットキー・ボタン類の表示を切り替えるキー・確定キー・定型文・日数）。
    ///   - annotations: 確定済みの注釈（確定した順）。画像は起動時に撮って置き場に保存される。
    ///   - open: 起動後に出しておくもの。
    ///   - screenRecording: 画面収録の許可。
    func launch(
        _ state: LaunchState = .setupDone,
        settings: LaunchSettings = LaunchSettings(),
        annotations: [SeedAnnotation] = [],
        open: OpenView? = nil,
        screenRecording: ScreenRecording = .granted
    ) {
        var seed = environmentSeed(screenRecording: screenRecording)
        seed["settings"] = settings.json(setupCompleted: state == .setupDone)
        if !annotations.isEmpty {
            seed["annotations"] = annotations.enumerated().map { index, annotation in
                [
                    "comment": annotation.comment,
                    "rect": Self.json(annotation.rect ?? defaultAnnotationRect(index)),
                ] as [String: Any]
            }
        }
        if let open {
            seed["open"] = open.rawValue
        }
        start(seed: seed)
        if state == .setupDone {
            bringSampleToFront()
        }
    }

    /// 同じ置き場（設定・画像）のまま、akapen を終了してもう一度起動する。設定と注釈は前の起動で保存されたものを使う。
    ///
    /// セットアップのウィンドウが出ないとき（セットアップ済み）は、起動のあと SampleTarget を前面に戻す。
    func relaunch(screenRecording: ScreenRecording = .granted) {
        terminateApp()
        start(seed: environmentSeed(screenRecording: screenRecording))
        if appState().settings.setupCompleted {
            bringSampleToFront()
        }
    }

    /// akapen のプロセスを止める（確認を出さずに）。
    func terminateApp() {
        guard app.state != .notRunning else {
            return
        }
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10), "akapen が終了しない")
    }

    /// 固定した時刻の `days` 日前の回のフォルダを、画像の置き場に作る（起動前に呼ぶ）。中に PNG を `imageCount` 枚置く。
    @discardableResult
    func placeOldSession(daysBeforeNow days: Int, imageCount: Int = 1) -> URL {
        let folder = imagesDirectory.appending(path: sessionFolderName(daysBeforeNow: days), directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for index in 1...max(1, imageCount) {
                let name = String(format: "%02d.png", index)
                try Self.tinyPNG.write(to: folder.appending(path: name))
            }
        } catch {
            XCTFail("古い回のフォルダを作れない: \(error)")
        }
        return folder
    }

    /// 固定した時刻の `days` 日前の回のフォルダ名（`yyyyMMdd-HHmm`。この Mac のタイムゾーン。akapen と同じ決め方）。
    func sessionFolderName(daysBeforeNow days: Int) -> String {
        let date = Self.fixedDate.addingTimeInterval(-Double(days) * 86_400)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return formatter.string(from: date)
    }

    /// SampleTarget を前面に出す。
    func bringSampleToFront() {
        sample.activate()
        XCTAssertTrue(sample.wait(for: .runningForeground, timeout: 5), "SampleTarget が前面に出ない")
    }

    // MARK: - 下請け

    /// 起動のたびに渡す前提（許可と、偽の撮影が返すウィンドウ）。
    private func environmentSeed(screenRecording: ScreenRecording) -> [String: Any] {
        let window = sampleElement(AXID.Sample.window)
        let frame = window.exists ? window.frame : Self.sampleFrame
        return [
            "screenRecording": screenRecording.rawValue,
            "windows": [
                [
                    "frame": Self.json(frame),
                    "appName": Self.sampleAppName,
                    "title": Self.sampleAppName,
                ] as [String: Any],
            ],
        ]
    }

    private func defaultAnnotationRect(_ index: Int) -> CGRect {
        let identifier = SeedAnnotation.defaultTargets[index % SeedAnnotation.defaultTargets.count]
        let target = sampleElement(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "SampleTarget の要素がない: \(identifier)")
        return target.frame.insetBy(dx: -8, dy: -8)
    }

    private func start(seed: [String: Any]) {
        for name in ["state.json", "startup-error.txt"] {
            try? FileManager.default.removeItem(at: stateDirectory.appending(path: name))
        }
        let json: String
        do {
            let data = try JSONSerialization.data(withJSONObject: seed, options: [.sortedKeys])
            json = String(decoding: data, as: UTF8.self)
        } catch {
            XCTFail("AKAPEN_SEED を作れない: \(error)")
            return
        }
        lastSeedJSON = json
        app.launchEnvironment = [
            "AKAPEN_E2E": "1",
            "AKAPEN_STATE_DIR": stateDirectory.path(percentEncoded: false),
            "AKAPEN_PASTEBOARD": pasteboardName,
            "AKAPEN_CAPTURE": ProcessInfo.processInfo.environment["AKAPEN_CAPTURE"] ?? "fixture",
            "AKAPEN_NOW": Self.fixedNow,
            "AKAPEN_SEED": json,
        ]
        app.launch()
        waitUntilReady()
    }

    /// `state.json` が書き出されるまで待つ（akapen は、前提づくりと画面の組み立てを終えてから書き出しを始める）。
    private func waitUntilReady(timeout: TimeInterval = 20) {
        let stateFile = stateDirectory.appending(path: "state.json").path(percentEncoded: false)
        let errorFile = stateDirectory.appending(path: "startup-error.txt")
        let ready = poll(timeout: timeout) {
            FileManager.default.fileExists(atPath: stateFile)
                || FileManager.default.fileExists(atPath: errorFile.path(percentEncoded: false))
        }
        if let error = try? String(contentsOf: errorFile, encoding: .utf8) {
            XCTFail("akapen を起動できなかった: \(error)")
            return
        }
        XCTAssertTrue(ready, "akapen の起動が済まない（state.json が書き出されない）")
    }

    fileprivate static func json(_ rect: CGRect) -> [String: Double] {
        [
            "x": Double(rect.minX),
            "y": Double(rect.minY),
            "width": Double(rect.width),
            "height": Double(rect.height),
        ]
    }

    /// 古い回のフォルダに置く、1×1 の PNG。
    private static let tinyPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==") ?? Data()
}
