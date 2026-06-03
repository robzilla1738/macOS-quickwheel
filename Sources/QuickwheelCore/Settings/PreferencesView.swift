import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var selectedDirection: WheelDirection = .up

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    globalSettings
                    selectedActionEditor
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wheel")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 16)

            VStack(spacing: 6) {
                ForEach(WheelDirection.allCases) { direction in
                    SlotSidebarButton(
                        direction: direction,
                        action: settingsStore.settings.action(for: direction),
                        isSelected: selectedDirection == direction
                    ) {
                        selectedDirection = direction
                    }
                }
            }
            .padding(.horizontal, 8)

            Divider()
                .padding(.vertical, 4)

            Menu {
                ForEach(QuickwheelPreset.starterSets) { preset in
                    Button {
                        loadPreset(preset)
                    } label: {
                        Label(preset.name, systemImage: preset.symbolName)
                    }
                }
            } label: {
                Label("Load Starter Set", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.button)
            .padding(.horizontal, 12)

            Button(role: .destructive) {
                settingsStore.resetToDefaults()
            } label: {
                Label("Reset Wheel", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .frame(width: 210)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Customize Quickwheel")
                .font(.title2.weight(.semibold))
            Text("Hold \(settingsStore.settings.triggerModifier.displayName), click, drag into a slot, then release to run it.")
                .foregroundStyle(.secondary)
        }
    }

    private var globalSettings: some View {
        SettingsSection(title: "Behavior") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Quickwheel", isOn: settingsBinding(\.isEnabled))

                Picker("Activation shortcut", selection: settingsBinding(\.triggerModifier)) {
                    ForEach(TriggerModifier.allCases) { triggerModifier in
                        Text(triggerModifier.shortcutDescription).tag(triggerModifier)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 320, alignment: .leading)

                HStack(spacing: 14) {
                    SymbolField(
                        title: "Menu bar icon",
                        text: settingsBinding(\.menuBarSymbolName)
                    )

                    SymbolField(
                        title: "Center icon",
                        text: settingsBinding(\.centerSymbolName)
                    )
                }

                Toggle("Show selected slot label", isOn: settingsBinding(\.showOverlayLabels))

                SliderRow(
                    title: "Dead zone",
                    value: settingsBinding(\.deadZoneRadius),
                    range: 12...120,
                    suffix: "pt"
                )

                SliderRow(
                    title: "Wheel size",
                    value: settingsBinding(\.overlaySize),
                    range: 144...260,
                    suffix: "pt"
                )
            }
        }
    }

    private var selectedActionEditor: some View {
        SettingsSection(title: "\(selectedDirection.displayName) Slot") {
            ActionEditor(
                direction: selectedDirection,
                action: actionBinding(for: selectedDirection)
            )
        }
    }

    private func settingsBinding<Value>(_ keyPath: WritableKeyPath<QuickwheelSettings, Value>) -> Binding<Value> {
        Binding(
            get: {
                settingsStore.settings[keyPath: keyPath]
            },
            set: { newValue in
                settingsStore.update { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func actionBinding(for direction: WheelDirection) -> Binding<QuickwheelAction> {
        Binding(
            get: {
                settingsStore.settings.action(for: direction)
            },
            set: { newValue in
                settingsStore.updateAction(newValue, for: direction)
            }
        )
    }

    private func loadPreset(_ preset: QuickwheelPreset) {
        settingsStore.update { settings in
            settings.up = preset.settings.up
            settings.down = preset.settings.down
            settings.left = preset.settings.left
            settings.right = preset.settings.right
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct SlotSidebarButton: View {
    let direction: WheelDirection
    let action: QuickwheelAction
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                SlotSidebarIcon(
                    action: action,
                    direction: direction,
                    isSelected: isSelected
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.resolvedTitle(fallback: direction))
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(action.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.14) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SlotSidebarIcon: View {
    let action: QuickwheelAction
    let direction: WheelDirection
    let isSelected: Bool

    var body: some View {
        Group {
            if let image = QuickwheelActionIconResolver.image(for: action) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Image(systemName: QuickwheelActionIconResolver.symbolName(for: action, fallback: direction))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .frame(width: 22, height: 22)
    }
}

private struct ActionEditor: View {
    let direction: WheelDirection
    @Binding var action: QuickwheelAction

    private let actionTemplates: [QuickwheelAction] = [
        QuickwheelAction(title: "Open Website", iconName: "safari", kind: .openURL, urlString: "https://"),
        QuickwheelAction(title: "Open File", iconName: "", kind: .openFile),
        QuickwheelAction(title: "Reveal File", iconName: "", kind: .revealInFinder),
        QuickwheelAction(title: "Launch App", iconName: "", kind: .launchApp),
        QuickwheelAction(title: "Run Command", iconName: "terminal", kind: .shellCommand),
        QuickwheelAction(title: "Run Script", iconName: "scroll", kind: .appleScript),
        QuickwheelAction(title: "Paste Text", iconName: "text.cursor", kind: .pasteText),
        QuickwheelAction(title: "Shortcut", iconName: "keyboard", kind: .keyboardShortcut),
        QuickwheelAction(title: "Command Palette", iconName: "command", kind: .keyboardShortcut, shortcutKey: "cmd+shift+p"),
        QuickwheelAction(title: "Quick Open", iconName: "doc.text.magnifyingglass", kind: .keyboardShortcut, shortcutKey: "cmd+p"),
        QuickwheelAction(title: "Inline AI Edit", iconName: "wand.and.sparkles", kind: .keyboardShortcut, shortcutKey: "cmd+k"),
        QuickwheelAction(title: "AI Chat", iconName: "sparkles", kind: .keyboardShortcut, shortcutKey: "cmd+l")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(direction.displayName, text: $action.title)
                        .textFieldStyle(.roundedBorder)
                }

                SymbolField(title: "Icon", text: $action.iconName, allowsAutomaticIcon: true)
                    .frame(width: 210)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Template")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Menu {
                        ForEach(actionTemplates) { template in
                            Button {
                                action = template
                            } label: {
                                Label(template.title, systemImage: template.resolvedSymbol(fallback: direction))
                            }
                        }
                    } label: {
                        Label("Load Action", systemImage: "square.and.arrow.down")
                    }
                    .menuStyle(.button)
                }
            }

            Picker("Action Type", selection: $action.kind) {
                ForEach(ActionKind.allCases) { kind in
                    Label(kind.displayName, systemImage: kind.symbolName)
                        .tag(kind)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 260, alignment: .leading)

            actionFields

            HStack(spacing: 8) {
                Image(systemName: action.isRunnable ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(action.isRunnable ? .green : .secondary)
                Text(action.summary.isEmpty ? "No details set" : action.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(direction.displayName) action")
    }

    @ViewBuilder
    private var actionFields: some View {
        switch action.kind {
        case .none:
            Text("This slot will cancel without running anything.")
                .foregroundStyle(.secondary)

        case .openURL:
            TextField("https://example.com", text: $action.urlString)
                .textFieldStyle(.roundedBorder)

        case .openFile, .revealInFinder:
            PathField(path: $action.filePath)

        case .launchApp:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("com.apple.Safari", text: $action.bundleIdentifier)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose App...") {
                        chooseApplication()
                    }
                }
                Text("Use the bundle identifier for the app you want this slot to launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .shellCommand:
            VStack(alignment: .leading, spacing: 8) {
                TextField("zsh command", text: $action.shellCommand)
                    .textFieldStyle(.roundedBorder)
                Text("Commands run with /bin/zsh -lc in the background.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .appleScript:
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $action.appleScript)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                Text("AppleScript runs in the background. Keep scripts short for flick actions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .pasteText:
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $action.text)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                Text("Quickwheel temporarily uses the clipboard, sends Command-V, then restores the previous pasteboard contents.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .keyboardShortcut:
            KeyboardShortcutEditor(action: $action)
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        if let bundleIdentifier = Bundle(url: url)?.bundleIdentifier {
            action.bundleIdentifier = bundleIdentifier
        }

        if action.title.trimmedForQuickwheel.isEmpty {
            action.title = url.deletingPathExtension().lastPathComponent
        }

        if action.iconName.trimmedForQuickwheel == ActionKind.launchApp.symbolName {
            action.iconName = ""
        }
    }
}

private struct PathField: View {
    @Binding var path: String

    var body: some View {
        HStack {
            TextField("~/Desktop/example.txt", text: $path)
                .textFieldStyle(.roundedBorder)
            Button("Choose...") {
                choosePath()
            }
        }
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.title = "Choose File or Folder"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        path = url.path
    }
}

private struct KeyboardShortcutEditor: View {
    @Binding var action: QuickwheelAction
    @State private var shortcutDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("cmd+shift+p", text: $shortcutDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(applyShortcutDraft)

                Button("Apply") {
                    applyShortcutDraft()
                }
                .disabled(shortcutDraft.trimmedForQuickwheel.isEmpty)
            }
            .onAppear {
                shortcutDraft = action.shortcutKey.trimmedForQuickwheel.isEmpty
                    ? QuickwheelShortcutParser.normalizedDisplayName(
                        keyCode: action.shortcutKeyCode,
                        modifiers: action.shortcutModifiers
                    )
                    : action.shortcutKey
            }
            .onChange(of: action.id) { _ in
                shortcutDraft = action.shortcutKey
            }

            HStack(spacing: 12) {
                TextField(
                    "Key code",
                    value: $action.shortcutKeyCode,
                    format: .number
                )
                .frame(width: 96)
                .textFieldStyle(.roundedBorder)

                Toggle("Command", isOn: modifierBinding(.command))
                Toggle("Shift", isOn: modifierBinding(.shift))
                Toggle("Option", isOn: modifierBinding(.option))
                Toggle("Control", isOn: modifierBinding(.control))
            }

            Text("Use strings like cmd+shift+p, cmd+k, ctrl+space, option+shift+f, cmd+left, or keyCode:123. The key-code fields remain available for exact macOS virtual key codes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func applyShortcutDraft() {
        let trimmedShortcut = shortcutDraft.trimmedForQuickwheel
        guard let parsedShortcut = QuickwheelShortcutParser.parse(trimmedShortcut) else {
            NSSound.beep()
            return
        }

        action.shortcutKey = trimmedShortcut
        action.shortcutKeyCode = parsedShortcut.keyCode
        action.shortcutModifiers = parsedShortcut.modifiers
    }

    private func modifierBinding(_ modifier: ShortcutModifiers) -> Binding<Bool> {
        Binding(
            get: { action.shortcutModifiers.contains(modifier) },
            set: { isOn in
                if isOn {
                    action.shortcutModifiers.insert(modifier)
                } else {
                    action.shortcutModifiers.remove(modifier)
                }

                action.shortcutKey = QuickwheelShortcutParser.normalizedDisplayName(
                    keyCode: action.shortcutKeyCode,
                    modifiers: action.shortcutModifiers
                )
                shortcutDraft = action.shortcutKey
            }
        )
    }
}

private struct SymbolField: View {
    let title: String
    @Binding var text: String
    var allowsAutomaticIcon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: QuickwheelSymbol.validatedName(text, fallback: "questionmark.circle"))
                    .frame(width: 26)
                    .foregroundStyle(.secondary)

                TextField(allowsAutomaticIcon ? "SF Symbol or blank" : "SF Symbol", text: $text)
                    .textFieldStyle(.roundedBorder)
            }

            if allowsAutomaticIcon {
                Text("Blank uses the target app or file icon when available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value)) \(suffix)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
        }
    }
}
