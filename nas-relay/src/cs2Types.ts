export interface Cs2Provider {
  name?: string;
  appid?: number;
  version?: number;
  steamid?: string;
  timestamp?: number;
}

export interface Cs2TeamMapDetails {
  score?: number;
  consecutive_round_losses?: number;
  timeouts_remaining?: number;
  matches_won_this_series?: number;
}

export interface Cs2Map {
  mode?: string;
  name?: string;
  phase?: string;
  round?: number;
  team_t?: Cs2TeamMapDetails;
  team_ct?: Cs2TeamMapDetails;
}

export interface Cs2Round {
  phase?: string;
  win_team?: string;
  bomb?: string;
}

export interface Cs2PlayerState {
  health?: number;
  armor?: number;
  helmet?: boolean;
  flashed?: number;
  smoked?: number;
  burning?: number;
  money?: number;
  round_kills?: number;
  round_killhs?: number;
  equip_value?: number;
}

export interface Cs2PlayerMatchStats {
  kills?: number;
  assists?: number;
  deaths?: number;
  mvps?: number;
  score?: number;
}

export interface Cs2Player {
  steamid?: string;
  name?: string;
  team?: string;
  activity?: string;
  state?: Cs2PlayerState;
  match_stats?: Cs2PlayerMatchStats;
}

export interface Cs2GameStatePayload {
  provider?: Cs2Provider;
  map?: Cs2Map;
  round?: Cs2Round;
  player?: Cs2Player;
  previously?: unknown;
  added?: unknown;
  auth?: unknown;
}

export interface Cs2GameStateSnapshot {
  providerSteamId: string;
  receivedAt: Date;
  sourceIp?: string;
  provider: Cs2Provider;
  map?: Cs2Map;
  round?: Cs2Round;
  player?: Cs2Player;
  payload: Cs2GameStatePayload;
}

export interface Cs2GameStateReceiveMetadata {
  sourceIp?: string;
}

export interface Cs2DebugSample {
  providerSteamId: string;
  receivedAt: string;
  sourceIp?: string;
  payload: Cs2GameStatePayload;
}

export interface Cs2GameStateStatus {
  providerSteamId: string;
  playerName?: string;
  team?: string;
  health?: number;
  flashed?: number;
  burning?: number;
  bomb?: string;
  map?: string;
}
