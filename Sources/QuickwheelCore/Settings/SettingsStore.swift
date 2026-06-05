import Combine
import Carbon.HIToolbox
import Foundation

enum WheelDirection: String, CaseIterable, Codable, Identifiable {
    case up
    case down
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        }
    }

    var symbolName: String {
        switch self {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }
}

enum ActionKind: String, CaseIterable, Codable, Identifiable {
    case none
    case openURL
    case openFile
    case revealInFinder
    case launchApp
    case shellCommand
    case appleScript
    case pasteText
    case keyboardShortcut

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .openURL: "Open URL"
        case .openFile: "Open File or Folder"
        case .revealInFinder: "Reveal in Finder"
        case .launchApp: "Launch App"
        case .shellCommand: "Shell Command"
        case .appleScript: "AppleScript"
        case .pasteText: "Paste Text"
        case .keyboardShortcut: "Keyboard Shortcut"
        }
    }

    var symbolName: String {
        switch self {
        case .none: "slash.circle"
        case .openURL: "safari"
        case .openFile: "doc"
        case .revealInFinder: "folder"
        case .launchApp: "app"
        case .shellCommand: "terminal"
        case .appleScript: "applescript"
        case .pasteText: "text.cursor"
        case .keyboardShortcut: "keyboard"
        }
    }
}

struct ShortcutModifiers: OptionSet, Codable, Hashable {
    let rawValue: Int

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let shift = ShortcutModifiers(rawValue: 1 << 1)
    static let option = ShortcutModifiers(rawValue: 1 << 2)
    static let control = ShortcutModifiers(rawValue: 1 << 3)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func fromAliases(_ aliases: [String]) -> ShortcutModifiers {
        aliases.reduce(into: ShortcutModifiers()) { modifiers, alias in
            switch alias.lowercased() {
            case "cmd", "command", "⌘":
                modifiers.insert(.command)
            case "shift", "⇧":
                modifiers.insert(.shift)
            case "option", "opt", "alt", "⌥":
                modifiers.insert(.option)
            case "control", "ctrl", "ctl", "⌃":
                modifiers.insert(.control)
            default:
                break
            }
        }
    }

    static func isModifierAlias(_ alias: String) -> Bool {
        switch alias.lowercased() {
        case "cmd", "command", "⌘", "shift", "⇧", "option", "opt", "alt", "⌥", "control", "ctrl", "ctl", "⌃":
            true
        default:
            false
        }
    }
}

struct QuickwheelAction: Codable, Equatable, Identifiable {
    var id = UUID()
    var title = ""
    var iconName = ""
    var iconImagePath = ""
    var kind: ActionKind = .none
    var urlString = ""
    var filePath = ""
    var bundleIdentifier = ""
    var shellCommand = ""
    var appleScript = ""
    var text = ""
    var shortcutKey = ""
    var shortcutKeyCode = 49
    var shortcutModifiers: ShortcutModifiers = [.command]

    var isRunnable: Bool {
        switch kind {
        case .none:
            false
        case .openURL:
            !urlString.trimmedForQuickwheel.isEmpty
        case .openFile, .revealInFinder:
            !filePath.trimmedForQuickwheel.isEmpty
        case .launchApp:
            !bundleIdentifier.trimmedForQuickwheel.isEmpty
        case .shellCommand:
            !shellCommand.trimmedForQuickwheel.isEmpty
        case .appleScript:
            !appleScript.trimmedForQuickwheel.isEmpty
        case .pasteText:
            !text.isEmpty
        case .keyboardShortcut:
            shortcutKey.trimmedForQuickwheel.isEmpty || QuickwheelShortcutParser.parse(shortcutKey) != nil
        }
    }

    func resolvedTitle(fallback direction: WheelDirection) -> String {
        let trimmedTitle = title.trimmedForQuickwheel
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return direction.displayName
    }

    func resolvedSymbol(fallback direction: WheelDirection) -> String {
        let trimmedIconName = iconName.trimmedForQuickwheel
        if !trimmedIconName.isEmpty {
            return trimmedIconName
        }

        if kind == .none {
            return direction.symbolName
        }

        return kind.symbolName
    }

