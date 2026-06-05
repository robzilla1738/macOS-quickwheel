import AppKit
import Combine
import Sparkle
import UniformTypeIdentifiers

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsStore = SettingsStore()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    private lazy var actionRunner = ActionRunner()
    private lazy var overlayController = OverlayWindowController(settingsStore: settingsStore)
    private lazy var preferencesController = PreferencesWindowController(settingsStore: settingsStore)
    private lazy var onboardingController = OnboardingWindowController(
        recheckHandler: { [weak self] in
            self?.checkAccessibilityAndStartInput(prompt: false)
        }
    )

    private var inputController: InputController?
    private var statusItem: NSStatusItem?
    private var settingsCancellable: AnyCancellable?

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ensureConfigurationFolder()
        _ = updaterController
        configureStatusItem()
        settingsCancellable = settingsStore.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildStatusMenu()
                self?.updateStatusItemIcon()
            }
        checkAccessibilityAndStartInput(prompt: true)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        inputController?.stop()
    }

    @objc private func openPreferences(_ sender: Any?) {
        preferencesController.showWindow(nil)
        preferencesController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleEnabled(_ sender: Any?) {
        settingsStore.update { settings in
            settings.isEnabled.toggle()
        }
    }

    @objc private func runDirectionFromMenu(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else { return }

        let components = rawValue.split(separator: ":", maxSplits: 1)
        let layerIndex: Int
        let rawDirection: String

        if components.count == 2, let parsedLayer = Int(components[0]) {
            layerIndex = parsedLayer
            rawDirection = String(components[1])
        } else {
            layerIndex = 0
            rawDirection = rawValue
        }

        guard let direction = WheelDirection(rawValue: rawDirection) else { return }

        let slot = settingsStore.settings.slot(layerIndex: layerIndex, direction: direction)
        let stepIndex = settingsStore.advanceCycle(forSlotID: slot.id, stepCount: slot.steps.count)
        actionRunner.run(slot.step(at: stepIndex))
    }

    @objc private func loadPresetFromMenu(_ sender: NSMenuItem) {
        guard
            let presetID = sender.representedObject as? String,
            let preset = QuickwheelPreset.starterSets.first(where: { $0.id == presetID })
        else {
            return
        }

        settingsStore.update { settings in
            guard !settings.layers.isEmpty else { return }
            let presetLayer = preset.settings.layers.first ?? WheelLayer()
            for direction in WheelDirection.allCases {
                settings.layers[0].setSlot(
                    presetLayer.slot(for: direction).withRegeneratedIDs(),
                    for: direction
                )
            }
        }
    }

    @objc private func importConfiguration(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "Load Quickwheel Configuration"
        panel.message = "Choose a Quickwheel JSON configuration file."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let settings = try QuickwheelConfigurationCodec.decodeSettings(
                from: data,
                currentSettings: settingsStore.settings
            )
            settingsStore.replaceSettings(settings)
        } catch {
            showAlert(
                title: "Could Not Load Configuration",
                message: error.localizedDescription
            )
        }
    }

    @objc private func openConfigurationFolder(_ sender: Any?) {
        do {
            try QuickwheelConfigurationFiles.ensureDirectory(currentSettings: settingsStore.settings)
            NSWorkspace.shared.open(QuickwheelConfigurationFiles.directoryURL)
        } catch {
            showAlert(
                title: "Could Not Open Configuration Folder",
                message: error.localizedDescription
            )
        }
    }

    @objc private func reloadActiveConfiguration(_ sender: Any?) {
        do {
            let settings = try QuickwheelConfigurationFiles.readActiveConfiguration(
                currentSettings: settingsStore.settings
            )
            settingsStore.replaceSettings(settings)
        } catch {
            showAlert(
                title: "Could Not Reload Active Configuration",
                message: error.localizedDescription
            )
        }
    }

    @objc private func saveActiveConfiguration(_ sender: Any?) {
        do {
            try QuickwheelConfigurationFiles.writeActiveConfiguration(settings: settingsStore.settings)
            NSWorkspace.shared.activateFileViewerSelecting([QuickwheelConfigurationFiles.activeConfigurationURL])
        } catch {
            showAlert(
                title: "Could Not Save Active Configuration",
                message: error.localizedDescription
            )
        }
    }

    @objc private func exportConfiguration(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.title = "Save Quickwheel Configuration"
        panel.nameFieldStringValue = "Quickwheel Configuration.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try settingsStore.encodedSettings()
            try data.write(to: url, options: [.atomic])
        } catch {
            showAlert(
                title: "Could Not Save Configuration",
                message: error.localizedDescription
            )
        }
    }

    @objc private func checkAccessibilityFromMenu(_ sender: Any?) {
        checkAccessibilityAndStartInput(prompt: true)
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imagePosition = .imageOnly
        statusItem = item
        updateStatusItemIcon()
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        guard let statusItem else { return }

        let settings = settingsStore.settings
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Quickwheel", action: nil, keyEquivalent: "")
        titleItem.image = statusImage(named: settings.menuBarSymbolName, accessibilityDescription: "Quickwheel")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let enabledItem = NSMenuItem(
            title: "Enable Quickwheel",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = settings.isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let triggerItem = NSMenuItem(
            title: "Trigger: \(settings.triggerModifier.shortcutDescription)",
            action: nil,
            keyEquivalent: ""
        )
        triggerItem.image = statusImage(named: "cursorarrow.click", accessibilityDescription: "Trigger")
        triggerItem.isEnabled = false
        menu.addItem(triggerItem)

        if settings.usesMultipleLayers {
            let layerHintItem = NSMenuItem(
                title: "Hold 1–9 to pick a layer",
                action: nil,
                keyEquivalent: ""
            )
            layerHintItem.image = statusImage(named: "square.3.layers.3d", accessibilityDescription: "Layers")
            layerHintItem.isEnabled = false
            menu.addItem(layerHintItem)
        }

        let runMenu = NSMenu()
        let showsAllLayers = settings.usesMultipleLayers

        for (layerIndex, layer) in settings.layers.enumerated() {
            if layerIndex > 0, !showsAllLayers {
                break
            }

            let directionItems = WheelDirection.allCases.map { direction -> NSMenuItem in
                let slot = layer.slot(for: direction)
                let action = slot.primaryAction
                var title = "\(action.resolvedTitle(fallback: direction)) - \(action.kind.displayName)"
                if slot.steps.count > 1 {
                    title = "\(action.resolvedTitle(fallback: direction)) - \(slot.steps.count) steps"
                }

                let item = NSMenuItem(
                    title: title,
                    action: #selector(runDirectionFromMenu(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = "\(layerIndex):\(direction.rawValue)"
                item.image = statusImage(
                    named: action.resolvedSymbol(fallback: direction),
                    accessibilityDescription: action.resolvedTitle(fallback: direction)
                )
                item.isEnabled = slot.isRunnable
                return item
            }

            if showsAllLayers {
                let layerMenu = NSMenu()
                directionItems.forEach { layerMenu.addItem($0) }
                let layerItem = NSMenuItem(title: layer.name, action: nil, keyEquivalent: "")
                layerItem.image = statusImage(
                    named: "\(layerIndex + 1).circle",
                    accessibilityDescription: layer.name
                )
                layerItem.submenu = layerMenu
                runMenu.addItem(layerItem)
            } else {
                directionItems.forEach { runMenu.addItem($0) }
            }
        }

        let runItem = NSMenuItem(title: "Run Action", action: nil, keyEquivalent: "")
        runItem.submenu = runMenu
        menu.addItem(runItem)

        let presetMenu = NSMenu()
        for preset in QuickwheelPreset.starterSets {
            let item = NSMenuItem(
                title: preset.name,
                action: #selector(loadPresetFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = preset.id
            item.image = statusImage(named: preset.symbolName, accessibilityDescription: preset.name)
            presetMenu.addItem(item)
        }

        let presetItem = NSMenuItem(title: "Load Starter Set", action: nil, keyEquivalent: "")
        presetItem.submenu = presetMenu
        menu.addItem(presetItem)

        menu.addItem(.separator())

        let configFolderMenu = NSMenu()

        let openConfigFolderItem = NSMenuItem(
            title: "Open Configuration Folder",
            action: #selector(openConfigurationFolder(_:)),
            keyEquivalent: ""
        )
        openConfigFolderItem.target = self
        openConfigFolderItem.image = statusImage(named: "folder", accessibilityDescription: "Open Configuration Folder")
        configFolderMenu.addItem(openConfigFolderItem)

        let reloadActiveItem = NSMenuItem(
            title: "Reload active.quickwheel.json",
            action: #selector(reloadActiveConfiguration(_:)),
            keyEquivalent: ""
        )
        reloadActiveItem.target = self
        reloadActiveItem.image = statusImage(named: "arrow.clockwise", accessibilityDescription: "Reload")
        configFolderMenu.addItem(reloadActiveItem)

        let saveActiveItem = NSMenuItem(
            title: "Save Current as active.quickwheel.json",
            action: #selector(saveActiveConfiguration(_:)),
            keyEquivalent: ""
        )
        saveActiveItem.target = self
        saveActiveItem.image = statusImage(named: "square.and.arrow.down.on.square", accessibilityDescription: "Save Active")
        configFolderMenu.addItem(saveActiveItem)

        let configFolderItem = NSMenuItem(title: "Configuration Folder", action: nil, keyEquivalent: "")
        configFolderItem.submenu = configFolderMenu
        menu.addItem(configFolderItem)

        let importItem = NSMenuItem(
            title: "Load Configuration...",
            action: #selector(importConfiguration(_:)),
            keyEquivalent: ""
        )
        importItem.target = self
        importItem.image = statusImage(named: "square.and.arrow.down", accessibilityDescription: "Load")
        menu.addItem(importItem)

        let exportItem = NSMenuItem(
            title: "Save Configuration...",
            action: #selector(exportConfiguration(_:)),
            keyEquivalent: ""
        )
        exportItem.target = self
        exportItem.image = statusImage(named: "square.and.arrow.up", accessibilityDescription: "Save")
        menu.addItem(exportItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(
            title: "Customize Wheel...",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.image = statusImage(named: "slider.horizontal.3", accessibilityDescription: "Customize")
        menu.addItem(preferencesItem)

        let permissionItem = NSMenuItem(
            title: "Check Accessibility Permission",
            action: #selector(checkAccessibilityFromMenu(_:)),
            keyEquivalent: ""
        )
        permissionItem.target = self
        permissionItem.image = statusImage(named: "hand.raised", accessibilityDescription: "Accessibility")
        menu.addItem(permissionItem)

        let updatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updatesItem.target = self
        updatesItem.image = statusImage(named: "arrow.down.circle", accessibilityDescription: "Check for Updates")
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Quickwheel",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }

        button.image = statusImage(
            named: settingsStore.settings.menuBarSymbolName,
            accessibilityDescription: "Quickwheel"
        )
        button.image?.isTemplate = true
        button.toolTip = settingsStore.settings.isEnabled ? "Quickwheel" : "Quickwheel Disabled"
    }

    private func checkAccessibilityAndStartInput(prompt: Bool) {
        guard AccessibilityPermission.isTrusted(prompt: prompt) else {
            inputController?.stop()
            inputController = nil
            onboardingController.showPermissionRequired()
            return
        }

        onboardingController.close()

        if inputController == nil {
            let controller = InputController(
                overlayController: overlayController,
                settingsStore: settingsStore,
                actionRunner: actionRunner
            )
            inputController = controller
        }

        guard inputController?.isRunning != true else { return }

        if inputController?.start() != true {
            onboardingController.showEventTapUnavailable()
        }
    }

    private func ensureConfigurationFolder() {
        do {
            try QuickwheelConfigurationFiles.ensureDirectory(currentSettings: settingsStore.settings)
        } catch {
            NSLog("Quickwheel configuration folder setup failed: \(error.localizedDescription)")
        }
    }

    private func statusImage(named symbolName: String, accessibilityDescription: String) -> NSImage? {
        let image = NSImage(
            systemSymbolName: symbolName.trimmedForQuickwheel,
            accessibilityDescription: accessibilityDescription
        ) ?? NSImage(
            systemSymbolName: "command.circle",
            accessibilityDescription: accessibilityDescription
        )
        image?.isTemplate = true
        return image
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
