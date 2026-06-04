import Foundation

enum QuickwheelConfigurationImportMode: String, Codable {
    case replace
    case merge
}

struct QuickwheelSlotOverrides: Codable, Equatable {
    var up: QuickwheelSlot?
    var down: QuickwheelSlot?
    var left: QuickwheelSlot?
    var right: QuickwheelSlot?

    var isEmpty: Bool {
        up == nil && down == nil && left == nil && right == nil
    }

    func apply(to settings: inout QuickwheelSettings) {
        guard !settings.layers.isEmpty else { return }

        if let up {
            settings.layers[0].up = up
        }

        if let down {
            settings.layers[0].down = down
        }

        if let left {
            settings.layers[0].left = left
        }

        if let right {
            settings.layers[0].right = right
        }
    }
}

struct QuickwheelConfigurationDocument: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion = currentSchemaVersion
    var name = "Quickwheel Configuration"
    var mode = QuickwheelConfigurationImportMode.replace
    var settings: QuickwheelSettings?
    var slots: QuickwheelSlotOverrides?
    var layers: [WheelLayer]?

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case name
        case mode
        case settings
        case slots
        case layers
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        name: String = "Quickwheel Configuration",
        mode: QuickwheelConfigurationImportMode = .replace,
        settings: QuickwheelSettings? = nil,
        slots: QuickwheelSlotOverrides? = nil,
        layers: [WheelLayer]? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.mode = mode
        self.settings = settings
        self.slots = slots
        self.layers = layers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Quickwheel Configuration"
        mode = try container.decodeIfPresent(QuickwheelConfigurationImportMode.self, forKey: .mode) ?? .merge
        settings = try container.decodeIfPresent(QuickwheelSettings.self, forKey: .settings)
        slots = try container.decodeIfPresent(QuickwheelSlotOverrides.self, forKey: .slots)
        layers = try container.decodeIfPresent([WheelLayer].self, forKey: .layers)
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

        if let layers, !layers.isEmpty {
            resolvedSettings.layers = layers
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
      "schemaVersion": 2,
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

    ## Layers

    Quickwheel has three wheel layers. Modifier+click opens Layer 1; holding 1, 2, or 3 with the modifier opens that layer. `slots` entries apply to Layer 1. To configure every layer, provide a top-level `layers` array of layer objects, each with `name` and `up`/`down`/`left`/`right` slots.

    ## Trigger patterns (multi-step slots)

    A slot can be a single action object, or `{ "steps": [action, action, ...] }`. Each trigger runs the next step and wraps around; the cycle position survives restarts.

    ```json
    {
      "schemaVersion": 2,
      "mode": "merge",
      "slots": {
        "up": {
          "steps": [
            { "title": "Start Recording", "kind": "openURL", "urlString": "spokenly://toggle" },
            { "title": "Stop Recording", "kind": "openURL", "urlString": "spokenly://toggle" }
          ]
        }
      }
    }
    ```

    ## Icons

    Leave `iconName` blank for app/file actions when Quickwheel should show the target app, file, or folder icon automatically. Set `iconImagePath` to use a custom image: relative paths (for example `Icons/my-icon.png`) resolve against this configuration folder; absolute and `~/` paths also work. A custom image overrides `iconName`.

    To change the activation gesture in a full `settings` object, set `triggerModifier` to one of: `leftCommand`, `rightCommand`, `eitherCommand`, `leftOption`, `rightOption`, `eitherOption`, `leftControl`, `rightControl`, `eitherControl`, `leftShift`, `rightShift`, `eitherShift`.
    """

    private static let configurationSchema = """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "title": "Quickwheel Configuration",
      "type": "object",
      "properties": {
        "schemaVersion": { "type": "integer", "enum": [1, 2] },
        "name": { "type": "string" },
        "mode": { "type": "string", "enum": ["replace", "merge"] },
        "settings": { "$ref": "#/$defs/settings" },
        "slots": { "$ref": "#/$defs/slots" },
        "layers": {
          "type": "array",
          "items": { "$ref": "#/$defs/layer" },
          "maxItems": 3
        }
      },
      "$defs": {
        "slots": {
          "type": "object",
          "properties": {
            "up": { "$ref": "#/$defs/slot" },
            "down": { "$ref": "#/$defs/slot" },
            "left": { "$ref": "#/$defs/slot" },
            "right": { "$ref": "#/$defs/slot" }
          },
          "additionalProperties": false
        },
        "layer": {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "name": { "type": "string" },
            "up": { "$ref": "#/$defs/slot" },
            "down": { "$ref": "#/$defs/slot" },
            "left": { "$ref": "#/$defs/slot" },
            "right": { "$ref": "#/$defs/slot" }
          },
          "additionalProperties": false
        },
        "slot": {
          "oneOf": [
            { "$ref": "#/$defs/action" },
            {
              "type": "object",
              "properties": {
                "id": { "type": "string" },
                "steps": {
                  "type": "array",
                  "items": { "$ref": "#/$defs/action" },
                  "minItems": 1
                }
              },
              "required": ["steps"],
              "additionalProperties": false
            }
          ]
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
            "layers": {
              "type": "array",
              "items": { "$ref": "#/$defs/layer" },
              "maxItems": 3
            },
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
            "id": { "type": "string" },
            "title": { "type": "string" },
            "iconName": { "type": "string" },
            "iconImagePath": { "type": "string", "description": "Custom icon image. Relative paths resolve against the Quickwheel configuration folder." },
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
