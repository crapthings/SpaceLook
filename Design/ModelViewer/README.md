# Model viewer

`viewer.js` is the editable Three.js viewer source. Rebuild the checked-in offline bundle with `zsh scripts/build-model-viewer.sh` (Node.js, npm, and network access required only for this step).

The app uses Three.js 0.180.0, bundled with esbuild 0.25.10. Three.js's MIT license is included beside the bundled script. Normal Xcode builds require no npm tooling or remote viewer assets.

Initial scope: self-contained glTF 2.0 GLB, static pose, orbit/pan/zoom, automatic framing, and white/gray/black backgrounds. Draco, Meshopt, and KTX2 decoders are not bundled. External resource URLs are rejected. GLB reads are capped at 128 MB; decoded textures and geometry can consume more GPU memory than the source file size.

References: [GLTFLoader](https://threejs.org/docs/pages/GLTFLoader.html), [OrbitControls](https://threejs.org/docs/pages/OrbitControls.html).