    var summary: String {
        switch kind {
        case .none:
            "No action"
        case .openURL:
            urlString.trimmedForQuickwheel
        case .openFile:
            filePath.trimmedForQuickwheel
        case .revealInFinder:
            filePath.trimmedForQuickwheel
        case .launchApp:
            bundleIdentifier.trimmedForQuickwheel
        case .shellCommand:
            shellCommand.trimmedForQuickwheel
        case .appleScript:
            appleScript.trimmedForQuickwheel.singleLinePreview
        case .pasteText:
            text.singleLinePreview
        case .keyboardShortcut:
            shortcutDescription
        }
    }

    var shortcutDescription: String {
        if !shortcutKey.trimmedForQuickwheel.isEmpty {
            return shortcutKey.trimmedForQuickwheel
        }

        let modifiers = shortcutModifiers.displayName
        if modifiers.isEmpty {
            return "Key code \(shortcutKeyCode)"
        }

        return "\(modifiers) + key code \(shortcutKeyCode)"
    }

    init() {}

    init(
        title: String,
        iconName: String,
        kind: ActionKind,
        iconImagePath: String = "",
        urlString: String = "",
        filePath: String = "",
        bundleIdentifier: String = "",
        shellCommand: String = "",
        appleScript: String = "",
        text: String = "",
        shortcutKey: String = "",
        shortcutKeyCode: Int = 49,
        shortcutModifiers: ShortcutModifiers = [.command]
    ) {
        self.title = title
        self.iconName = iconName
        self.iconImagePath = iconImagePath
        self.kind = kind
        self.urlString = urlString
        self.filePath = filePath
        self.bundleIdentifier = bundleIdentifier
        self.shellCommand = shellCommand
        self.appleScript = appleScript
        self.text = text
        self.shortcutKey = shortcutKey
        self.shortcutKeyCode = shortcutKeyCode
        self.shortcutModifiers = shortcutModifiers

        if !shortcutKey.trimmedForQuickwheel.isEmpty,
           let parsedShortcut = QuickwheelShortcutParser.parse(shortcutKey) {
            self.shortcutKeyCode = parsedShortcut.keyCode
            self.shortcutModifiers = parsedShortcut.modifiers
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case iconName
        case iconImagePath
        case kind
        case urlString
        case filePath
        case bundleIdentifier
        case shellCommand
        case appleScript
        case text
        case shortcutKey
        case shortcutKeyCode
        case shortcutModifiers
    }

    private enum AliasCodingKeys: String, CodingKey {
        case shortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let aliasContainer = try decoder.container(keyedBy: AliasCodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? ""
        iconImagePath = try container.decodeIfPresent(String.self, forKey: .iconImagePath) ?? ""
        kind = try container.decodeIfPresent(ActionKind.self, forKey: .kind) ?? .none
        urlString = try container.decodeIfPresent(String.self, forKey: .urlString) ?? ""
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath) ?? ""
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? ""
        shellCommand = try container.decodeIfPresent(String.self, forKey: .shellCommand) ?? ""
        appleScript = try container.decodeIfPresent(String.self, forKey: .appleScript) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        shortcutKey = try container.decodeIfPresent(String.self, forKey: .shortcutKey)
            ?? aliasContainer.decodeIfPresent(String.self, forKey: .shortcut)
            ?? ""
        shortcutKeyCode = try container.decodeIfPresent(Int.self, forKey: .shortcutKeyCode) ?? 49
        shortcutModifiers = try container.decodeIfPresent(ShortcutModifiers.self, forKey: .shortcutModifiers) ?? [.command]

        if !shortcutKey.trimmedForQuickwheel.isEmpty,
           let parsedShortcut = QuickwheelShortcutParser.parse(shortcutKey) {
            shortcutKeyCode = parsedShortcut.keyCode
            shortcutModifiers = parsedShortcut.modifiers
        }
    }
}

struct QuickwheelSlot: Codable, Equatable, Identifiable {
    /// Maximum sequential steps a slot can cycle through on repeated triggers.
    static let maxSteps = 4

