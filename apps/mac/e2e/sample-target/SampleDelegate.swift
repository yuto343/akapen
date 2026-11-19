import AppKit
import AkapenAXID

/// Sample App のウィンドウを組み立て、`Submit` を押した回数を数える。
@MainActor final class SampleDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    private var count = 0

    private let countLabel = NSTextField(labelWithString: "0")

    private let firstField = NSTextField(string: "")

    private let secondField = NSTextView()

    private let thirdField = NSTextField(string: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = Self.windowFrame(from: ProcessInfo.processInfo.environment["SAMPLE_FRAME"])
        let window = SampleWindow(
            contentRect: Self.appKitRect(frame),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.setFrame(Self.appKitRect(frame), display: false)
        window.title = NSLocalizedString("window.title", comment: "")
        window.isRestorable = false
        window.appearance = NSAppearance(named: .aqua)
        window.isMovable = false
        window.setAccessibilityIdentifier(AXID.Sample.window)
        let canvas = SampleCanvas(frame: window.contentLayoutRect)
        window.contentView = canvas
        canvas.fitContents()
        buildSidebar(in: canvas)
        buildForm(in: canvas)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// `SAMPLE_FRAME`（`x,y,幅,高さ`。主画面の左上が原点）を読む。読めなければ資料の位置と大きさにする。
    static func windowFrame(from text: String?) -> NSRect {
        let values = (text ?? "").split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == 4 else {
            return SampleLayout.defaultFrame
        }
        return NSRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }

    /// 主画面の左上を原点にした矩形を、AppKit の左下原点の矩形に直す。
    static func appKitRect(_ rect: NSRect) -> NSRect {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(x: rect.minX, y: top - rect.minY - rect.height, width: rect.width, height: rect.height)
    }

    private func buildSidebar(in canvas: SampleCanvas) {
        let sidebar = SidebarView(frame: NSRect(
            x: 0,
            y: 0,
            width: SampleLayout.sidebarWidth,
            height: canvas.bounds.height
        ))
        sidebar.setAccessibilityElement(true)
        sidebar.setAccessibilityRole(.group)
        sidebar.setAccessibilityIdentifier(AXID.Sample.sidebar)
        for (index, itemFrame) in SampleLayout.sidebarItems.enumerated() {
            let isSelected = index == 0
            let item = FilledShape(
                frame: itemFrame,
                color: isSelected ? SampleColor.sidebarSelection : .clear,
                radius: SampleLayout.controlRadius
            )
            item.setAccessibilityElement(true)
            item.setAccessibilityRole(.group)
            item.setAccessibilityIdentifier(AXID.Sample.sidebarItem(index))
            let bar = FilledShape(
                frame: NSRect(x: 12, y: 10, width: SampleLayout.sidebarBarWidths[index], height: 8),
                color: isSelected ? SampleColor.selectedBar : SampleColor.bar,
                radius: 4
            )
            item.addSubview(bar)
            sidebar.addSubview(item)
        }
        canvas.addSubview(sidebar)
    }

    private func buildForm(in canvas: SampleCanvas) {
        let form = NSView(frame: SampleLayout.form)
        form.setAccessibilityElement(true)
        form.setAccessibilityRole(.group)
        form.setAccessibilityIdentifier(AXID.Sample.form)
        canvas.addSubview(form)
        let heading = FilledShape(
            frame: SampleLayout.headingTitle,
            color: SampleColor.headingTitle,
            radius: 7
        )
        heading.setAccessibilityElement(true)
        heading.setAccessibilityRole(.group)
        heading.setAccessibilityIdentifier(AXID.Sample.heading)
        canvas.addSubview(heading)
        canvas.addSubview(FilledShape(
            frame: SampleLayout.headingSubtitle,
            color: SampleColor.headingSubtitle,
            radius: 4
        ))
        for labelFrame in SampleLayout.fieldLabels {
            canvas.addSubview(FilledShape(frame: labelFrame, color: SampleColor.bar, radius: 4))
        }
        addSingleLineField(firstField, frame: SampleLayout.firstField, identifier: AXID.Sample.firstField, in: canvas)
        addMultiLineField(in: canvas)
        addSingleLineField(thirdField, frame: SampleLayout.thirdField, identifier: AXID.Sample.thirdField, in: canvas)
        canvas.addSubview(FilledShape(frame: SampleLayout.separator, color: SampleColor.separator, radius: 0))
        let cancel = SampleButton(
            frame: SampleLayout.cancel,
            title: NSLocalizedString("button.cancel", comment: ""),
            style: .outlined
        )
        cancel.target = self
        cancel.action = #selector(clearFields)
        cancel.setAccessibilityIdentifier(AXID.Sample.cancel)
        canvas.addSubview(cancel)
        let submit = SampleButton(
            frame: SampleLayout.submit,
            title: NSLocalizedString("button.submit", comment: ""),
            style: .filled
        )
        submit.target = self
        submit.action = #selector(submitForm)
        submit.keyEquivalent = ""
        submit.setAccessibilityIdentifier(AXID.Sample.button)
        canvas.addSubview(submit)
        let caption = NSTextField(labelWithString: NSLocalizedString("count.caption", comment: ""))
        caption.font = NSFont.systemFont(ofSize: SampleLayout.fontSize)
        caption.textColor = SampleColor.secondaryText
        caption.sizeToFit()
        caption.setFrameOrigin(SampleLayout.countCaption.origin)
        canvas.addSubview(caption)
        countLabel.frame = SampleLayout.count.offsetBy(dx: caption.frame.maxX + SampleLayout.countSpacing, dy: 0)
        countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: SampleLayout.fontSize, weight: .semibold)
        countLabel.textColor = SampleColor.text
        countLabel.setAccessibilityIdentifier(AXID.Sample.count)
        canvas.addSubview(countLabel)
    }

    private func addSingleLineField(_ field: NSTextField, frame: NSRect, identifier: String, in canvas: SampleCanvas) {
        let outline = OutlineView(frame: frame)
        let inset = SampleLayout.fieldInset
        let height = field.intrinsicContentSize.height
        field.frame = NSRect(
            x: inset,
            y: (frame.height - height) / 2,
            width: frame.width - inset * 2,
            height: height
        )
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: SampleLayout.fontSize)
        field.usesSingleLineMode = true
        field.setAccessibilityIdentifier(identifier)
        outline.addSubview(field)
        canvas.addSubview(outline)
    }

    private func addMultiLineField(in canvas: SampleCanvas) {
        let frame = SampleLayout.secondField
        let outline = OutlineView(frame: frame)
        let inset = SampleLayout.fieldInset / 2
        let scroll = NSScrollView(frame: NSRect(
            x: inset,
            y: inset,
            width: frame.width - inset * 2,
            height: frame.height - inset * 2
        ))
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.borderType = .noBorder
        secondField.frame = NSRect(origin: .zero, size: scroll.contentSize)
        secondField.drawsBackground = false
        secondField.isRichText = false
        secondField.font = NSFont.systemFont(ofSize: SampleLayout.fontSize)
        secondField.textContainerInset = NSSize(width: 0, height: 2)
        secondField.autoresizingMask = [.width]
        secondField.setAccessibilityIdentifier(AXID.Sample.secondField)
        scroll.documentView = secondField
        outline.addSubview(scroll)
        canvas.addSubview(outline)
    }

    @objc private func submitForm() {
        count += 1
        countLabel.stringValue = String(count)
    }

    @objc private func clearFields() {
        firstField.stringValue = ""
        secondField.string = ""
        thirdField.stringValue = ""
    }
}

/// 位置と大きさを OS に直されないウィンドウ。毎回 `SAMPLE_FRAME` のとおりに出すため。
final class SampleWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
