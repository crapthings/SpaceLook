# Contributing to SpaceLook

Bug reports, feature ideas, and focused pull requests are welcome. For preview issues, include your macOS version, the file type, and whether the menu bar app was running. Share a minimal sample file with private information removed when possible.

## Build from source

Use macOS with Xcode supporting Swift 6. The deployment target is macOS 13. Open `SpaceLook.xcodeproj` and select the `SpaceLook` scheme. Xcode resolves the Swift Package dependencies on the first build.

To check compilation without signing or installing:

```sh
xcodebuild -project SpaceLook.xcodeproj -scheme SpaceLook \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/SpaceLook-DerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

## Install locally

The local installer requires a valid code-signing identity named `SpaceLook Development Signing`, including its private key, in your keychain. Create a self-signed Code Signing certificate using Keychain Access's Certificate Assistant and configure its trust, or adapt the script to your own signing identity.

Check available identities:

```sh
security find-identity -v -p codesigning
```

Then run:

```sh
./scripts/install-local.sh
```

This builds and signs the app and extension, replaces `/Applications/SpaceLook.app`, registers the extension, refreshes the Quick Look cache, and launches the app. It is intended for local development, not notarized distribution. Never commit certificates or private keys.

Grant Accessibility and Finder Automation access when prompted to use the custom preview window. Keep the signing identity, bundle identifier, and installation path stable between builds. System Quick Look may require enabling the extension in System Settings, and other preview extensions can affect selection.

## Project layout

- `App`: menu bar, Finder selection, keyboard handling, and remembered preview windows.
- `Extensions/QuickLook`: adapts system preview requests to the shared modules.
- `Packages/SpaceLookPreview`: format modules, routing, and shared UI.
- `Design`: editable SVG masters and exported icons.
- `scripts`: local installation and icon generation.

To add a format, implement `PreviewModule` in a package target, register it in `BuiltInPreviews`, and update the extension's supported content types. Choose the appropriate text or table layout family. Keep expensive work off the main thread, bound resource use, and support cancellation.

Verify both the running app and the system Quick Look extension. For window changes, check resizing, moving, closing and reopening, and switching between document and list previews.

## Icons

Edit the SVG masters in `Design`, then regenerate resources with:

```sh
python3 scripts/generate-icons.py
```

This uses system WebKit and Xcode tools; no third-party Python packages are needed.
