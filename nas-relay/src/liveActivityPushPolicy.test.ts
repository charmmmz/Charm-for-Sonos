import assert from 'node:assert/strict';
import { test } from 'node:test';

import { shouldPushLiveActivityUpdate } from './liveActivityPushPolicy.js';
import type { TokenEntry } from './types.js';

test('Live Activity force updates bypass an unchanged content hash', () => {
  const token = tokenEntry({ lastSentHash: 'same-hash' });

  assert.equal(shouldPushLiveActivityUpdate(token, 'same-hash', { force: true }), true);
});

test('Live Activity event updates skip an unchanged content hash', () => {
  const token = tokenEntry({ lastSentHash: 'same-hash' });

  assert.equal(shouldPushLiveActivityUpdate(token, 'same-hash', { force: false }), false);
});

test('Live Activity event updates send changed content hashes', () => {
  const token = tokenEntry({ lastSentHash: 'old-hash' });

  assert.equal(shouldPushLiveActivityUpdate(token, 'new-hash', { force: false }), true);
});

function tokenEntry(overrides: Partial<TokenEntry> = {}): TokenEntry {
  return {
    groupId: '192.168.50.25',
    token: 'token',
    registeredAt: '2026-06-06T00:00:00.000Z',
    ...overrides,
  };
}
