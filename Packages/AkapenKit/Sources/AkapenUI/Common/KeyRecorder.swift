import AppKit
import SwiftUI
import AkapenCore

extension KeyCode {
    /// `Delete`（Backspace）。
    static let delete: UInt16 = 51
    /// `Forward Delete`（`fn` + `Delete`）。
    static let forwardDelete: UInt16 = 117
}

/// キーの記録欄の状態（設定とセットアップで共通。`DECISIONS.md` 24・A8）。
///
/// - クリックで記録を待つ状態になり、次のキー入力を記録する。
/// - 修飾キー（⌘ ⌥ ⌃ のどれか）がないキーは記録しない（待ち続ける）。⇧ だけでは足りない（大文字を打てなくなるため）。
/// - `Esc` で取りやめる。未割り当てを許す欄では、修飾キーなしの `Delete` で未割り当てに戻す。
/// - 記録したキーが、もう 1 つの欄で使われているとき（`isTaken`）や、使えないとき（`isAvailable` が false）は、元の値に戻して知らせを出す。
@MainActor @Observable final class KeyRecorderModel {
    /// 記録したキーを受け入れなかった理由。
    enum Problem: Equatable {
        /// 登録できなかった（ほかのアプリとぶつかったなど。`This shortcut is unavailable`）。
        case unavailable
        /// もう 1 つの欄で使っている。
        case inUse
    }

    /// いまの値。nil は未割り当て。
    private(set) var shortcut: AkapenCore.KeyboardShortcut?
    /// 記録を待っているか。
    private(set) var isRecording = false
    /// 直前の記録を受け入れなかった理由。次に記録を始めるか、値が入ると消える。
    private(set) var problem: Problem?
    /// 未割り当てを許すか。
    @ObservationIgnored let allowsNone: Bool
    /// 記録したキーが使えるか（組み立ての側が、実際に登録できるかを確かめて返す）。
    @ObservationIgnored var isAvailable: @MainActor (AkapenCore.KeyboardShortcut) -> Bool = { _ in true }
    /// 記録したキーが、もう 1 つの欄で使われているか。
    @ObservationIgnored var isTaken: @MainActor (AkapenCore.KeyboardShortcut) -> Bool = { _ in false }
    /// 値が変わったとき（記録した・未割り当てに戻した）。外から `load(_:)` で入れたときは呼ばない。
    @ObservationIgnored var onCommit: (@MainActor (AkapenCore.KeyboardShortcut?) -> Void)?
    /// 記録を待ち始めた（true）・待つのをやめた（false）とき。
    @ObservationIgnored var onRecordingChange: (@MainActor (Bool) -> Void)?

    init(shortcut: AkapenCore.KeyboardShortcut?, allowsNone: Bool) {
        self.shortcut = shortcut
        self.allowsNone = allowsNone
    }

    /// 外から値を入れる（ウィンドウを開いたときなど）。記録の途中ならやめ、知らせも消す。
    func load(_ shortcut: AkapenCore.KeyboardShortcut?) {
        cancelRecording()
        self.shortcut = shortcut
        problem = nil
    }

    /// 記録欄が押されたとき。待っていなければ待ち始め、待っていればやめる。
    func toggleRecording() {
        if isRecording {
            cancelRecording()
        } else {
            beginRecording()
        }
    }

    /// 記録を待ち始める。
    func beginRecording() {
        problem = nil
        guard !isRecording else {
            return
        }
        isRecording = true
        onRecordingChange?(true)
    }

    /// 記録をやめ、値は元のままにする。
    func cancelRecording() {
        guard isRecording else {
            return
        }
        endRecording()
    }

    /// キー入力を扱う。記録を待っていて、このキーを扱ったら true（下へ流さない）。
    @discardableResult
    func handle(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard isRecording else {
            return false
        }
        let modifiers = KeyModifiers(eventFlags: flags)
        if keyCode == KeyCode.escape {
            cancelRecording()
            return true
        }
        if modifiers.isEmpty, keyCode == KeyCode.delete || keyCode == KeyCode.forwardDelete {
            if allowsNone {
                commit(nil)
            }
            return true
        }
        guard !modifiers.intersection([.command, .option, .control]).isEmpty else {
            return true
        }
        record(AkapenCore.KeyboardShortcut(keyCode: UInt32(keyCode), modifiers: modifiers))
        return true
    }

