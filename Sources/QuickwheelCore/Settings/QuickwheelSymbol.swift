import AppKit

enum QuickwheelSymbol {
    static func validatedName(_ symbolName: String, fallback: String) -> String {
        let trimmedSymbolName = symbolName.trimmedForQuickwheel
        if !trimmedSymbolName.isEmpty,
           NSImage(systemSymbolName: trimmedSymbolName, accessibilityDescription: nil) != nil {
            return trimmedSymbolName
        }

        if NSImage(systemSymbolName: fallback, accessibilityDescription: nil) != nil {
            return fallback
        }

        return "questionmark.circle"
    }
}
