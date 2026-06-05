# Quickwheel

[![Release](https://img.shields.io/github/v/release/robzilla1738/macOS-quickwheel)](https://github.com/robzilla1738/macOS-quickwheel/releases/latest)
[![CI](https://github.com/robzilla1738/macOS-quickwheel/actions/workflows/ci.yml/badge.svg)](https://github.com/robzilla1738/macOS-quickwheel/actions/workflows/ci.yml)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-robcourson-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/robcourson)

Quickwheel is a macOS menu-bar utility for fast directional actions. Hold the activation modifier, left-click anywhere, flick toward a direction, and release to run that slot — a radial joystick for your most-used shortcuts, scripts, and apps.

The default trigger is **Left Command + left click**. Press **1**, **2**, or **3** with the modifier held — before clicking or while the wheel is open — to switch wheel layers.

## Install

1. Download `Quickwheel-<version>.zip` from the [latest release](https://github.com/robzilla1738/macOS-quickwheel/releases/latest).
2. Unzip and move **Quickwheel.app** to `/Applications`.
3. Launch it and grant Accessibility permission when prompted (required for the global gesture).

The app is Developer ID signed and notarized by Apple. Requires macOS 13.0 or later.
Quickwheel checks for updates with Sparkle and uses the GitHub release feed configured in `appcast.xml`.

## Features

- **Radial flick gesture** — hold the modifier, click, flick up/down/left/right, release to fire. Release inside the dead zone to cancel.
- **Nine wheel layers** — modifier+click opens Layer 1; press 1–9 before or during a gesture to switch layers (up to 36 actions). The wheel updates live and shows the active layer number.
- **Trigger patterns** — a slot can hold multiple steps that cycle on each trigger (run A, then B, then back to A). Perfect for start/stop toggles like dictation or screen recording. The cycle position survives restarts, and the wheel previews the step that fires next.
- **Eight action kinds** — open URL, open file/folder, reveal in Finder, launch app, shell command, AppleScript, paste text, and keyboard shortcut.
- **Custom icons** — SF Symbols, automatic app/file icons, or any image via drag-and-drop onto the icon well in settings.
- **Custom activation modifier** — left/right/either Command, Option, Control, or Shift.
- **Configurable feel** — dead-zone radius, wheel size, slot labels, menu-bar and center icons.
- **Starter sets** — one-click presets for browser navigation, writing, IDE/AI coding, and app launching.
- **Tool-friendly JSON config** — IDEs and AI agents can reconfigure the wheel by writing JSON to `~/Library/Application Support/Quickwheel/`. See [docs/quickwheel-config.md](docs/quickwheel-config.md).

## Usage

1. Launch Quickwheel — it lives in the menu bar (no Dock icon).
2. Grant Accessibility permission when prompted.
3. Hold the configured modifier, left-click, drag toward a slot, and release.
4. Press 1–9 with the modifier held — before clicking or while the wheel is open — to switch layers.
5. Release inside the dead zone to cancel, or press Escape.

Customize everything from the menu-bar item under **Customize Wheel...**:

- Pick a layer with the segmented control, then click a direction slot to edit it.
- Use **Add Step** in the Trigger Pattern section to make a slot cycle through multiple actions.
- Drop an image onto the **Image** well (or click Choose...) to give an action a custom icon.

> **Note on layer digits:** the 1/2/3 keys are never swallowed when pressed before clicking, so app shortcuts like ⌘1 still reach the frontmost app. Digits pressed while the wheel is already open are consumed by Quickwheel.

## Configuration for tools and AI agents

External tools can patch or replace the wheel by writing JSON to:

```text
~/Library/Application Support/Quickwheel/active.quickwheel.json
```

then choosing **Configuration Folder > Reload active.quickwheel.json** from the menu. The format supports merge patches, full replacement, multi-layer setups, multi-step trigger patterns, and custom icons — see [docs/quickwheel-config.md](docs/quickwheel-config.md) and the bundled JSON schema.

## Development

```sh
swift test            # unit tests
xcodegen generate     # regenerate the Xcode project after editing project.yml
open Quickwheel.xcodeproj
```

Local packaging and verification:

```sh
scripts/build_app.sh  # build and ad-hoc sign build/Quickwheel.app
scripts/verify.sh     # full local release gate
scripts/release.sh    # Developer ID sign, notarize, staple, zip, and update appcast.xml
```

The app requests Accessibility permission on launch. That permission is required for the global event tap and for swallowing the original click while the wheel is visible.

More detail in [docs/development.md](docs/development.md) and [docs/production-checklist.md](docs/production-checklist.md).

## Support

If Quickwheel saves you time, you can [buy me a coffee](https://buymeacoffee.com/robcourson). ☕

## License

[MIT](LICENSE)
