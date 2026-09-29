#!/bin/zsh
set -euo pipefail

# Resolves paths independently of the shell's current working directory.
project_root="${0:A:h:h}"
derived_data="${TMPDIR%/}/SpaceLook-LocalDerivedData"
built_app="$derived_data/Build/Products/Debug/SpaceLook.app"
installed_app="/Applications/SpaceLook.app"
extension_id="dev.spacelook.app.quicklook"
signing_identity="SpaceLook Development Signing"
launch_services="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

# Builds both targets with the stable local signing identity configured in the project.
xcodebuild \
  -project "$project_root/SpaceLook.xcodeproj" \
  -scheme SpaceLook \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build

# Signs nested code before signing its containing extension and app bundles.
extension_path="$built_app/Contents/PlugIns/SpaceLookQuickLook.appex"
for nested_code in "$extension_path"/Contents/MacOS/*.dylib(N); do
  codesign --force --sign "$signing_identity" --timestamp=none "$nested_code"
done
codesign \
  --force --sign "$signing_identity" --timestamp=none \
  --entitlements "$project_root/Extensions/QuickLook/QuickLook.entitlements" \
  "$extension_path"
for nested_code in "$built_app"/Contents/MacOS/*.dylib(N); do
  codesign --force --sign "$signing_identity" --timestamp=none "$nested_code"
done
codesign \
  --force --sign "$signing_identity" --timestamp=none \
  --entitlements "$project_root/App/SpaceLook.entitlements" \
  "$built_app"
codesign --verify --deep --strict --verbose=1 "$built_app"

# Replaces the installed app and refreshes system registrations.
killall SpaceLook 2>/dev/null || true
ditto "$built_app" "$installed_app"
codesign --verify --deep --strict --verbose=1 "$installed_app"
"$launch_services" -f -R -trusted "$installed_app"
pluginkit -a "$installed_app/Contents/PlugIns/SpaceLookQuickLook.appex"
pluginkit -e use -i "$extension_id"
qlmanage -r cache
open "$installed_app"
