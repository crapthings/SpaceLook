#!/usr/bin/env python3
"""Generate macOS icon assets and an ICNS file from the editable SVG masters."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "App/Assets.xcassets"


# Rebuild all raster sizes from vectors and retain the menu icon as a template vector.
def main():
    appicon = ASSETS / "AppIcon.appiconset"
    menu = ASSETS / "MenuBarIcon.imageset"
    exports = ROOT / "Design/Exports"
    for directory in (appicon, menu, exports):
        directory.mkdir(parents=True, exist_ok=True)
    info = {"version": 1, "author": "xcode"}
    (ASSETS / "Contents.json").write_text(json.dumps({"info": info}, indent=2) + "\n")
    with tempfile.TemporaryDirectory(prefix="spacelook-icons-") as temporary:
        renderer = Path(temporary) / "render-svg"
        subprocess.run(["xcrun", "swiftc", "-parse-as-library", str(ROOT / "scripts/render-svg.swift"), "-o", str(renderer)], check=True)
        iconset = Path(temporary) / "SpaceLook.iconset"
        iconset.mkdir()
        images = []
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                filename = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
                subprocess.run([str(renderer), str(ROOT / "Design/AppIcon.svg"), str(appicon / filename), str(size * scale)], check=True)
                shutil.copyfile(appicon / filename, iconset / filename)
                images.append({"idiom": "mac", "size": f"{size}x{size}", "scale": f"{scale}x", "filename": filename})
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(exports / "SpaceLook.icns")], check=True)
        shutil.copyfile(appicon / "icon_512x512@2x.png", exports / "AppIcon.png")
        subprocess.run([str(renderer), str(ROOT / "Design/MenuBarIcon.svg"), str(exports / "MenuBarIcon@2x.png"), "36"], check=True)
    (appicon / "Contents.json").write_text(json.dumps({"images": images, "info": info}, indent=2) + "\n")
    shutil.copyfile(ROOT / "Design/MenuBarIcon.svg", menu / "MenuBarIcon.svg")
    (menu / "Contents.json").write_text(json.dumps({
        "images": [{"idiom": "universal", "filename": "MenuBarIcon.svg"}], "info": info,
        "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"}
    }, indent=2) + "\n")


if __name__ == "__main__":
    main()
