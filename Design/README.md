# SpaceLook icons

The original “lift to look” mark combines an open eye with a spacebar-shaped lower edge. Mint signals the preview; the white bar represents the keyboard action. The menu bar variant uses optically adjusted strokes at 18 pt and system template tinting.

- `AppIcon.svg`: editable application icon master, 1024 × 1024.
- `MenuBarIcon.svg`: editable monochrome menu bar master, 18 × 18.
- `Exports/`: generated PNG previews and standalone macOS ICNS.
- `../App/Assets.xcassets/`: generated Xcode app icon and vector template assets.

Regenerate with `python3 scripts/generate-icons.py` from the project root on macOS with Xcode. The renderer uses system WebKit; no third-party packages are required. Then run `./scripts/install-local.sh` to rebuild and install.
