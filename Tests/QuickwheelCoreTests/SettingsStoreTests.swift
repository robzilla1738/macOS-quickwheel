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

        // Legacy flat slots migrate into layer 1; the other layers stay empty.
        XCTAssertEqual(settings.layers.count, QuickwheelSettings.layerCount)
        XCTAssertEqual(settings.layers[0].up.steps.count, 1)
        XCTAssertEqual(settings.layers[0].up.primaryAction.urlString, "https://example.com")
        XCTAssertFalse(settings.layers[1].hasRunnableSlot)
        XCTAssertFalse(settings.layers[2].hasRunnableSlot)
    }

    func testLayersRoundTripThroughCodable() throws {
        var settings = QuickwheelSettings.defaults
        settings.layers[1].setSlot(
            QuickwheelSlot(steps: [
                QuickwheelAction(title: "Start", iconName: "record.circle", kind: .openURL, urlString: "app://start"),
                QuickwheelAction(title: "Stop", iconName: "stop.circle", kind: .openURL, urlString: "app://stop")
            ]),
            for: .up
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(QuickwheelSettings.self, from: data)

        XCTAssertEqual(decoded.layers.count, QuickwheelSettings.layerCount)
        XCTAssertEqual(decoded.layers[1].up.steps.count, 2)
        XCTAssertEqual(decoded.layers[1].up.steps[0].title, "Start")
        XCTAssertEqual(decoded.layers[1].up.steps[1].title, "Stop")
        XCTAssertEqual(decoded.layers[1].up.id, settings.layers[1].up.id)
        XCTAssertEqual(decoded.layers[0].up.primaryAction.title, "Search")
    }

    func testSlotDecodesBareActionAndStepsForms() throws {
        let bareActionJSON = """
        { "kind": "openURL", "urlString": "https://example.com" }
        """
        let bareSlot = try JSONDecoder().decode(QuickwheelSlot.self, from: Data(bareActionJSON.utf8))
        XCTAssertEqual(bareSlot.steps.count, 1)
        XCTAssertEqual(bareSlot.steps[0].urlString, "https://example.com")

        let stepsJSON = """
        {
          "steps": [
            { "kind": "pasteText", "text": "one" },
            { "kind": "pasteText", "text": "two" }
          ]
        }
        """
        let stepsSlot = try JSONDecoder().decode(QuickwheelSlot.self, from: Data(stepsJSON.utf8))
        XCTAssertEqual(stepsSlot.steps.count, 2)
        XCTAssertEqual(stepsSlot.steps[1].text, "two")
    }

    func testCycleIndexAdvancesAndPersistsAcrossStores() throws {
        let suiteName = "quickwheel.tests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(userDefaults: userDefaults, storageKey: "settings", cycleStorageKey: "cycles")
        let slotID = UUID()

        XCTAssertEqual(store.advanceCycle(forSlotID: slotID, stepCount: 3), 0)
        XCTAssertEqual(store.advanceCycle(forSlotID: slotID, stepCount: 3), 1)
        XCTAssertEqual(store.cycleIndex(forSlotID: slotID, stepCount: 3), 2)

        // A fresh store on the same defaults resumes from the persisted position.
        let reloadedStore = SettingsStore(userDefaults: userDefaults, storageKey: "settings", cycleStorageKey: "cycles")
        XCTAssertEqual(reloadedStore.advanceCycle(forSlotID: slotID, stepCount: 3), 2)
        XCTAssertEqual(reloadedStore.advanceCycle(forSlotID: slotID, stepCount: 3), 0)

        // Single-step slots never advance.
        XCTAssertEqual(reloadedStore.advanceCycle(forSlotID: UUID(), stepCount: 1), 0)
    }

    func testLayerIndexSelectionClampsHeldDigit() {
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: nil, layerCount: 3), 0)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 1, layerCount: 3), 0)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 2, layerCount: 3), 1)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 3, layerCount: 3), 2)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 3, layerCount: 2), 1)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 2, layerCount: 0), 0)

        // Digits 4–9 reach the expanded layer range, and clamp when fewer layers exist.
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 9, layerCount: 9), 8)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 7, layerCount: 9), 6)
        XCTAssertEqual(InputController.layerIndex(forHeldDigit: 9, layerCount: 3), 2)
    }

    func testActionIconImagePathRoundTrips() throws {
        var action = QuickwheelAction()
        action.kind = .openURL
        action.urlString = "https://example.com"
        action.iconImagePath = "Icons/example.png"

        let data = try JSONEncoder().encode(action)
        let decoded = try JSONDecoder().decode(QuickwheelAction.self, from: data)

        XCTAssertEqual(decoded.iconImagePath, "Icons/example.png")
    }

    func testIconStoreResolvesAbsoluteAndRelativePaths() {
        let absoluteURL = QuickwheelIconStore.resolvedURL(forIconPath: "/tmp/icon.png")
        XCTAssertEqual(absoluteURL.path, "/tmp/icon.png")

        let relativeURL = QuickwheelIconStore.resolvedURL(forIconPath: "Icons/icon.png")
        XCTAssertEqual(
            relativeURL.path,
            QuickwheelConfigurationFiles.directoryURL.appendingPathComponent("Icons/icon.png").path
        )
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

        // Bare-action slot overrides land on layer 1.
        XCTAssertEqual(settings.layers[0].right.steps.count, 1)
        XCTAssertEqual(settings.layers[0].right.primaryAction.title, "AI Chat")
    }

    func testConfigurationDocumentCanMergeMultiStepSlot() throws {
        let json = """
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
        """

        let settings = try QuickwheelConfigurationCodec.decodeSettings(
            from: Data(json.utf8),
            currentSettings: .defaults
        )

        XCTAssertEqual(settings.layers[0].up.steps.count, 2)
        XCTAssertEqual(settings.layers[0].up.steps[0].title, "Start Recording")
        XCTAssertEqual(settings.layers[0].up.steps[1].title, "Stop Recording")
        XCTAssertEqual(settings.layers[0].down.primaryAction.title, "Paste")
    }

    func testTriggerModifierCodableRoundTrip() throws {
        var settings = QuickwheelSettings.defaults
        settings.triggerModifier = .rightControl

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(QuickwheelSettings.self, from: data)

        XCTAssertEqual(decoded.triggerModifier, .rightControl)
    }
}
