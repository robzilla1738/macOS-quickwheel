import AppKit
import Foundation

enum QuickwheelIconStore {
    static var iconsDirectoryURL: URL {
        QuickwheelConfigurationFiles.directoryURL.appendingPathComponent("Icons", isDirectory: true)
    }

    /// Copies an image into the configuration folder's Icons directory and
    /// returns the relative path (`Icons/<uuid>.<ext>`) to store in settings.
    static func importImage(from sourceURL: URL) throws -> String {
        try FileManager.default.createDirectory(
            at: iconsDirectoryURL,
            withIntermediateDirectories: true
        )

        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = iconsDirectoryURL.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return "Icons/\(fileName)"
    }

    /// Resolves a stored icon path. Relative paths are anchored at the
    /// configuration folder; absolute and `~/` paths are used as-is.
    static func resolvedURL(forIconPath path: String) -> URL {
        let trimmedPath = path.trimmedForQuickwheel

        if trimmedPath.hasPrefix("/") {
            return URL(fileURLWithPath: trimmedPath)
        }

        if trimmedPath.hasPrefix("~/") {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            return URL(fileURLWithPath: homeDirectory + String(trimmedPath.dropFirst()))
        }

        return QuickwheelConfigurationFiles.directoryURL.appendingPathComponent(trimmedPath)
    }

    static func image(forIconPath path: String) -> NSImage? {
        let url = resolvedURL(forIconPath: path)
        guard let image = NSImage(contentsOf: url) else { return nil }
        let preparedImage = (image.copy() as? NSImage) ?? image
        preparedImage.size = NSSize(width: 32, height: 32)
        return preparedImage
    }
}
