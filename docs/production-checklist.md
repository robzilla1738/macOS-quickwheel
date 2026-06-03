# Production Checklist

Use this checklist before publishing a build.

## Required Verification

```sh
scripts/verify.sh
```

Expected result:

- SwiftPM tests pass.
- Xcode Debug build succeeds.
- `build/Quickwheel.app` is produced.
- `codesign --verify --deep --strict build/Quickwheel.app` passes.

## Manual Smoke Test

1. Quit any running Quickwheel process.
2. Launch `build/Quickwheel.app`.
3. Confirm the menu-bar item appears.
4. Confirm Accessibility permission is granted.
5. Use `Left Command + left click`.
6. Drag the joystick to each direction and release.
7. Confirm the configured action runs.
8. Release inside the dead zone and confirm nothing runs.
9. Open Preferences and edit a slot title, icon, action, and shortcut.
10. Import and export a JSON config.

## Distribution Notes

The local packaging script ad-hoc signs the app so it can be tested on this machine. Public distribution should use a Developer ID certificate and Apple notarization.

Recommended release flow:

```sh
scripts/verify.sh
# archive/sign/notarize with Developer ID outside the local helper
```

## Security Notes

Shell commands and AppleScript run with the user's account permissions. Treat imported configs as executable input and only load configs from trusted tools or people.
