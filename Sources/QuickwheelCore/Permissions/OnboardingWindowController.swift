import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    private let recheckHandler: () -> Void

    init(recheckHandler: @escaping () -> Void) {
        self.recheckHandler = recheckHandler

        let model = OnboardingModel(
            title: "Accessibility Permission Required",
            message: "Quickwheel needs Accessibility permission to detect the configured global modifier-click gesture and block the original click while the wheel is open.",
            primaryButtonTitle: "Open System Settings",
            secondaryButtonTitle: "Recheck",
            openSettings: Self.openAccessibilitySettings,
            recheck: recheckHandler
        )
        let hostingController = NSHostingController(rootView: OnboardingView(model: model))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Quickwheel"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 260))
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPermissionRequired() {
        updateContent(
            title: "Accessibility Permission Required",
            message: "Quickwheel needs Accessibility permission to detect the configured global modifier-click gesture and block the original click while the wheel is open.",
            primaryButtonTitle: "Open System Settings"
        )
        show()
    }

    func showEventTapUnavailable() {
        updateContent(
            title: "Input Monitor Unavailable",
            message: "Quickwheel could not install its event tap. Confirm Accessibility permission, then recheck.",
            primaryButtonTitle: "Open System Settings"
        )
        show()
    }

    private func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateContent(title: String, message: String, primaryButtonTitle: String) {
        guard let hostingController = window?.contentViewController as? NSHostingController<OnboardingView> else {
            return
        }

        let model = OnboardingModel(
            title: title,
            message: message,
            primaryButtonTitle: primaryButtonTitle,
            secondaryButtonTitle: "Recheck",
            openSettings: Self.openAccessibilitySettings,
            recheck: recheckHandler
        )
        hostingController.rootView = OnboardingView(model: model)
    }

    private static func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct OnboardingModel {
    let title: String
    let message: String
    let primaryButtonTitle: String
    let secondaryButtonTitle: String
    let openSettings: () -> Void
    let recheck: () -> Void
}

private struct OnboardingView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.title)
                        .font(.title2.weight(.semibold))
                    Text(model.message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button(model.secondaryButtonTitle) {
                    model.recheck()
                }
                Button(model.primaryButtonTitle) {
                    model.openSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 260)
    }
}
