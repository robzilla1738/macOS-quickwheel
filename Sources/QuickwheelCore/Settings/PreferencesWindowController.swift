import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(settingsStore: SettingsStore) {
        let hostingController = NSHostingController(rootView: PreferencesView(settingsStore: settingsStore))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Quickwheel Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 820, height: 620))
        window.minSize = NSSize(width: 780, height: 560)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
