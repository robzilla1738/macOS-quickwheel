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
- Sparkle is embedded in `build/Quickwheel.app/Contents/Frameworks`.

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

The local packaging script ad-hoc signs the app so it can be tested on this machine. Public distribution uses a Developer ID certificate and Apple notarization via the release script.

Recommended release flow:

```sh
scripts/verify.sh
scripts/release.sh   # build, Developer ID sign (hardened runtime), notarize, staple, zip
```

`scripts/release.sh` expects a `Developer ID Application` identity in the keychain and notarytool credentials stored under the `notarytool` keychain profile (override with `SIGNING_IDENTITY` / `NOTARY_PROFILE`). It produces `build/Quickwheel-<version>.zip` ready for upload.

The release script also regenerates `appcast.xml` for Sparkle using the local EdDSA signing key in Keychain. Upload the generated zip to the matching GitHub tag, commit the updated `appcast.xml`, and push `main` so installed apps can see the release feed.

Before tagging a release, bump `CFBundleShortVersionString`/`CFBundleVersion` in both `project.yml` and `Resources/Info.plist` (xcodegen regenerates the plist from `project.yml`).

## Security Notes

Shell commands and AppleScript run with the user's account permissions. Treat imported configs as executable input and only load configs from trusted tools or people.
