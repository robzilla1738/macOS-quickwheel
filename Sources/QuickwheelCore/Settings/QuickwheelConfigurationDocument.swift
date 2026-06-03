import Foundation

enum QuickwheelConfigurationImportMode: String, Codable {
    case replace
    case merge
}

struct QuickwheelSlotOverrides: Codable, Equatable {
    var up: QuickwheelAction?
    var down: QuickwheelAction?
    var left: QuickwheelAction?
    var right: QuickwheelAction?

    var isEmpty: Bool {
        up == nil && down == nil && left == nil && right == nil
    }

    func apply(to settings: inout QuickwheelSettings) {
        if let up {
            settings.up = up
        }

        if let down {
            settings.down = down
        }

        if let left {
            settings.left = left
        }

        if let right {
            settings.right = right
        }
    }
}

struct QuickwheelConfigurationDocument: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var name = "Quickwheel Configuration"
    var mode = QuickwheelConfigurationImportMode.replace
    var settings: QuickwheelSettings?
    var slots: QuickwheelSlotOverrides?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case name
        case mode
        case settings
        case slots
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        name: String = "Quickwheel Configuration",
        mode: QuickwheelConfigurationImportMode = .replace,
        settings: QuickwheelSettings? = nil,
        slots: QuickwheelSlotOverrides? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.mode = mode
        self.settings = settings
        self.slots = slots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Quickwheel Configuration"
        mode = try container.decodeIfPresent(QuickwheelConfigurationImportMode.self, forKey: .mode) ?? .merge
        settings = try container.decodeIfPresent(QuickwheelSettings.self, forKey: .settings)
        slots = try container.decodeIfPresent(QuickwheelSlotOverrides.self, forKey: .slots)
    }

    func resolvedSettings(currentSettings: QuickwheelSettings) -> QuickwheelSettings {
        var resolvedSettings: QuickwheelSettings

        switch mode {
        case .replace:
            resolvedSettings = settings ?? .defaults
        case .merge:
            resolvedSettings = currentSettings
            if let settings {
                resolvedSettings.isEnabled = settings.isEnabled
                resolvedSettings.triggerModifier = settings.triggerModifier
                resolvedSettings.menuBarSymbolName = settings.menuBarSymbolName
                resolvedSettings.centerSymbolName = settings.centerSymbolName
                resolvedSettings.deadZoneRadius = settings.deadZoneRadius
                resolvedSettings.overlaySize = settings.overlaySize
                resolvedSettings.showOverlayLabels = settings.showOverlayLabels
            }
        }

        slots?.apply(to: &resolvedSettings)
        resolvedSettings.clampEditableValues()
        return resolvedSettings
    }
}

enum QuickwheelConfigurationCodec {
    static func decodeSettings(from data: Data, currentSettings: QuickwheelSettings) throws -> QuickwheelSettings {
        if shouldDecodeAsDocument(data),
           let document = try? JSONDecoder().decode(QuickwheelConfigurationDocument.self, from: data) {
            return document.resolvedSettings(currentSettings: currentSettings)
        }

        var settings = try JSONDecoder().decode(QuickwheelSettings.self, from: data)
        settings.clampEditableValues()
        return settings
    }

    static func encodeDocument(settings: QuickwheelSettings, name: String = "Quickwheel Configuration") throws -> Data {
        let document = QuickwheelConfigurationDocument(
            name: name,
            mode: .replace,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    private static func shouldDecodeAsDocument(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return false
        }

        return dictionary.keys.contains("schemaVersion")
            || dictionary.keys.contains("mode")
            || dictionary.keys.contains("settings")
            || dictionary.keys.contains("slots")
    }
}

enum QuickwheelConfigurationFiles {
    static var directoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return baseURL.appendingPathComponent("Quickwheel", isDirectory: true)
    }

    static var activeConfigurationURL: URL {
        directoryURL.appendingPathComponent("active.quickwheel.json")
    }

    static var readmeURL: URL {
        directoryURL.appendingPathComponent("README.md")
    }

    static var schemaURL: URL {
        directoryURL.appendingPathComponent("quickwheel-config.schema.json")
    }

