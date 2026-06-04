# Development

Quickwheel is a SwiftPM project with a generated Xcode project.

## Requirements

- macOS 13 or later
- Xcode with the macOS SDK
- Swift 5.10 or newer
- XcodeGen for project regeneration

## Common Commands

```sh
swift test
xcodegen generate
xcodebuild -project Quickwheel.xcodeproj -scheme Quickwheel -configuration Debug build
scripts/build_app.sh
scripts/verify.sh
scripts/release.sh   # Developer ID sign, notarize, staple, zip
```

## Architecture

- `InputController`: owns the global CGEvent tap, modifier and layer-digit tracking, mouse tracking, event swallowing, direction resolution, and cycle advancement on fire.
- `OverlayWindowController`: owns the non-activating floating panel, passes gesture state into SwiftUI, and snapshots cycle indices when the wheel opens or the layer switches.
- `RadialOverlayView`: renders the minimal joystick overlay, safe canvas padding, slots with next-step previews and step badges, layer indicator dots, hover state, and automatic icons.
- `SettingsStore`: persists Codable settings in UserDefaults, exposes starter presets, and tracks per-slot cycle positions (`quickwheel.cycleIndices.v1`).
- `ActionRunner`: executes URLs, files, app launches, shell commands, AppleScript, paste text, and keyboard shortcuts.
- `QuickwheelConfigurationDocument`: imports/exports JSON configs for external tools (schema v2: layers, multi-step slots, custom icon paths; v1 and legacy flat configs still load).
- `QuickwheelIconStore`: copies user-chosen icon images into the configuration folder and resolves stored icon paths.

## Data Model

`QuickwheelSettings.layers` holds three `WheelLayer`s; each layer has four `QuickwheelSlot`s (up/down/left/right); each slot holds one or more `QuickwheelAction` steps that cycle on each trigger. Legacy persisted settings with flat `up/down/left/right` actions decode into Layer 1 automatically, and `settings.up` etc. remain as conveniences over Layer 1's primary steps.

Cycle positions are runtime state, stored separately from settings (keyed by slot UUID) so they survive restarts without polluting exported configs.

## Accessibility Permission

Quickwheel needs Accessibility permission to:

- detect the global modifier-click gesture
- receive drag and release events outside the app
- swallow the original click while the wheel is open
- send configured keyboard shortcuts or paste actions

If the event tap cannot be installed, the app shows the onboarding window again.

## Overlay Sizing

The configured `overlaySize` controls the visual wheel spacing. The actual `NSPanel` uses additional transparent padding from `RadialOverlayLayout` so selected icons, labels, hover scaling, and shadows have enough room and do not clip.

## Testing Notes

`scripts/verify.sh` is the release gate for local builds. It runs SwiftPM tests, regenerates the Xcode project when XcodeGen is installed, builds the Xcode scheme, packages `build/Quickwheel.app`, and verifies the ad-hoc signature.
