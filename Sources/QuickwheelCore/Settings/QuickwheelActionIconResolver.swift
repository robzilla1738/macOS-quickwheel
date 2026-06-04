import AppKit
import Foundation

enum QuickwheelActionIconResolver {
    static func image(for action: QuickwheelAction) -> NSImage? {
        if !action.iconImagePath.trimmedForQuickwheel.isEmpty,
           let customImage = QuickwheelIconStore.image(forIconPath: action.iconImagePath) {
            return customImage
        }

        guard action.iconName.trimmedForQuickwheel.isEmpty else {
            return nil
        }

        switch action.kind {
        case .launchApp:
            let bundleIdentifier = action.bundleIdentifier.trimmedForQuickwheel
            guard
                !bundleIdentifier.isEmpty,
                let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            else {
                return nil
            }

            return workspaceIcon(forFile: appURL.path)

        case .openFile, .revealInFinder:
            let path = expandedPath(action.filePath.trimmedForQuickwheel)
            guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
                return nil
            }

            return workspaceIcon(forFile: path)

        default:
            return nil
        }
    }

    static func symbolName(for action: QuickwheelAction, fallback direction: WheelDirection) -> String {
        QuickwheelSymbol.validatedName(
            action.resolvedSymbol(fallback: direction),
            fallback: direction.symbolName
        )
    }

    private static func workspaceIcon(forFile path: String) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: path)
        let preparedImage = (image.copy() as? NSImage) ?? image
        preparedImage.size = NSSize(width: 32, height: 32)
        return preparedImage
    }

    private static func expandedPath(_ path: String) -> String {
        guard path.hasPrefix("~/") else {
            return path
        }

        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        return homeDirectory + String(path.dropFirst())
    }
}
