import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class ActionRunner {
    func run(_ action: QuickwheelAction) {
        switch action.kind {
        case .none:
            break
        case .openURL:
            openURL(action.urlString)
        case .openFile:
            openFile(at: action.filePath)
        case .revealInFinder:
            revealInFinder(path: action.filePath)
        case .launchApp:
            launchApp(bundleIdentifier: action.bundleIdentifier)
        case .shellCommand:
            runShellCommand(action.shellCommand)
        case .appleScript:
            runAppleScript(action.appleScript)
        case .pasteText:
            pasteText(action.text)
        case .keyboardShortcut:
            let parsedShortcut = QuickwheelShortcutParser.parse(action.shortcutKey)
            sendKeyboardShortcut(
                keyCode: CGKeyCode(clamping: parsedShortcut?.keyCode ?? action.shortcutKeyCode),
                modifiers: parsedShortcut?.modifiers ?? action.shortcutModifiers
            )
        }
    }

    private func openURL(_ urlString: String) {
        let trimmedURLString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURLString), !trimmedURLString.isEmpty else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func openFile(at path: String) {
        let trimmedPath = path.trimmedForQuickwheel
        guard !trimmedPath.isEmpty else { return }

        NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath(trimmedPath)))
    }

    private func revealInFinder(path: String) {
        let trimmedPath = path.trimmedForQuickwheel
        guard !trimmedPath.isEmpty else { return }

        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: expandedPath(trimmedPath))
        ])
    }

    private func launchApp(bundleIdentifier: String) {
        let trimmedBundleIdentifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmedBundleIdentifier.isEmpty,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmedBundleIdentifier)
        else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }

    private func runShellCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", trimmedCommand]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                NSLog("Quickwheel shell action failed: \(error.localizedDescription)")
            }
        }
    }

    private func runAppleScript(_ script: String) {
        let trimmedScript = script.trimmedForQuickwheel
        guard !trimmedScript.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            var errorInfo: NSDictionary?
            let appleScript = NSAppleScript(source: trimmedScript)
            appleScript?.executeAndReturnError(&errorInfo)

            if let errorInfo {
                NSLog("Quickwheel AppleScript action failed: \(errorInfo)")
            }
        }
    }

    private func pasteText(_ text: String) {
        guard !text.isEmpty else { return }

        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let previousItems = pasteboard.quickwheelClonedItems()

            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            self.postKeyboardShortcut(
                keyCode: CGKeyCode(kVK_ANSI_V),
                modifiers: [.command]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                pasteboard.clearContents()
                if !previousItems.isEmpty {
                    pasteboard.writeObjects(previousItems)
                }
            }
        }
    }

    private func sendKeyboardShortcut(keyCode: CGKeyCode, modifiers: ShortcutModifiers) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.postKeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private func postKeyboardShortcut(keyCode: CGKeyCode, modifiers: ShortcutModifiers) {
        let source = CGEventSource(stateID: .hidSystemState)
        let flags = modifiers.cgEventFlags

        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: true
        )
        keyDown?.flags = flags

        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: keyCode,
            keyDown: false
        )
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        usleep(25_000)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func expandedPath(_ path: String) -> String {
        guard path.hasPrefix("~/") else {
            return path
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        return homeDirectory + String(path.dropFirst())
    }
}

private extension NSPasteboard {
    func quickwheelClonedItems() -> [NSPasteboardItem] {
        guard let pasteboardItems else { return [] }

        return pasteboardItems.map { item in
            let clonedItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clonedItem.setData(data, forType: type)
                }
            }
            return clonedItem
        }
    }
}

private extension ShortcutModifiers {
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []

        if contains(.command) {
            flags.insert(.maskCommand)
        }

        if contains(.shift) {
            flags.insert(.maskShift)
        }

        if contains(.option) {
            flags.insert(.maskAlternate)
        }

        if contains(.control) {
            flags.insert(.maskControl)
        }

        return flags
    }
}
