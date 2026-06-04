# Quickwheel

Quickwheel is a macOS menu-bar utility for fast directional actions. Hold the configured activation modifier, left-click anywhere, drag or flick toward a direction, then release to run that slot.

The default trigger is **Left Command + left click**. Hold **1**, **2**, or **3** with the modifier to open that wheel layer instead.

## Features

- Menu-bar background app with Preferences, starter sets, import/export, direct action running, and Quit.
- Minimal radial overlay with a center joystick puck, four floating action slots, hover growth, and release-to-launch selection.
- Three wheel layers: modifier+click opens Layer 1; modifier+1/2/3+click opens that layer (up to 12 actions).
- Trigger patterns: a slot can hold multiple steps that cycle on each trigger (great for start/stop toggles), with the position remembered across restarts.
- Safe overlay canvas padding so icons, labels, hover states, and shadows do not clip at supported wheel sizes.
- Custom activation modifier: left/right/either Command, Option, Control, or Shift.
- Custom menu-bar icon, center icon, slot title, and slot icon.
- Custom slot images: drop or choose any image per action; it overrides the SF Symbol.
- Automatic app/file icons when a `launchApp`, `openFile`, or `revealInFinder` slot leaves `iconName` blank.
- Configurable dead-zone radius, wheel size, and selected-slot label.
- Actions for URLs, files/folders, reveal in Finder, app bundle IDs, shell commands, AppleScript, paste text, and keyboard shortcuts.
- Tool-friendly JSON config folder at `~/Library/Application Support/Quickwheel/` for IDEs and AI agents. See [docs/quickwheel-config.md](docs/quickwheel-config.md).

## Usage

1. Launch Quickwheel.
2. Grant Accessibility permission when prompted.
3. Hold the configured modifier, left-click, drag toward a slot, and release.
4. Hold 1, 2, or 3 along with the modifier before clicking to use that layer's wheel.
5. Release inside the dead zone to cancel.

Preferences are available from the menu-bar item under **Customize Wheel...**.

## Development

Open the generated Xcode project and run the `Quickwheel` scheme:

```sh
open Quickwheel.xcodeproj
```

Regenerate the project after changing `project.yml`:

```sh
xcodegen generate
```

Run unit tests:

```sh
swift test
```

Run the full local verification path:

```sh
scripts/verify.sh
```

Build a local app bundle:

```sh
scripts/build_app.sh
open build/Quickwheel.app
```

The app requests Accessibility permission on launch. That permission is required for the global event tap and for swallowing the original click while the wheel is visible.

## Docs

- [Configuration format](docs/quickwheel-config.md)
- [Development notes](docs/development.md)
- [Production checklist](docs/production-checklist.md)
