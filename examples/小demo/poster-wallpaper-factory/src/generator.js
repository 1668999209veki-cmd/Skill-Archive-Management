export const canvasSpec = {
  width: 1080,
  height: 1440,
};

export const layoutPresets = [
  {
    id: 'halo-grid',
    name: 'Halo Grid',
    description: 'Radial marks locked to a quiet editorial grid.',
  },
  {
    id: 'ribbon-type',
    name: 'Ribbon Type',
    description: 'Large type bands with kinetic slices and soft fields.',
  },
  {
    id: 'mosaic-field',
    name: 'Mosaic Field',
    description: 'Wallpaper tiles, poster blocks, and noisy symbols.',
  },
];

export const palettePresets = [
  {
    id: 'signal-pop',
    name: 'Signal Pop',
    background: '#f5f1e8',
    ink: '#111111',
    colors: ['#ff4b3e', '#009f93', '#ffd166', '#2f55d4', '#111111'],
  },
  {
    id: 'night-bloom',
    name: 'Night Bloom',
    background: '#141217',
    ink: '#f6efe6',
    colors: ['#ff6fb1', '#62d9ff', '#f7e05f', '#8df27b', '#f6efe6'],
  },
  {
    id: 'print-shop',
    name: 'Print Shop',
    background: '#fffaf0',
    ink: '#1b1b1b',
    colors: ['#ef233c', '#2b9348', '#0077b6', '#f4a261', '#1b1b1b'],
  },
  {
    id: 'ice-ember',
    name: 'Ice Ember',
    background: '#ecf8f8',
    ink: '#16213e',
    colors: ['#ff7a59', '#00a8cc', '#7d5fff', '#f8d210', '#16213e'],
  },
];

export const defaultControls = {
  seed: 'studio-001',
  layout: 'halo-grid',
  palette: 'signal-pop',
  density: 54,
  scale: 52,
  chaos: 34,
};

export function createSeededRandom(seed) {
  let state = hashString(String(seed || defaultControls.seed));

  return () => {
    state += 0x6d2b79f5;
    let next = state;
    next = Math.imul(next ^ (next >>> 15), next | 1);
    next ^= next + Math.imul(next ^ (next >>> 7), next | 61);
    return ((next ^ (next >>> 14)) >>> 0) / 4294967296;
  };
}

export function clampControls(input = {}) {
  const controls = { ...defaultControls, ...input };
  const seed = String(controls.seed ?? '').trim() || defaultControls.seed;

  return {
    seed,
    layout: layoutPresets.some((layout) => layout.id === controls.layout)
      ? controls.layout
      : defaultControls.layout,
    palette: palettePresets.some((palette) => palette.id === controls.palette)
      ? controls.palette
      : defaultControls.palette,
    density: clampNumber(controls.density, 0, 100, defaultControls.density),
    scale: clampNumber(controls.scale, 0, 100, defaultControls.scale),
    chaos: clampNumber(controls.chaos, 0, 100, defaultControls.chaos),
  };
}

export function getLayoutPreset(id) {
  return layoutPresets.find((layout) => layout.id === id) ?? layoutPresets[0];
}

export function getPalettePreset(id) {
  return palettePresets.find((palette) => palette.id === id) ?? palettePresets[0];
}

export function createFactoryState(input = {}) {
  const controls = clampControls(input);
  const palette = getPalettePreset(controls.palette);
  const layout = getLayoutPreset(controls.layout);
  const random = createSeededRandom(
    `${controls.seed}:${controls.layout}:${controls.palette}:${controls.density}:${controls.scale}:${controls.chaos}`,
  );
  const shapeCount = Math.round(16 + controls.density * 0.92);
  const minSize = 18 + controls.scale * 0.18;
  const maxSize = 76 + controls.scale * 2.8;
  const chaos = controls.chaos / 100;
  const shapes = Array.from({ length: shapeCount }, (_, index) => {
    const size = lerp(minSize, maxSize, random());

    return {
      id: index,
      x: round(random()),
      y: round(random()),
      size: round(size),
      rotation: round(lerp(-Math.PI, Math.PI, random()) * chaos),
      color: palette.colors[Math.floor(random() * palette.colors.length)],
      variant: Math.floor(random() * 5),
      alpha: round(0.42 + random() * 0.58),
      weight: round(1 + random() * 7),
      drift: round((random() - 0.5) * chaos),
    };
  });

  return {
    controls,
    palette,
    layout,
    canvas: canvasSpec,
    shapes,
    signature: `${controls.layout}/${controls.seed}`,
  };
}

function hashString(value) {
  let hash = 1779033703 ^ value.length;

  for (let index = 0; index < value.length; index += 1) {
    hash = Math.imul(hash ^ value.charCodeAt(index), 3432918353);
    hash = (hash << 13) | (hash >>> 19);
  }

  return hash >>> 0;
}

function clampNumber(value, min, max, fallback) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return fallback;
  }

  return Math.min(max, Math.max(min, Math.round(number)));
}

function lerp(start, end, amount) {
  return start + (end - start) * amount;
}

function round(value) {
  return Math.round(value * 1000) / 1000;
}
