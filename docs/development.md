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
```

## Architecture

- `InputController`: owns the global CGEvent tap, modifier tracking, mouse tracking, event swallowing, and direction resolution.
- `OverlayWindowController`: owns the non-activating floating panel and passes gesture state into SwiftUI.
- `RadialOverlayView`: renders the minimal joystick overlay, safe canvas padding, slots, hover state, and automatic icons.
- `SettingsStore`: persists Codable settings in UserDefaults and exposes starter presets.
- `ActionRunner`: executes URLs, files, app launches, shell commands, AppleScript, paste text, and keyboard shortcuts.
- `QuickwheelConfigurationDocument`: imports/exports JSON configs for external tools.

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
