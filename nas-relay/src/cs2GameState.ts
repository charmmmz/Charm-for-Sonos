import { EventEmitter } from 'node:events';

import type {
  Cs2DebugSample,
  Cs2GameStatePayload,
  Cs2GameStateReceiveMetadata,
  Cs2GameStateSnapshot,
  Cs2GameStateStatus,
} from './cs2Types.js';

export class Cs2GameStateValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'Cs2GameStateValidationError';
  }
}

export class Cs2GameStateService extends EventEmitter {
  private readonly debugSampleLimit: number;
  private readonly snapshots = new Map<string, Cs2GameStateSnapshot>();
  private readonly recentDebugSamples: Cs2DebugSample[] = [];

  constructor(options: { debugSampleLimit?: number } = {}) {
    super();
    this.debugSampleLimit = Math.max(0, Math.floor(options.debugSampleLimit ?? 25));
  }

  receive(payload: Cs2GameStatePayload, metadata: Cs2GameStateReceiveMetadata = {}): Cs2GameStateSnapshot {
    const providerSteamId = providerSteamIdFrom(payload);
    const snapshot: Cs2GameStateSnapshot = {
      providerSteamId,
      receivedAt: new Date(),
      sourceIp: metadata.sourceIp,
      provider: payload.provider!,
      map: payload.map,
      round: payload.round,
      player: payload.player,
      payload,
    };

    this.snapshots.set(providerSteamId, snapshot);
    const debugSample = this.toDebugSample(snapshot);
    this.rememberDebugSample(debugSample);
    this.emit('state', snapshot);
    this.emit('debug-sample', debugSample);
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

  debugSamples(): Cs2DebugSample[] {
    return [...this.recentDebugSamples];
  }

  clearDebugSamples(): void {
    this.recentDebugSamples.length = 0;
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

  private toDebugSample(snapshot: Cs2GameStateSnapshot): Cs2DebugSample {
    return withoutUndefined({
      providerSteamId: snapshot.providerSteamId,
      receivedAt: snapshot.receivedAt.toISOString(),
      sourceIp: snapshot.sourceIp,
      payload: snapshot.payload,
    });
  }

  private rememberDebugSample(sample: Cs2DebugSample): void {
    if (this.debugSampleLimit === 0) return;
    this.recentDebugSamples.push(sample);
    while (this.recentDebugSamples.length > this.debugSampleLimit) {
      this.recentDebugSamples.shift();
    }
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
