import { describe, expect, test } from 'vitest';
import {
  clampControls,
  createFactoryState,
  createSeededRandom,
  getLayoutPreset,
  layoutPresets,
} from '../src/generator.js';

describe('poster generator core', () => {
  test('seeded random returns the same sequence for the same seed', () => {
    const first = createSeededRandom('neon-42');
    const second = createSeededRandom('neon-42');

    expect([first(), first(), first()]).toEqual([second(), second(), second()]);
  });

  test('different seeds produce different artwork state', () => {
    const first = createFactoryState({ seed: 'aurora', layout: 'halo-grid' });
    const second = createFactoryState({ seed: 'midnight', layout: 'halo-grid' });

    expect(first.shapes).not.toEqual(second.shapes);
  });

  test('three layout presets are available for the MVP', () => {
    expect(layoutPresets.map((preset) => preset.id)).toEqual([
      'halo-grid',
      'ribbon-type',
      'mosaic-field',
    ]);
  });

  test('control values are clamped and normalized', () => {
    expect(
      clampControls({
        seed: '',
        layout: 'unknown',
        palette: 'unknown',
        density: 250,
        scale: -12,
        chaos: 999,
      }),
    ).toMatchObject({
      seed: 'studio-001',
      layout: 'halo-grid',
      palette: 'signal-pop',
      density: 100,
      scale: 0,
      chaos: 100,
    });
  });

  test('layout preset lookup falls back to the first layout', () => {
    expect(getLayoutPreset('ribbon-type').name).toBe('Ribbon Type');
    expect(getLayoutPreset('missing').id).toBe('halo-grid');
  });
});
