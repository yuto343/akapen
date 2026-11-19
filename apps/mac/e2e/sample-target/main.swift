import AppKit

// E2E の撮影対象にする小さなアプリ。Paper の「Sample App」に近い構成のウィンドウを 1 枚だけ出す。
let application = NSApplication.shared
let delegate = SampleDelegate()
application.delegate = delegate
application.run()
