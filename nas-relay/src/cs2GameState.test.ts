import assert from 'node:assert/strict';
import { test } from 'node:test';

import express from 'express';
import pino from 'pino';

import { Cs2GameStateService } from './cs2GameState.js';
import { createCs2GameStateRouter } from './cs2Routes.js';
import type { Cs2GameStatePayload } from './cs2Types.js';

const samplePayload: Cs2GameStatePayload = {
  provider: {
    name: 'Counter-Strike 2',
    appid: 730,
    version: 14020,
    steamid: '76561197981496355',
    timestamp: 1720553252,
  },
  map: {
    mode: 'Competitive',
    name: 'de_inferno',
    phase: 'Live',
    round: 12,
    team_t: {
      score: 6,
      consecutive_round_losses: 1,
      timeouts_remaining: 1,
      matches_won_this_series: 0,
    },
    team_ct: {
      score: 5,
      consecutive_round_losses: 0,
      timeouts_remaining: 1,
      matches_won_this_series: 0,
    },
  },
  round: {
    phase: 'Live',
    bomb: 'Planted',
  },
  player: {
    steamid: '76561197981496355',
    name: 'Charm',
    team: 'CT',
    activity: 'Playing',
    state: {
      health: 42,
      armor: 87,
      helmet: true,
      flashed: 128,
      smoked: 0,
      burning: 32,
      money: 1200,
      round_kills: 1,
      round_killhs: 1,
      equip_value: 4100,
    },
    match_stats: {
      kills: 9,
      assists: 2,
      deaths: 7,
      mvps: 1,
      score: 24,
    },
  },
};

test('CS2 game state service stores the latest payload by provider SteamID', () => {
  const service = new Cs2GameStateService();
  const events: unknown[] = [];
  service.on('state', event => events.push(event));

  const snapshot = service.receive(samplePayload);

  assert.equal(snapshot.providerSteamId, '76561197981496355');
  assert.equal(snapshot.player?.state?.health, 42);
  assert.equal(snapshot.player?.state?.flashed, 128);
  assert.equal(snapshot.round?.bomb, 'Planted');
  assert.equal(service.latest('76561197981496355'), snapshot);
  assert.deepEqual(service.providers(), ['76561197981496355']);
  assert.equal(events.length, 1);
});

test('CS2 router accepts Valve GSI POST payloads and exposes status', async () => {
  const app = express();
  const service = new Cs2GameStateService();
  app.use(express.json());
  app.use('/api', createCs2GameStateRouter(service, pino({ enabled: false })));

  const server = app.listen(0);
  await new Promise<void>(resolve => server.once('listening', resolve));
  const address = server.address();
  assert(address && typeof address === 'object');
  const baseURL = `http://127.0.0.1:${address.port}`;

  try {
    const postResponse = await fetch(`${baseURL}/api/cs2/gamestate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(samplePayload),
    });
    assert.equal(postResponse.status, 204);

    const statusResponse = await fetch(`${baseURL}/api/cs2/status`);
    assert.equal(statusResponse.status, 200);
    const status = await statusResponse.json() as {
      ok: boolean;
      providers: Array<{
        providerSteamId: string;
        playerName?: string;
        team?: string;
        health?: number;
        flashed?: number;
        burning?: number;
        bomb?: string;
        map?: string;
      }>;
    };

    assert.equal(status.ok, true);
    assert.deepEqual(status.providers, [
      {
        providerSteamId: '76561197981496355',
        playerName: 'Charm',
        team: 'CT',
        health: 42,
        flashed: 128,
        burning: 32,
        bomb: 'Planted',
        map: 'de_inferno',
      },
    ]);
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close(error => error ? reject(error) : resolve());
    });
  }
});

test('CS2 router rejects payloads without provider SteamID', async () => {
  const app = express();
  app.use(express.json());
  app.use('/api', createCs2GameStateRouter(new Cs2GameStateService(), pino({ enabled: false })));

  const server = app.listen(0);
  await new Promise<void>(resolve => server.once('listening', resolve));
  const address = server.address();
  assert(address && typeof address === 'object');

  try {
    const response = await fetch(`http://127.0.0.1:${address.port}/api/cs2/gamestate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider: { name: 'Counter-Strike 2', appid: 730 } }),
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), {
      ok: false,
      error: 'provider.steamid required',
    });
  } finally {
    await new Promise<void>((resolve, reject) => {
      server.close(error => error ? reject(error) : resolve());
    });
  }
});