    var id = UUID()
    var steps: [QuickwheelAction] = [QuickwheelAction()]

    var primaryAction: QuickwheelAction {
        steps.first ?? QuickwheelAction()
    }

    var isRunnable: Bool {
        steps.contains { $0.isRunnable }
    }

    init() {}

    init(action: QuickwheelAction) {
        steps = [action]
    }

    init(steps: [QuickwheelAction]) {
        self.steps = steps.isEmpty ? [QuickwheelAction()] : steps
    }

    func step(at index: Int) -> QuickwheelAction {
        guard steps.indices.contains(index) else { return primaryAction }
        return steps[index]
    }

    mutating func clampSteps() {
        if steps.isEmpty {
            steps = [QuickwheelAction()]
        } else if steps.count > Self.maxSteps {
            steps = Array(steps.prefix(Self.maxSteps))
        }
    }

    /// A copy with fresh identities, for loading shared presets/templates so
    /// slots never collide on id (used for SwiftUI identity and cycle state).
    func withRegeneratedIDs() -> QuickwheelSlot {
        var slot = self
        slot.id = UUID()
        slot.steps = slot.steps.map { step in
            var step = step
            step.id = UUID()
            return step
        }
        return slot
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case steps
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self), container.contains(.steps) {
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            let decodedSteps = try container.decodeIfPresent([QuickwheelAction].self, forKey: .steps) ?? []
            steps = decodedSteps.isEmpty ? [QuickwheelAction()] : decodedSteps
        } else {
            let action = try QuickwheelAction(from: decoder)
            id = UUID()
            steps = [action]
        }
    }
}

struct WheelLayer: Codable, Equatable, Identifiable {
    var id = UUID()
    var name = ""
    var up = QuickwheelSlot()
    var down = QuickwheelSlot()
    var left = QuickwheelSlot()
    var right = QuickwheelSlot()

    var hasRunnableSlot: Bool {
        WheelDirection.allCases.contains { slot(for: $0).isRunnable }
    }

    init() {}

    init(
        name: String = "",
        up: QuickwheelAction = QuickwheelAction(),
        down: QuickwheelAction = QuickwheelAction(),
        left: QuickwheelAction = QuickwheelAction(),
        right: QuickwheelAction = QuickwheelAction()
    ) {
        self.name = name
        self.up = QuickwheelSlot(action: up)
        self.down = QuickwheelSlot(action: down)
        self.left = QuickwheelSlot(action: left)
        self.right = QuickwheelSlot(action: right)
    }

    func slot(for direction: WheelDirection) -> QuickwheelSlot {
        switch direction {
        case .up: up
        case .down: down
        case .left: left
        case .right: right
        }
    }

    mutating func setSlot(_ slot: QuickwheelSlot, for direction: WheelDirection) {
        switch direction {
        case .up:
            up = slot
        case .down:
            down = slot
        case .left:
            left = slot
        case .right:
            right = slot
        }
    }

    mutating func setStep(_ action: QuickwheelAction, at index: Int, for direction: WheelDirection) {
        var updatedSlot = slot(for: direction)
        guard updatedSlot.steps.indices.contains(index) else { return }
        updatedSlot.steps[index] = action
        setSlot(updatedSlot, for: direction)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case up
        case down
        case left
        case right
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        up = try container.decodeIfPresent(QuickwheelSlot.self, forKey: .up) ?? QuickwheelSlot()
        down = try container.decodeIfPresent(QuickwheelSlot.self, forKey: .down) ?? QuickwheelSlot()
        left = try container.decodeIfPresent(QuickwheelSlot.self, forKey: .left) ?? QuickwheelSlot()
        right = try container.decodeIfPresent(QuickwheelSlot.self, forKey: .right) ?? QuickwheelSlot()
    }
}

