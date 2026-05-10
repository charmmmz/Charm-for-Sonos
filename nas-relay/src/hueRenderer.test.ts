import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildHueLightBody,
  resolveHueTargets,
  shouldUseLightForAmbience,
} from './hueRenderer.js';
import type { HueAmbienceRuntimeConfig, HueLightResource } from './hueTypes.js';

const lights: HueLightResource[] = [
  {
    id: 'decor-gradient',
    name: 'Gradient Strip',
    supportsColor: true,
    supportsGradient: true,
    supportsEntertainment: true,
    function: 'decorative',
    functionMetadataResolved: true,
  },
  {
    id: 'task-lamp',
    name: 'Desk Lamp',
    supportsColor: true,
    supportsGradient: false,
    supportsEntertainment: true,
    function: 'functional',
    functionMetadataResolved: true,
  },
  {
    id: 'old-cache',
    name: 'Old Cached Light',
    supportsColor: true,
    supportsGradient: false,
    supportsEntertainment: true,
    function: 'unknown',
    functionMetadataResolved: false,
  },
];

const config: HueAmbienceRuntimeConfig = {
  enabled: true,
  bridge: { id: 'bridge-1', ipAddress: '192.168.50.216', name: 'Hue Bridge' },
  applicationKey: 'secret-key',
  resources: {
    lights,
    areas: [
      {
        id: 'ent-1',
        name: 'PC Entertainment Area',
        kind: 'entertainmentArea',
        childLightIDs: ['decor-gradient', 'task-lamp', 'old-cache'],
      },
    ],
  },
  mappings: [
    {
      sonosID: 'RINCON_playroom',
      sonosName: 'Playroom',
      relayGroupID: '192.168.50.25',
      preferredTarget: { kind: 'entertainmentArea', id: 'ent-1' },
      fallbackTarget: null,
      includedLightIDs: ['old-cache'],
      excludedLightIDs: ['task-lamp'],
      capability: 'liveEntertainment',
    },
  ],
  groupStrategy: 'allMappedRooms',
  stopBehavior: 'leaveCurrent',
  motionStyle: 'flowing',
  flowIntervalSeconds: 8,
};

test('light filtering excludes task lights and unresolved metadata unless explicitly included', () => {
  assert.equal(shouldUseLightForAmbience(lights[0]!, config.mappings[0]!), true);
  assert.equal(shouldUseLightForAmbience(lights[1]!, config.mappings[0]!), false);
  assert.equal(shouldUseLightForAmbience(lights[2]!, config.mappings[0]!), true);
});

test('target resolution matches relay group id and keeps exclusions winning over inclusions', () => {
  const targets = resolveHueTargets(config, {
    groupId: '192.168.50.25',
    speakerName: 'Playroom',
    trackTitle: 'A',
    artist: 'B',
    album: 'C',
    isPlaying: true,
    positionSeconds: 1,
    durationSeconds: 120,
    groupMemberCount: 1,
    sampledAt: new Date('2026-05-11T00:00:00Z'),
  });

  assert.deepEqual(targets.map(t => t.area.id), ['ent-1']);
  assert.deepEqual(targets[0]!.lights.map(l => l.id), ['decor-gradient', 'old-cache']);
});

test('gradient lights receive multi-point palette bodies while basic lights receive one xy color', () => {
  const palette = [
    { r: 1, g: 0.1, b: 0.1 },
    { r: 0.1, g: 0.7, b: 1 },
    { r: 0.8, g: 0.2, b: 0.9 },
  ];

  const gradientBody = buildHueLightBody(lights[0]!, palette, 8);
  assert.equal(gradientBody.gradient?.points.length, 3);
  assert.equal(gradientBody.dynamics.duration, 8000);

  const basicBody = buildHueLightBody({ ...lights[0]!, supportsGradient: false }, palette, 4);
  assert.equal(basicBody.gradient, undefined);
  assert.ok(basicBody.color?.xy.x);
  assert.equal(basicBody.dynamics.duration, 4000);
});
