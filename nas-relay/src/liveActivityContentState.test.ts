import assert from 'node:assert/strict';
import { test } from 'node:test';
import { PNG } from 'pngjs';

import {
  buildLiveActivityContentState,
  hashLiveActivityContentState,
} from './liveActivityContentState.js';
import type { SonosGroupSnapshot } from './types.js';

test('Live Activity content state embeds fetched album art as a small base64 JPEG thumbnail', async () => {
  const state = await buildLiveActivityContentState(snapshot({
    albumArtUri: 'http://192.168.50.25:1400/getaa?s=1',
  }), {
    fetchAlbumArt: async () => makeSolidPng(96, 96),
  });

  assert.ok(state.albumArtThumbnail);
  const thumbnail = Buffer.from(state.albumArtThumbnail, 'base64');
  assert.equal(thumbnail[0], 0xff);
  assert.equal(thumbnail[1], 0xd8);
  assert.ok(thumbnail.length > 0);
  assert.ok(thumbnail.length <= 15 * 1024);
});

test('Live Activity content hash changes when album art becomes available', () => {
  const withoutArt = hashLiveActivityContentState({
    ...baseContentState(),
    albumArtThumbnail: null,
  });
  const withArt = hashLiveActivityContentState({
    ...baseContentState(),
    albumArtThumbnail: Buffer.from('cover').toString('base64'),
  });

  assert.notEqual(withoutArt, withArt);
});

function snapshot(overrides: Partial<SonosGroupSnapshot> = {}): SonosGroupSnapshot {
  return {
    groupId: '192.168.50.25',
    speakerName: 'Office',
    trackTitle: 'Blue Train',
    artist: 'John Coltrane',
    album: 'Blue Train',
    albumArtUri: null,
    isPlaying: true,
    positionSeconds: 42,
    durationSeconds: 300,
    groupMemberCount: 1,
    sampledAt: new Date('2026-06-02T00:00:00Z'),
    ...overrides,
  };
}

function baseContentState() {
  return {
    trackTitle: 'Blue Train',
    artist: 'John Coltrane',
    album: 'Blue Train',
    isPlaying: true,
    positionSeconds: 42,
    durationSeconds: 300,
    dominantColorHex: null,
    startedAt: 802396758,
    endsAt: 802397058,
    groupMemberCount: 1,
    playbackSourceRaw: null,
  };
}

function makeSolidPng(width: number, height: number): Buffer {
  const png = new PNG({ width, height });
  for (let index = 0; index < png.data.length; index += 4) {
    png.data[index] = 24;
    png.data[index + 1] = 96;
    png.data[index + 2] = 210;
    png.data[index + 3] = 255;
  }
  return PNG.sync.write(png);
}
