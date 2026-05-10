import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

import { HueAmbienceConfigStore } from './hueConfigStore.js';
import type { HueAmbienceRuntimeConfig } from './hueTypes.js';

const config: HueAmbienceRuntimeConfig = {
  enabled: true,
  bridge: { id: 'bridge-1', ipAddress: '192.168.50.216', name: 'Hue Bridge' },
  applicationKey: 'secret-key',
  resources: { lights: [], areas: [] },
  mappings: [],
  groupStrategy: 'coordinatorOnly',
  stopBehavior: 'turnOff',
  motionStyle: 'still',
  flowIntervalSeconds: 8,
};

test('config store persists runtime config without redacting the saved application key', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'hue-config-'));
  try {
    const store = new HueAmbienceConfigStore(dir);
    await store.save(config);

    const reloaded = new HueAmbienceConfigStore(dir);
    const loaded = await reloaded.load();
    assert.equal(loaded?.applicationKey, 'secret-key');

    const raw = JSON.parse(await readFile(path.join(dir, 'hue-ambience-config.json'), 'utf8'));
    assert.equal(raw.applicationKey, 'secret-key');
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});

test('config store status redacts application key', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'hue-config-'));
  try {
    const store = new HueAmbienceConfigStore(dir);
    await store.save(config);

    assert.deepEqual(store.status(), {
      configured: true,
      enabled: true,
      bridge: { id: 'bridge-1', ipAddress: '192.168.50.216', name: 'Hue Bridge' },
      mappings: 0,
      lights: 0,
      areas: 0,
      motionStyle: 'still',
      stopBehavior: 'turnOff',
    });
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
});
