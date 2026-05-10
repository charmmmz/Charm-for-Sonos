import assert from 'node:assert/strict';
import { test } from 'node:test';

import { stablePaletteForTrack } from './huePalette.js';

test('stable track palette is deterministic and bounded', () => {
  const first = stablePaletteForTrack('Midnight City', 'M83', 'Hurry Up');
  const second = stablePaletteForTrack('Midnight City', 'M83', 'Hurry Up');

  assert.deepEqual(first, second);
  assert.equal(first.length, 5);
  assert.ok(first.every(color => color.r >= 0 && color.r <= 1));
  assert.ok(first.every(color => color.g >= 0 && color.g <= 1));
  assert.ok(first.every(color => color.b >= 0 && color.b <= 1));
});

test('stable track palette changes between tracks', () => {
  assert.notDeepEqual(
    stablePaletteForTrack('Midnight City', 'M83', 'Hurry Up'),
    stablePaletteForTrack('Breathe', 'The Prodigy', 'The Fat of the Land'),
  );
});