enum TriggerModifier: String, CaseIterable, Codable, Identifiable {
    case leftCommand
    case rightCommand
    case eitherCommand
    case leftOption
    case rightOption
    case eitherOption
    case leftControl
    case rightControl
    case eitherControl
    case leftShift
    case rightShift
    case eitherShift

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftCommand: "Left Command"
        case .rightCommand: "Right Command"
        case .eitherCommand: "Either Command"
        case .leftOption: "Left Option"
        case .rightOption: "Right Option"
        case .eitherOption: "Either Option"
        case .leftControl: "Left Control"
        case .rightControl: "Right Control"
        case .eitherControl: "Either Control"
        case .leftShift: "Left Shift"
        case .rightShift: "Right Shift"
        case .eitherShift: "Either Shift"
        }
    }

    var shortcutDescription: String {
        "\(displayName) + left click"
    }

    var matchingKeyCodes: Set<Int64> {
        switch self {
        case .leftCommand:
            [Int64(kVK_Command)]
        case .rightCommand:
            [Int64(kVK_RightCommand)]
        case .eitherCommand:
            [Int64(kVK_Command), Int64(kVK_RightCommand)]
        case .leftOption:
            [Int64(kVK_Option)]
        case .rightOption:
            [Int64(kVK_RightOption)]
        case .eitherOption:
            [Int64(kVK_Option), Int64(kVK_RightOption)]
        case .leftControl:
            [Int64(kVK_Control)]
        case .rightControl:
            [Int64(kVK_RightControl)]
        case .eitherControl:
            [Int64(kVK_Control), Int64(kVK_RightControl)]
        case .leftShift:
            [Int64(kVK_Shift)]
        case .rightShift:
            [Int64(kVK_RightShift)]
        case .eitherShift:
            [Int64(kVK_Shift), Int64(kVK_RightShift)]
        }
    }

    static var allKeyCodes: Set<Int64> {
        Set(allCases.flatMap(\.matchingKeyCodes))
    }
}

struct QuickwheelSettings: Codable, Equatable {
    static let layerCount = 9

    var isEnabled = true
    var triggerModifier = TriggerModifier.leftCommand
    var menuBarSymbolName = "command.circle"
    var centerSymbolName = "command"
    var deadZoneRadius = 36.0
    var overlaySize = 184.0
    var showOverlayLabels = false
    var layers: [WheelLayer] = [WheelLayer(), WheelLayer(), WheelLayer()]

    var up: QuickwheelAction {
        get { action(for: .up) }
        set { setAction(newValue, for: .up) }
    }

    var down: QuickwheelAction {
        get { action(for: .down) }
        set { setAction(newValue, for: .down) }
    }

    var left: QuickwheelAction {
        get { action(for: .left) }
        set { setAction(newValue, for: .left) }
    }

    var right: QuickwheelAction {
        get { action(for: .right) }
        set { setAction(newValue, for: .right) }
    }

    static let defaults = QuickwheelSettings(
        up: QuickwheelAction(
            title: "Search",
            iconName: "magnifyingglass",
            kind: .keyboardShortcut,
            shortcutKey: "cmd+f",
            shortcutKeyCode: 3,
            shortcutModifiers: [.command]
        ),
        down: QuickwheelAction(
            title: "Paste",
            iconName: "doc.on.clipboard",
            kind: .keyboardShortcut,
            shortcutKey: "cmd+v",
            shortcutKeyCode: 9,
            shortcutModifiers: [.command]
        ),
        left: QuickwheelAction(
            title: "Back",
            iconName: "chevron.left",
            kind: .keyboardShortcut,
            shortcutKey: "cmd+left",
            shortcutKeyCode: 123,
            shortcutModifiers: [.command]
        ),
        right: QuickwheelAction(
            title: "Forward",
            iconName: "chevron.right",
            kind: .keyboardShortcut,
            shortcutKey: "cmd+right",
            shortcutKeyCode: 124,
            shortcutModifiers: [.command]
        )
    )

    func action(for direction: WheelDirection) -> QuickwheelAction {
        slot(layerIndex: 0, direction: direction).primaryAction
    }

    func slot(layerIndex: Int, direction: WheelDirection) -> QuickwheelSlot {
        guard layers.indices.contains(layerIndex) else { return QuickwheelSlot() }
        return layers[layerIndex].slot(for: direction)
    }

    func clampedLayerIndex(_ layerIndex: Int) -> Int {
        guard layers.indices.contains(layerIndex) else { return 0 }
        return layerIndex
    }

