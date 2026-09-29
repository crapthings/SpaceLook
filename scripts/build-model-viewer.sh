#!/bin/zsh
set -euo pipefail

# Bundles pinned Three.js sources without adding a Node dependency to the macOS app build.
project_root="${0:A:h:h}"
build_dir="$(mktemp -d "${TMPDIR%/}/spacelook-three.XXXXXX")"
resources="$project_root/Packages/SpaceLookPreview/Sources/ModelPreview/Resources"
npm install --prefix "$build_dir" --no-audit --no-fund --ignore-scripts three@0.180.0 esbuild@0.25.10
NODE_PATH="$build_dir/node_modules" "$build_dir/node_modules/.bin/esbuild" \
  "$project_root/Design/ModelViewer/viewer.js" --bundle --minify --format=iife \
  --outfile="$resources/viewer.js"
cp "$build_dir/node_modules/three/LICENSE" "$resources/THREE-LICENSE.txt"
echo "Viewer rebuilt. Temporary build tools: $build_dir"
