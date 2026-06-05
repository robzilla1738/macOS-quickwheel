# Quickwheel Configuration

Quickwheel can be customized through the app UI, the menu-bar import/export commands, or JSON files that external tools write for the user.

The tool-friendly config folder is:

```text
~/Library/Application Support/Quickwheel/
```

Write a config document to:

```text
~/Library/Application Support/Quickwheel/active.quickwheel.json
```

Then choose `Quickwheel > Configuration Folder > Reload active.quickwheel.json` from the menu-bar item.

## Minimal AI/IDE Patch

Use `mode: "merge"` when a tool should update only specific slots and preserve the rest of the user configuration. Slot patches under `slots` apply to Layer 1.

```json
{
  "schemaVersion": 2,
  "name": "IDE AI Shortcuts",
  "mode": "merge",
  "slots": {
    "up": {
      "title": "Command Palette",
      "iconName": "command",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+shift+p"
    },
    "left": {
      "title": "Inline AI Edit",
      "iconName": "wand.and.sparkles",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+k"
    },
    "right": {
      "title": "AI Chat",
      "iconName": "sparkles",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+l"
    }
  }
}
```

## Full Replacement

Use `mode: "replace"` with `settings` when a file should replace the whole wheel.

```json
{
  "schemaVersion": 2,
  "name": "Full Quickwheel Setup",
  "mode": "replace",
  "settings": {
    "isEnabled": true,
    "triggerModifier": "leftCommand",
    "menuBarSymbolName": "command.circle",
    "centerSymbolName": "command",
    "deadZoneRadius": 36,
    "overlaySize": 184,
    "showOverlayLabels": false,
    "up": {
      "title": "Command Palette",
      "iconName": "command",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+shift+p"
    },
    "down": {
      "title": "Quick Open",
      "iconName": "doc.text.magnifyingglass",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+p"
    },
    "left": {
      "title": "Inline AI Edit",
      "iconName": "wand.and.sparkles",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+k"
    },
    "right": {
      "title": "AI Chat",
      "iconName": "sparkles",
      "kind": "keyboardShortcut",
      "shortcutKey": "cmd+l"
    }
  }
}
```

## Wheel Layers

Quickwheel has nine wheel layers, each with its own four directional slots:

- Modifier + click opens Layer 1.
- Holding `1` through `9` together with the modifier opens that layer.
- The digit key is never swallowed, so app shortcuts like `cmd+2` still reach the frontmost app.

`slots` patches apply to Layer 1. To configure every layer, provide a top-level `layers` array (also valid inside `settings`):

```json
{
  "schemaVersion": 2,
  "mode": "merge",
  "layers": [
    { "name": "Browsing", "up": { "kind": "keyboardShortcut", "shortcutKey": "cmd+t" } },
    { "name": "Coding", "up": { "kind": "keyboardShortcut", "shortcutKey": "cmd+shift+p" } },
    { "name": "Apps", "up": { "kind": "launchApp", "bundleIdentifier": "com.apple.Safari" } }
  ]
}
```

Legacy configs that use top-level `up`/`down`/`left`/`right` in `settings` still load and map to Layer 1.

## Trigger Patterns (Multi-Step Slots)

Anywhere a slot is accepted, it can be either a single action object or `{ "steps": [action, ...] }`. Each trigger runs the next step in order and wraps back to the first; the cycle position is persisted and survives app restarts.

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

## Action Kinds

- `none`
- `openURL`: set `urlString`
- `openFile`: set `filePath`
- `revealInFinder`: set `filePath`
- `launchApp`: set `bundleIdentifier`
- `shellCommand`: set `shellCommand`
- `appleScript`: set `appleScript`
- `pasteText`: set `text`
- `keyboardShortcut`: set `shortcutKey` or `shortcutKeyCode` plus `shortcutModifiers`

## Shortcut Strings

Prefer `shortcutKey` for tool-generated configs.

Supported examples:

- `cmd+shift+p`
- `cmd+k`
- `cmd+l`
- `cmd+left`
- `ctrl+space`
- `option+shift+f`
- `keyCode:123`

Aliases accepted:

- Command: `cmd`, `command`, `⌘`
- Shift: `shift`, `⇧`
- Option: `option`, `opt`, `alt`, `⌥`
- Control: `control`, `ctrl`, `ctl`, `⌃`

## Icons

Use SF Symbol names in `iconName`, `menuBarSymbolName`, and `centerSymbolName`. Invalid symbols fall back to a safe system icon instead of breaking the wheel.

For `launchApp`, `openFile`, and `revealInFinder`, leave `iconName` blank to let Quickwheel show the target app, file, or folder icon automatically.

Set `iconImagePath` on an action to use a custom image (PNG, JPEG, etc.). Relative paths such as `Icons/my-icon.png` resolve against the Quickwheel configuration folder; absolute and `~/` paths also work. A custom image overrides `iconName`. Images chosen in the app UI are copied into `~/Library/Application Support/Quickwheel/Icons/`.

## Trigger Modifier

Set `triggerModifier` in `settings` when a config should change the activation gesture. The mouse button is currently left click.

Supported values:

- `leftCommand`
- `rightCommand`
- `eitherCommand`
- `leftOption`
- `rightOption`
- `eitherOption`
- `leftControl`
- `rightControl`
- `eitherControl`
- `leftShift`
- `rightShift`
- `eitherShift`
