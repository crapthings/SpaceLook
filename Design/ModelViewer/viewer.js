import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// Reports completion and actionable errors to the native loading overlay.
const report = (message) => window.webkit?.messageHandlers.modelStatus.postMessage(message);

// Loads a self-contained GLB and renders only when the camera, viewport, or background changes.
async function start() {
  const canvas = document.querySelector('canvas');
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#858585');
  const camera = new THREE.PerspectiveCamera(40, 1, 0.01, 100);
  const controls = new OrbitControls(camera, canvas);
  controls.enablePan = true;
  scene.add(new THREE.HemisphereLight(0xffffff, 0x687084, 2.5));
  const key = new THREE.DirectionalLight(0xffffff, 3);
  key.position.set(3, 5, 4);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xffffff, 1.5);
  fill.position.set(-3, 1, -2);
  scene.add(fill);
  let model;
  let radius = 1;
  const render = () => renderer.render(scene, camera);
  const resize = () => {
    const width = Math.max(1, innerWidth), height = Math.max(1, innerHeight);
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    render();
  };
  const fit = () => {
    const vertical = THREE.MathUtils.degToRad(camera.fov) / 2;
    const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
    const distance = radius / Math.sin(Math.min(vertical, horizontal)) * 1.15;
    camera.position.set(1, 0.65, 1).normalize().multiplyScalar(distance);
    camera.near = Math.max(radius / 1000, 0.00001);
    camera.far = Math.max(radius * 100, distance * 10);
    camera.updateProjectionMatrix();
    controls.target.set(0, 0, 0);
    controls.minDistance = radius * 0.05;
    controls.maxDistance = Math.max(radius * 30, distance * 2);
    controls.update();
    render();
  };
  controls.addEventListener('change', render);
  window.addEventListener('resize', resize);
  canvas.addEventListener('dblclick', fit);
  canvas.addEventListener('webglcontextlost', (event) => {
    event.preventDefault();
    report('Graphics resources were exhausted. Close and reopen the preview to try again.');
  });
  document.querySelectorAll('[data-color]').forEach((button) => {
    button.addEventListener('click', () => {
      const colors = { white: '#ffffff', gray: '#858585', black: '#151515' };
      scene.background.set(colors[button.dataset.color]);
      document.querySelectorAll('[data-color]').forEach((item) => item.setAttribute('aria-pressed', String(item === button)));
      render();
    });
  });
  resize();
  const response = await fetch('model.glb');
  if (!response.ok) throw new Error(await response.text());
  const data = await response.arrayBuffer();
  if (data.byteLength < 20) throw new Error('This file is not a valid GLB model.');
  const header = new DataView(data);
  if (header.getUint32(0, true) !== 0x46546c67 || header.getUint32(4, true) !== 2 || header.getUint32(8, true) !== data.byteLength) {
    throw new Error('This file is not a valid glTF 2.0 binary model.');
  }
  const manager = new THREE.LoadingManager();
  manager.setURLModifier((url) => {
    if (url.startsWith('blob:') || url.startsWith('data:')) return url;
    throw new Error('This model references external files. Export a self-contained GLB to preview it.');
  });
  const gltf = await new GLTFLoader(manager).parseAsync(data, '');
  model = gltf.scene;
  model.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(model);
  if (bounds.isEmpty()) throw new Error('This model contains no visible geometry.');
  const center = bounds.getCenter(new THREE.Vector3());
  radius = bounds.getBoundingSphere(new THREE.Sphere()).radius;
  if (!Number.isFinite(radius) || radius <= 0) throw new Error('This model has invalid bounds.');
  model.position.sub(center);
  scene.add(model);
  fit();
  report('ready');
  window.addEventListener('pagehide', () => {
    controls.dispose();
    model.traverse((object) => {
      object.geometry?.dispose();
      const materials = Array.isArray(object.material) ? object.material : [object.material];
      materials.filter(Boolean).forEach((material) => {
        Object.values(material).forEach((value) => { if (value?.isTexture) value.dispose(); });
        material.dispose();
      });
    });
    renderer.dispose();
    renderer.forceContextLoss();
  }, { once: true });
}

// Ends the loading state even when a model or required graphics feature cannot be loaded.
start().catch((error) => {
  console.error(error);
  const message = String(error.message || error);
  report(/DRACO|KTX2|Meshopt/i.test(message)
    ? 'This model uses unsupported compression. Export a GLB without Draco, Meshopt, or KTX2 compression.'
    : `Could not preview model. ${message}`);
});