    /// `NSEvent` のキー入力を扱う。
    @discardableResult
    func handle(_ event: NSEvent) -> Bool {
        handle(keyCode: event.keyCode, flags: event.modifierFlags)
    }

    private func record(_ candidate: AkapenCore.KeyboardShortcut) {
        if candidate == shortcut {
            endRecording()
            return
        }
        if isTaken(candidate) {
            problem = .inUse
            endRecording()
            return
        }
        guard isAvailable(candidate) else {
            problem = .unavailable
            endRecording()
            return
        }
        commit(candidate)
    }

    private func commit(_ value: AkapenCore.KeyboardShortcut?) {
        let changed = value != shortcut
        shortcut = value
        problem = nil
        endRecording()
        if changed {
            onCommit?(value)
        }
    }

    private func endRecording() {
        isRecording = false
        onRecordingChange?(false)
    }
}

extension UIStrings {
    /// キーの記録欄の知らせ。
    func recorderMessage(_ problem: KeyRecorderModel.Problem) -> String {
        switch problem {
        case .unavailable:
            self[.recorderUnavailable]
        case .inUse:
            self[.recorderInUse]
        }
    }
}

/// 記録を待っている間、キー入力を受け取る見えない NSView。記録欄の後ろに置く。
///
/// `⌘` 付きのキーはキー入力（`keyDown`）より先に `performKeyEquivalent` に来るので、両方で受け取る。
/// フォーカスが外れたら（ほかの欄をクリックしたなど）記録をやめる。
final class KeyCaptureView: NSView {
    var recorder: KeyRecorderModel?
    /// フォーカスを手放しても、記録をやめない間（同じ記録欄の作り直された NSView へ渡すとき、画面から外されるとき）。
    private var isHandingOver = false

    override var acceptsFirstResponder: Bool {
        recorder?.isRecording == true
    }

    /// マウスは前の記録欄（SwiftUI のボタン）に通す。
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func keyDown(with event: NSEvent) {
        if recorder?.handle(event) != true {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let recorder, recorder.isRecording, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        return recorder.handle(event)
    }

    override func cancelOperation(_ sender: Any?) {
        recorder?.cancelRecording()
    }

    override func resignFirstResponder() -> Bool {
        if !isHandingOver {
            recorder?.cancelRecording()
        }
        return true
    }

    /// 記録を待っている間はフォーカスを取り、待つのをやめたら手放す。
    ///
    /// 記録欄の中身が変わると、SwiftUI がこの NSView を作り直すことがある。
    /// フォーカスを持っているのが同じ記録欄の古い NSView なら、記録を続けたまま受け取る。
    func syncFocus() {
        guard let window else {
            return
        }
        let isRecording = recorder?.isRecording == true
        if isRecording, window.firstResponder !== self {
            let previous = window.firstResponder as? KeyCaptureView
            let isSameRecorder = previous?.recorder === recorder
            if isSameRecorder {
                previous?.isHandingOver = true
            }
            window.makeFirstResponder(self)
            if isSameRecorder {
                previous?.isHandingOver = false
            }
        } else if !isRecording, window.firstResponder === self {
            window.makeFirstResponder(nil)
        }
    }

    /// 画面から外されるときは記録をやめない（作り直された NSView が受け取る。ウィンドウを閉じたときは制御役がやめる）。
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            isHandingOver = true
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        isHandingOver = false
        super.viewDidMoveToWindow()
        syncFocus()
    }
}

/// `KeyCaptureView` を SwiftUI に置く。`isRecording` が変わるたびにフォーカスを合わせる。
struct KeyCaptureField: NSViewRepresentable {
    let recorder: KeyRecorderModel
    /// `recorder.isRecording` を渡す（値が変わったときに `updateNSView` が呼ばれるように）。
    let isRecording: Bool

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.recorder = recorder
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.recorder = recorder
        // 画面の更新の途中でフォーカスを動かすと、外れた欄の記録をやめる処理が更新の中で走るので、次の周回に回す。
        Task { @MainActor [weak nsView] in
            nsView?.syncFocus()
        }
    }
}
