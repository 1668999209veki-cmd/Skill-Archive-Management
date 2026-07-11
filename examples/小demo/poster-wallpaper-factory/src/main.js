import './styles.css';
import {
  clampControls,
  createFactoryState,
  defaultControls,
  layoutPresets,
  palettePresets,
} from './generator.js';
import { createPosterSketch } from './sketch.js';
import { copyTextToClipboard } from './clipboard.js';

const form = document.querySelector('#controls');
const seedInput = document.querySelector('#seed');
const paletteSelect = document.querySelector('#palette');
const layoutOptions = document.querySelector('#layoutOptions');
const densityInput = document.querySelector('#density');
const scaleInput = document.querySelector('#scale');
const chaosInput = document.querySelector('#chaos');
const densityValue = document.querySelector('#densityValue');
const scaleValue = document.querySelector('#scaleValue');
const chaosValue = document.querySelector('#chaosValue');
const signature = document.querySelector('#signature');
const randomizeSeedButton = document.querySelector('#randomizeSeed');
const exportButton = document.querySelector('#exportPng');
const copyLinkButton = document.querySelector('#copyLink');
const copyStatus = document.querySelector('#copyStatus');

const initialControls = controlsFromUrl();
renderStaticOptions();
setFormValues(initialControls);

const sketch = createPosterSketch(document.querySelector('#canvasMount'), createFactoryState(initialControls));
render();

form.addEventListener('input', render);
form.addEventListener('change', render);

randomizeSeedButton.addEventListener('click', () => {
  seedInput.value = makeSeed();
  render();
});

exportButton.addEventListener('click', () => {
  sketch.exportPng();
});

copyLinkButton.addEventListener('click', async () => {
  const result = await copyTextToClipboard(window.location.href);
  setCopyFeedback(result.ok ? 'Copied' : 'Copy failed');
});

function render() {
  const controls = readControls();
  const state = createFactoryState(controls);

  setFormValues(state.controls);
  setOutputs(state.controls);
  signature.textContent = state.signature;
  syncUrl(state.controls);
  sketch.update(state);
}

function renderStaticOptions() {
  layoutOptions.innerHTML = layoutPresets
    .map(
      (layout) => `
        <label class="segment">
          <input type="radio" name="layout" value="${layout.id}" />
          <span>${layout.name}</span>
        </label>
      `,
    )
    .join('');

  paletteSelect.innerHTML = palettePresets
    .map(
      (palette) => `
        <option value="${palette.id}">${palette.name}</option>
      `,
    )
    .join('');
}

function readControls() {
  const formData = new FormData(form);

  return clampControls({
    seed: seedInput.value,
    layout: formData.get('layout'),
    palette: paletteSelect.value,
    density: densityInput.value,
    scale: scaleInput.value,
    chaos: chaosInput.value,
  });
}

function setFormValues(controls) {
  seedInput.value = controls.seed;
  paletteSelect.value = controls.palette;
  densityInput.value = controls.density;
  scaleInput.value = controls.scale;
  chaosInput.value = controls.chaos;

  const layoutInput = form.querySelector(`input[name="layout"][value="${controls.layout}"]`);
  if (layoutInput) {
    layoutInput.checked = true;
  }
}

function setOutputs(controls) {
  densityValue.value = controls.density;
  scaleValue.value = controls.scale;
  chaosValue.value = controls.chaos;
}

function controlsFromUrl() {
  const params = new URLSearchParams(window.location.search);

  return clampControls({
    seed: params.get('seed') ?? defaultControls.seed,
    layout: params.get('layout') ?? defaultControls.layout,
    palette: params.get('palette') ?? defaultControls.palette,
    density: params.get('density') ?? defaultControls.density,
    scale: params.get('scale') ?? defaultControls.scale,
    chaos: params.get('chaos') ?? defaultControls.chaos,
  });
}

function syncUrl(controls) {
  const params = new URLSearchParams(controls);
  const nextUrl = `${window.location.pathname}?${params.toString()}`;

  window.history.replaceState({}, '', nextUrl);
}

function makeSeed() {
  const bytes = new Uint32Array(1);
  window.crypto.getRandomValues(bytes);
  return `studio-${bytes[0].toString(36).slice(0, 6)}`;
}

function setCopyFeedback(message) {
  const previousLabel = 'Copy Link';

  copyLinkButton.textContent = message;
  copyStatus.textContent = message;
  window.setTimeout(() => {
    copyLinkButton.textContent = previousLabel;
  }, 1100);
}