    var usesMultipleLayers: Bool {
        layers.dropFirst().contains { $0.hasRunnableSlot }
    }

    mutating func setAction(_ action: QuickwheelAction, for direction: WheelDirection) {
        setAction(action, layerIndex: 0, for: direction)
    }

    mutating func setAction(_ action: QuickwheelAction, layerIndex: Int, for direction: WheelDirection) {
        guard layers.indices.contains(layerIndex) else { return }
        var updatedSlot = layers[layerIndex].slot(for: direction)
        if updatedSlot.steps.isEmpty {
            updatedSlot.steps = [action]
        } else {
            updatedSlot.steps[0] = action
        }
        layers[layerIndex].setSlot(updatedSlot, for: direction)
    }

    mutating func clampEditableValues() {
        deadZoneRadius = min(max(deadZoneRadius, 12), 120)
        overlaySize = min(max(overlaySize, 144), 260)

        if menuBarSymbolName.trimmedForQuickwheel.isEmpty {
            menuBarSymbolName = "command.circle"
        }

        if centerSymbolName.trimmedForQuickwheel.isEmpty {
            centerSymbolName = "command"
        }

        clampLayers()
    }

    private mutating func clampLayers() {
        if layers.count > Self.layerCount {
            layers = Array(layers.prefix(Self.layerCount))
        }

        while layers.count < Self.layerCount {
            layers.append(WheelLayer())
        }

        for index in layers.indices {
            if layers[index].name.trimmedForQuickwheel.isEmpty {
                layers[index].name = "Layer \(index + 1)"
            }

            for direction in WheelDirection.allCases {
                var slot = layers[index].slot(for: direction)
                slot.clampSteps()
                layers[index].setSlot(slot, for: direction)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case triggerModifier
        case menuBarSymbolName
        case centerSymbolName
        case deadZoneRadius
        case overlaySize
        case showOverlayLabels
        case layers
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case up
        case down
        case left
        case right
    }

    init(
        isEnabled: Bool = true,
        triggerModifier: TriggerModifier = .leftCommand,
        menuBarSymbolName: String = "command.circle",
        centerSymbolName: String = "command",
        deadZoneRadius: Double = 36,
        overlaySize: Double = 184,
        showOverlayLabels: Bool = false,
        up: QuickwheelAction = QuickwheelAction(),
        down: QuickwheelAction = QuickwheelAction(),
        left: QuickwheelAction = QuickwheelAction(),
        right: QuickwheelAction = QuickwheelAction()
    ) {
        self.isEnabled = isEnabled
        self.triggerModifier = triggerModifier
        self.menuBarSymbolName = menuBarSymbolName
        self.centerSymbolName = centerSymbolName
        self.deadZoneRadius = deadZoneRadius
        self.overlaySize = overlaySize
        self.showOverlayLabels = showOverlayLabels
        self.layers = [
            WheelLayer(up: up, down: down, left: left, right: right),
            WheelLayer(),
            WheelLayer()
        ]
        clampEditableValues()
    }

    init(
        isEnabled: Bool = true,
        triggerModifier: TriggerModifier = .leftCommand,
        menuBarSymbolName: String = "command.circle",
        centerSymbolName: String = "command",
        deadZoneRadius: Double = 36,
        overlaySize: Double = 184,
        showOverlayLabels: Bool = false,
        layers: [WheelLayer]
    ) {
        self.isEnabled = isEnabled
        self.triggerModifier = triggerModifier
        self.menuBarSymbolName = menuBarSymbolName
        self.centerSymbolName = centerSymbolName
        self.deadZoneRadius = deadZoneRadius
        self.overlaySize = overlaySize
        self.showOverlayLabels = showOverlayLabels
        self.layers = layers
        clampEditableValues()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        triggerModifier = try container.decodeIfPresent(TriggerModifier.self, forKey: .triggerModifier) ?? .leftCommand
        menuBarSymbolName = try container.decodeIfPresent(String.self, forKey: .menuBarSymbolName) ?? "command.circle"
        centerSymbolName = try container.decodeIfPresent(String.self, forKey: .centerSymbolName) ?? "command"
        deadZoneRadius = try container.decodeIfPresent(Double.self, forKey: .deadZoneRadius) ?? 36
        overlaySize = try container.decodeIfPresent(Double.self, forKey: .overlaySize) ?? 184
        showOverlayLabels = try container.decodeIfPresent(Bool.self, forKey: .showOverlayLabels) ?? false

        if let decodedLayers = try container.decodeIfPresent([WheelLayer].self, forKey: .layers), !decodedLayers.isEmpty {
            layers = decodedLayers
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            var firstLayer = WheelLayer()
            firstLayer.up = QuickwheelSlot(
                action: try legacyContainer.decodeIfPresent(QuickwheelAction.self, forKey: .up) ?? QuickwheelAction()
            )
            firstLayer.down = QuickwheelSlot(
                action: try legacyContainer.decodeIfPresent(QuickwheelAction.self, forKey: .down) ?? QuickwheelAction()
            )
            firstLayer.left = QuickwheelSlot(
                action: try legacyContainer.decodeIfPresent(QuickwheelAction.self, forKey: .left) ?? QuickwheelAction()
            )
            firstLayer.right = QuickwheelSlot(
                action: try legacyContainer.decodeIfPresent(QuickwheelAction.self, forKey: .right) ?? QuickwheelAction()
            )
            layers = [firstLayer, WheelLayer(), WheelLayer()]
        }

        clampEditableValues()
    }
}

final class SettingsStore: ObservableObject {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let cycleStorageKey: String

    @Published private(set) var settings: QuickwheelSettings

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "quickwheel.settings.v1",
        cycleStorageKey: String = "quickwheel.cycleIndices.v1"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.cycleStorageKey = cycleStorageKey
        settings = Self.loadSettings(from: userDefaults, key: storageKey)
    }

    func updateAction(_ action: QuickwheelAction, for direction: WheelDirection) {
        var updatedSettings = settings
        updatedSettings.setAction(action, for: direction)
        replaceSettings(updatedSettings)
    }

    func cycleIndex(forSlotID slotID: UUID, stepCount: Int) -> Int {
        guard stepCount > 1 else { return 0 }
        let storedIndex = cycleIndices()[slotID.uuidString] ?? 0
        return ((storedIndex % stepCount) + stepCount) % stepCount
    }

    @discardableResult
    func advanceCycle(forSlotID slotID: UUID, stepCount: Int) -> Int {
        guard stepCount > 1 else { return 0 }
        let index = cycleIndex(forSlotID: slotID, stepCount: stepCount)
        var indices = cycleIndices()
        indices[slotID.uuidString] = (index + 1) % stepCount
        userDefaults.set(indices, forKey: cycleStorageKey)
        return index
    }

    private func cycleIndices() -> [String: Int] {
        (userDefaults.dictionary(forKey: cycleStorageKey) ?? [:]).compactMapValues { $0 as? Int }
    }

    func update(_ edit: (inout QuickwheelSettings) -> Void) {
        var updatedSettings = settings
        edit(&updatedSettings)
        replaceSettings(updatedSettings)
    }

    func replaceSettings(_ newSettings: QuickwheelSettings) {
        var sanitizedSettings = newSettings
        sanitizedSettings.clampEditableValues()
        settings = sanitizedSettings
        save()
    }

    func resetToDefaults() {
        replaceSettings(.defaults)
    }

    func encodedSettings() throws -> Data {
        try QuickwheelConfigurationCodec.encodeDocument(settings: settings)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func loadSettings(from userDefaults: UserDefaults, key: String) -> QuickwheelSettings {
        guard
            let data = userDefaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(QuickwheelSettings.self, from: data)
        else {
            return .defaults
        }

        return decoded
    }
}

extension ShortcutModifiers {
    var displayName: String {
        var parts: [String] = []

        if contains(.control) {
            parts.append("Control")
        }

        if contains(.option) {
            parts.append("Option")
        }

        if contains(.shift) {
            parts.append("Shift")
        }

        if contains(.command) {
            parts.append("Command")
        }

        return parts.joined(separator: " + ")
    }
}

struct QuickwheelPreset: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    let settings: QuickwheelSettings

    static let starterSets: [QuickwheelPreset] = [
        QuickwheelPreset(
            id: "browser",
            name: "Browser Navigation",
            symbolName: "safari",
            settings: QuickwheelSettings(
                up: QuickwheelAction(
                    title: "Find",
                    iconName: "magnifyingglass",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+f",
                    shortcutKeyCode: 3,
                    shortcutModifiers: [.command]
                ),
                down: QuickwheelAction(
                    title: "New Tab",
                    iconName: "plus.square.on.square",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+t",
                    shortcutKeyCode: 17,
                    shortcutModifiers: [.command]
                ),
                left: QuickwheelAction(
                    title: "Back",
                    iconName: "chevron.left",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+left",
                    shortcutKeyCode: 123,
                    shortcutModifiers: [.command]
                ),
                right: QuickwheelAction(
                    title: "Forward",
                    iconName: "chevron.right",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+right",
                    shortcutKeyCode: 124,
                    shortcutModifiers: [.command]
                )
            )
        ),
        QuickwheelPreset(
            id: "writing",
            name: "Writing",
            symbolName: "text.cursor",
            settings: QuickwheelSettings(
                up: QuickwheelAction(
                    title: "Paste Date",
                    iconName: "calendar",
                    kind: .shellCommand,
                    shellCommand: "date '+%Y-%m-%d' | pbcopy"
                ),
                down: QuickwheelAction(
                    title: "Paste Thanks",
                    iconName: "text.quote",
                    kind: .pasteText,
                    text: "Thanks,"
                ),
                left: QuickwheelAction(
                    title: "Undo",
                    iconName: "arrow.uturn.backward",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+z",
                    shortcutKeyCode: 6,
                    shortcutModifiers: [.command]
                ),
                right: QuickwheelAction(
                    title: "Redo",
                    iconName: "arrow.uturn.forward",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+shift+z",
                    shortcutKeyCode: 6,
                    shortcutModifiers: [.command, .shift]
                )
            )
        ),
        QuickwheelPreset(
            id: "ide-ai",
            name: "IDE / AI Coding",
            symbolName: "sparkles",
            settings: QuickwheelSettings(
                up: QuickwheelAction(
                    title: "Command Palette",
                    iconName: "command",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+shift+p"
                ),
                down: QuickwheelAction(
                    title: "Quick Open",
                    iconName: "doc.text.magnifyingglass",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+p"
                ),
                left: QuickwheelAction(
                    title: "Inline AI Edit",
                    iconName: "wand.and.sparkles",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+k"
                ),
                right: QuickwheelAction(
                    title: "AI Chat",
                    iconName: "sparkles",
                    kind: .keyboardShortcut,
                    shortcutKey: "cmd+l"
                )
            )
        ),
        QuickwheelPreset(
            id: "apps",
            name: "App Launcher",
            symbolName: "square.grid.2x2",
            settings: QuickwheelSettings(
                up: QuickwheelAction(
                    title: "Safari",
                    iconName: "safari",
                    kind: .launchApp,
                    bundleIdentifier: "com.apple.Safari"
                ),
                down: QuickwheelAction(
                    title: "Finder",
                    iconName: "face.smiling",
                    kind: .launchApp,
                    bundleIdentifier: "com.apple.finder"
                ),
                left: QuickwheelAction(
                    title: "Terminal",
                    iconName: "terminal",
                    kind: .launchApp,
                    bundleIdentifier: "com.apple.Terminal"
                ),
                right: QuickwheelAction(
                    title: "Messages",
                    iconName: "message",
                    kind: .launchApp,
                    bundleIdentifier: "com.apple.MobileSMS"
                )
            )
        )
    ]
}

extension String {
    var trimmedForQuickwheel: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var singleLinePreview: String {
        let collapsed = components(separatedBy: .newlines)
            .map { $0.trimmedForQuickwheel }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > 80 else {
            return collapsed
        }

        return String(collapsed.prefix(77)) + "..."
    }
}
