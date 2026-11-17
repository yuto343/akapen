import AppKit
import AkapenAXID

@MainActor final class SampleDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var count = 0
    let label = NSTextField(labelWithString: "0")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frameText = ProcessInfo.processInfo.environment["SAMPLE_FRAME"] ?? "160,180,500,320"
        let parts = frameText.split(separator: ",").compactMap { Double($0) }
        let values = parts.count == 4 ? parts : [160, 180, 500, 320]
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        window = NSWindow(
            contentRect: NSRect(x: values[0], y: top - values[1] - values[3], width: values[2], height: values[3]),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let button = NSButton(
            title: NSLocalizedString("increment", comment: ""),
            target: self,
            action: #selector(increment)
        )
        button.setAccessibilityIdentifier(AXID.Sample.button)
        label.setAccessibilityIdentifier(AXID.Sample.count)
        let stack = NSStackView(views: [button, label])
        stack.orientation = .vertical
        window.contentView = stack
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func increment() {
        count += 1
        label.stringValue = String(count)
    }
}

let app = NSApplication.shared
let delegate = SampleDelegate()
app.delegate = delegate
app.run()
