import { EventEmitter } from 'node:events';

import type { Cs2GameStatePayload, Cs2GameStateSnapshot, Cs2GameStateStatus } from './cs2Types.js';

export class Cs2GameStateValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'Cs2GameStateValidationError';
  }
}

export class Cs2GameStateService extends EventEmitter {
  private readonly snapshots = new Map<string, Cs2GameStateSnapshot>();

  receive(payload: Cs2GameStatePayload): Cs2GameStateSnapshot {
    const providerSteamId = providerSteamIdFrom(payload);
    const snapshot: Cs2GameStateSnapshot = {
      providerSteamId,
      receivedAt: new Date(),
      provider: payload.provider!,
      map: payload.map,
      round: payload.round,
      player: payload.player,
      payload,
    };

    this.snapshots.set(providerSteamId, snapshot);
    this.emit('state', snapshot);
    return snapshot;
  }

  latest(providerSteamId: string): Cs2GameStateSnapshot | undefined {
    return this.snapshots.get(providerSteamId);
  }

  all(): Cs2GameStateSnapshot[] {
    return Array.from(this.snapshots.values());
  }

  providers(): string[] {
    return Array.from(this.snapshots.keys());
  }

  status(): Cs2GameStateStatus[] {
    return this.all().map(snapshot => {
      const player = snapshot.player;
      const playerState = player?.state;
      return withoutUndefined({
        providerSteamId: snapshot.providerSteamId,
        playerName: player?.name,
        team: player?.team,
        health: playerState?.health,
        flashed: playerState?.flashed,
        burning: playerState?.burning,
        bomb: snapshot.round?.bomb,
        map: snapshot.map?.name,
      });
    });
  }
}

function providerSteamIdFrom(payload: Cs2GameStatePayload): string {
  const steamId = payload?.provider?.steamid?.trim();
  if (!steamId) {
    throw new Cs2GameStateValidationError('provider.steamid required');
  }
  return steamId;
}

function withoutUndefined<T extends Record<string, unknown>>(value: T): T {
  return Object.fromEntries(
    Object.entries(value).filter(([, entry]) => entry !== undefined),
  ) as T;
}
