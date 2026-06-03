import XCTest
@testable import QuickwheelCore

final class SettingsStoreTests: XCTestCase {
    func testSettingsRoundTripThroughUserDefaults() throws {
        let suiteName = "quickwheel.tests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(userDefaults: userDefaults, storageKey: "settings")
        var action = QuickwheelAction()
        action.kind = .openURL
        action.urlString = "https://example.com"
        store.updateAction(action, for: .up)

        let reloadedStore = SettingsStore(userDefaults: userDefaults, storageKey: "settings")
        XCTAssertEqual(reloadedStore.settings.up.kind, .openURL)
        XCTAssertEqual(reloadedStore.settings.up.urlString, "https://example.com")
    }

    func testDecodesOlderSettingsWithoutNewFields() throws {
        let json = """
        {
          "up": { "kind": "openURL", "urlString": "https://example.com" },
          "down": { "kind": "none" },
          "left": { "kind": "none" },
          "right": { "kind": "none" }
        }
        """

        let settings = try JSONDecoder().decode(QuickwheelSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.triggerModifier, .leftCommand)
        XCTAssertEqual(settings.menuBarSymbolName, "command.circle")
        XCTAssertEqual(settings.centerSymbolName, "command")
        XCTAssertEqual(settings.up.kind, .openURL)
        XCTAssertEqual(settings.up.urlString, "https://example.com")
    }

    func testActionDisplayFallsBackToKindAndDirection() {
        var action = QuickwheelAction()
        action.kind = .openFile
        action.filePath = "~/Desktop"

        XCTAssertEqual(action.resolvedTitle(fallback: .left), "Left")
        XCTAssertEqual(action.resolvedSymbol(fallback: .left), "doc")
        XCTAssertTrue(action.isRunnable)
        XCTAssertEqual(action.summary, "~/Desktop")
    }

    func testParsesReadableShortcutKeys() throws {
        let parsedShortcut = try XCTUnwrap(QuickwheelShortcutParser.parse("cmd+shift+p"))

        XCTAssertEqual(parsedShortcut.keyCode, 35)
        XCTAssertTrue(parsedShortcut.modifiers.contains(.command))
        XCTAssertTrue(parsedShortcut.modifiers.contains(.shift))
        XCTAssertFalse(parsedShortcut.modifiers.contains(.option))
    }

    func testRejectsUnknownShortcutModifiers() {
        XCTAssertNil(QuickwheelShortcutParser.parse("banana+p"))
    }

    func testConfigurationDocumentCanMergeAISlots() throws {
        let json = """
        {
          "schemaVersion": 1,
          "name": "AI patch",
          "mode": "merge",
          "settings": {
            "triggerModifier": "eitherOption"
          },
          "slots": {
            "right": {
              "title": "AI Chat",
              "iconName": "sparkles",
              "kind": "keyboardShortcut",
              "shortcutKey": "cmd+l"
            }
          }
        }
        """

        let settings = try QuickwheelConfigurationCodec.decodeSettings(
            from: Data(json.utf8),
            currentSettings: .defaults
        )

        XCTAssertEqual(settings.right.title, "AI Chat")
        XCTAssertEqual(settings.right.shortcutKeyCode, 37)
        XCTAssertTrue(settings.right.shortcutModifiers.contains(.command))
        XCTAssertEqual(settings.left.title, "Back")
        XCTAssertEqual(settings.triggerModifier, .eitherOption)
    }

    func testTriggerModifierCodableRoundTrip() throws {
        var settings = QuickwheelSettings.defaults
        settings.triggerModifier = .rightControl

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(QuickwheelSettings.self, from: data)

        XCTAssertEqual(decoded.triggerModifier, .rightControl)
    }
}
