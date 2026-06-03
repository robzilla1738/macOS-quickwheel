import AppKit
#if SWIFT_PACKAGE
import QuickwheelCore
#endif

let app = NSApplication.shared
let delegate = AppDelegate()

app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
