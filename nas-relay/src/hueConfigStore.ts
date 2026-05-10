import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';

import type { HueAmbienceRuntimeConfig, HueAmbienceStatus } from './hueTypes.js';

const DEFAULT_FILE_NAME = 'hue-ambience-config.json';

export class HueAmbienceConfigStore {
  private currentConfig: HueAmbienceRuntimeConfig | null = null;
  private readonly filePath: string;

  constructor(dataDir: string, filePath = process.env.HUE_AMBIENCE_CONFIG_PATH) {
    this.filePath = filePath && filePath.trim().length > 0
      ? filePath
      : path.join(dataDir, DEFAULT_FILE_NAME);
  }

  get configPath(): string {
    return this.filePath;
  }

  get current(): HueAmbienceRuntimeConfig | null {
    return this.currentConfig;
  }

  async load(): Promise<HueAmbienceRuntimeConfig | null> {
    try {
      const raw = await readFile(this.filePath, 'utf8');
      const parsed = JSON.parse(raw) as HueAmbienceRuntimeConfig;
      this.currentConfig = normalizeConfig(parsed);
      return this.currentConfig;
    } catch (err: any) {
      if (err?.code === 'ENOENT') {
        this.currentConfig = null;
        return null;
      }
      throw err;
    }
  }

  async save(config: HueAmbienceRuntimeConfig): Promise<void> {
    this.currentConfig = normalizeConfig(config);
    await mkdir(path.dirname(this.filePath), { recursive: true });
    await writeFile(this.filePath, `${JSON.stringify(this.currentConfig, null, 2)}\n`, 'utf8');
  }

  async clear(): Promise<void> {
    this.currentConfig = null;
    await rm(this.filePath, { force: true });
  }

  status(): HueAmbienceStatus {
    if (!this.currentConfig) {
      return { configured: false };
    }

    return {
      configured: true,
      enabled: this.currentConfig.enabled,
      bridge: this.currentConfig.bridge,
      mappings: this.currentConfig.mappings.length,
      lights: this.currentConfig.resources.lights.length,
      areas: this.currentConfig.resources.areas.length,
      motionStyle: this.currentConfig.motionStyle,
      stopBehavior: this.currentConfig.stopBehavior,
    };
  }
}

function normalizeConfig(config: HueAmbienceRuntimeConfig): HueAmbienceRuntimeConfig {
  return {
    ...config,
    enabled: config.enabled && (process.env.HUE_AMBIENCE_ENABLED ?? 'true') !== 'false',
    resources: {
      lights: config.resources?.lights ?? [],
      areas: config.resources?.areas ?? [],
    },
    mappings: (config.mappings ?? []).map(mapping => ({
      ...mapping,
      includedLightIDs: mapping.includedLightIDs ?? [],
      excludedLightIDs: mapping.excludedLightIDs ?? [],
    })),
    groupStrategy: config.groupStrategy ?? 'allMappedRooms',
    stopBehavior: config.stopBehavior ?? 'leaveCurrent',
    motionStyle: config.motionStyle ?? 'flowing',
    flowIntervalSeconds: Math.max(config.flowIntervalSeconds ?? 8, 1),
  };
}