    static func ensureDirectory(currentSettings: QuickwheelSettings) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: activeConfigurationURL.path) {
            let data = try QuickwheelConfigurationCodec.encodeDocument(
                settings: currentSettings,
                name: "Active Quickwheel Configuration"
            )
            try data.write(to: activeConfigurationURL, options: [.atomic])
        }

        if !FileManager.default.fileExists(atPath: readmeURL.path) {
            try configurationReadme.write(to: readmeURL, atomically: true, encoding: .utf8)
        }

        if !FileManager.default.fileExists(atPath: schemaURL.path) {
            try configurationSchema.write(to: schemaURL, atomically: true, encoding: .utf8)
        }
    }

    static func writeActiveConfiguration(settings: QuickwheelSettings) throws {
        try ensureDirectory(currentSettings: settings)
        let data = try QuickwheelConfigurationCodec.encodeDocument(
            settings: settings,
            name: "Active Quickwheel Configuration"
        )
        try data.write(to: activeConfigurationURL, options: [.atomic])
    }

    static func readActiveConfiguration(currentSettings: QuickwheelSettings) throws -> QuickwheelSettings {
        let data = try Data(contentsOf: activeConfigurationURL)
        return try QuickwheelConfigurationCodec.decodeSettings(
            from: data,
            currentSettings: currentSettings
        )
    }

    private static let configurationReadme = """
    # Quickwheel Configuration Folder

    Tools can update Quickwheel by writing JSON to `active.quickwheel.json`, then choosing Reload Active Configuration from the Quickwheel menu.

    For shortcut actions, prefer the readable `shortcutKey` field:

    ```json
    {
      "schemaVersion": 1,
      "mode": "merge",
      "slots": {
        "up": {
          "title": "Command Palette",
          "iconName": "command",
          "kind": "keyboardShortcut",
          "shortcutKey": "cmd+shift+p"
        }
      }
    }
    ```

    Supported action kinds: `none`, `openURL`, `openFile`, `revealInFinder`, `launchApp`, `shellCommand`, `appleScript`, `pasteText`, `keyboardShortcut`.

    Leave `iconName` blank for app/file actions when Quickwheel should show the target app, file, or folder icon automatically.

    To change the activation gesture in a full `settings` object, set `triggerModifier` to one of: `leftCommand`, `rightCommand`, `eitherCommand`, `leftOption`, `rightOption`, `eitherOption`, `leftControl`, `rightControl`, `eitherControl`, `leftShift`, `rightShift`, `eitherShift`.
    """

    private static let configurationSchema = """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "title": "Quickwheel Configuration",
      "type": "object",
      "properties": {
        "schemaVersion": { "type": "integer", "const": 1 },
        "name": { "type": "string" },
        "mode": { "type": "string", "enum": ["replace", "merge"] },
        "settings": { "$ref": "#/$defs/settings" },
        "slots": { "$ref": "#/$defs/slots" }
      },
      "$defs": {
        "slots": {
          "type": "object",
          "properties": {
            "up": { "$ref": "#/$defs/action" },
            "down": { "$ref": "#/$defs/action" },
            "left": { "$ref": "#/$defs/action" },
            "right": { "$ref": "#/$defs/action" }
          },
          "additionalProperties": false
        },
        "settings": {
          "type": "object",
          "properties": {
            "isEnabled": { "type": "boolean" },
            "triggerModifier": {
              "type": "string",
              "enum": ["leftCommand", "rightCommand", "eitherCommand", "leftOption", "rightOption", "eitherOption", "leftControl", "rightControl", "eitherControl", "leftShift", "rightShift", "eitherShift"]
            },
            "menuBarSymbolName": { "type": "string" },
            "centerSymbolName": { "type": "string" },
            "deadZoneRadius": { "type": "number", "minimum": 12, "maximum": 120 },
            "overlaySize": { "type": "number", "minimum": 144, "maximum": 260 },
            "showOverlayLabels": { "type": "boolean", "default": false },
            "up": { "$ref": "#/$defs/action" },
            "down": { "$ref": "#/$defs/action" },
            "left": { "$ref": "#/$defs/action" },
            "right": { "$ref": "#/$defs/action" }
          },
          "additionalProperties": false
        },
        "action": {
          "type": "object",
          "properties": {
            "title": { "type": "string" },
            "iconName": { "type": "string" },
            "kind": {
              "type": "string",
              "enum": ["none", "openURL", "openFile", "revealInFinder", "launchApp", "shellCommand", "appleScript", "pasteText", "keyboardShortcut"]
            },
            "urlString": { "type": "string" },
            "filePath": { "type": "string" },
            "bundleIdentifier": { "type": "string" },
            "shellCommand": { "type": "string" },
            "appleScript": { "type": "string" },
            "text": { "type": "string" },
            "shortcutKey": { "type": "string" },
            "shortcutKeyCode": { "type": "integer" },
            "shortcutModifiers": { "type": "integer" }
          },
          "required": ["kind"],
          "additionalProperties": false
        }
      }
    }
    """
}
