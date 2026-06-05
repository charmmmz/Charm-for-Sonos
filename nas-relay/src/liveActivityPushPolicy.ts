import type { SonosGroupSnapshot, TokenEntry } from './types.js';

export interface LiveActivityPushDecisionOptions {
  force?: boolean;
}

export function shouldPushLiveActivityUpdate(
  token: TokenEntry,
  contentHash: string,
  options: LiveActivityPushDecisionOptions = {},
): boolean {
  return options.force === true || token.lastSentHash !== contentHash;
}

export function shouldForceLiveActivityCalibration(snap: SonosGroupSnapshot): boolean {
  return snap.isPlaying && snap.durationSeconds > 0;
}
