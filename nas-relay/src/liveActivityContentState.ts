import crypto from 'node:crypto';
import jpeg from 'jpeg-js';
import { PNG } from 'pngjs';

import { fetchAlbumArt as defaultFetchAlbumArt } from './hueAlbumArtPalette.js';
import type { LiveActivityContentState, SonosGroupSnapshot } from './types.js';

const THUMBNAIL_SIZE = 60;
const THUMBNAIL_JPEG_QUALITY = 65;
const MAX_THUMBNAIL_BYTES = 15 * 1024;
const MAX_THUMBNAIL_CACHE_ENTRIES = 50;
const thumbnailCache = new Map<string, string | null>();

export interface LiveActivityContentStateDependencies {
  fetchAlbumArt?: (uri: string) => Promise<Buffer>;
}

interface DecodedImage {
  width: number;
  height: number;
  data: Uint8Array;
}

export async function buildLiveActivityContentState(
  snap: SonosGroupSnapshot,
  dependencies: LiveActivityContentStateDependencies = {},
): Promise<LiveActivityContentState> {
  const sampledUnix = snap.sampledAt.getTime() / 1000;
  const startedAtUnix = snap.isPlaying && snap.durationSeconds > 0
    ? sampledUnix - snap.positionSeconds
    : null;
  const endsAtUnix = snap.isPlaying && snap.durationSeconds > 0
    ? sampledUnix + (snap.durationSeconds - snap.positionSeconds)
    : null;

  return {
    trackTitle: snap.trackTitle || 'Not Playing',
    artist: snap.artist || '-',
    album: snap.album,
    isPlaying: snap.isPlaying,
    positionSeconds: snap.positionSeconds,
    durationSeconds: snap.durationSeconds,
    dominantColorHex: null,
    startedAt: startedAtUnix !== null ? toSwiftDate(startedAtUnix) : null,
    endsAt: endsAtUnix !== null ? toSwiftDate(endsAtUnix) : null,
    albumArtThumbnail: await albumArtThumbnailBase64(snap.albumArtUri, dependencies),
    groupMemberCount: snap.groupMemberCount,
    playbackSourceRaw: snap.playbackSourceRaw ?? null,
  };
}

export function hashLiveActivityContentState(state: LiveActivityContentState): string {
  // Hash only the user-visible fields; ignore startedAt/endsAt drift since
  // those move on every poll even when playback is unchanged.
  const projection = {
    t: state.trackTitle,
    a: state.artist,
    al: state.album,
    p: state.isPlaying,
    d: state.durationSeconds,
    s: state.playbackSourceRaw,
    art: state.albumArtThumbnail,
  };
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(projection))
    .digest('hex')
    .slice(0, 16);
}

async function albumArtThumbnailBase64(
  albumArtUri: string | null | undefined,
  dependencies: LiveActivityContentStateDependencies,
): Promise<string | null> {
  if (!albumArtUri) return null;

  const useCache = dependencies.fetchAlbumArt === undefined;
  if (useCache && thumbnailCache.has(albumArtUri)) {
    return thumbnailCache.get(albumArtUri) ?? null;
  }

  try {
    const imageData = await (dependencies.fetchAlbumArt ?? defaultFetchAlbumArt)(albumArtUri);
    const thumbnail = makeJpegThumbnailBase64(imageData);
    if (useCache) rememberThumbnail(albumArtUri, thumbnail);
    return thumbnail;
  } catch {
    if (useCache) rememberThumbnail(albumArtUri, null);
    return null;
  }
}

function rememberThumbnail(albumArtUri: string, thumbnail: string | null): void {
  thumbnailCache.set(albumArtUri, thumbnail);
  while (thumbnailCache.size > MAX_THUMBNAIL_CACHE_ENTRIES) {
    const oldest = thumbnailCache.keys().next().value;
    if (oldest === undefined) return;
    thumbnailCache.delete(oldest);
  }
}

function makeJpegThumbnailBase64(data: Buffer): string {
  const image = decodeImage(data);
  const sourceSide = Math.max(1, Math.min(image.width, image.height));
  const sourceX = Math.floor((image.width - sourceSide) / 2);
  const sourceY = Math.floor((image.height - sourceSide) / 2);
  const target = Buffer.alloc(THUMBNAIL_SIZE * THUMBNAIL_SIZE * 4);

  for (let y = 0; y < THUMBNAIL_SIZE; y += 1) {
    const sy = sourceY + Math.min(sourceSide - 1, Math.floor(((y + 0.5) / THUMBNAIL_SIZE) * sourceSide));
    for (let x = 0; x < THUMBNAIL_SIZE; x += 1) {
      const sx = sourceX + Math.min(sourceSide - 1, Math.floor(((x + 0.5) / THUMBNAIL_SIZE) * sourceSide));
      const sourceIndex = (sy * image.width + sx) * 4;
      const targetIndex = (y * THUMBNAIL_SIZE + x) * 4;
      const alpha = image.data[sourceIndex + 3]! / 255;
      target[targetIndex] = compositeOverBlack(image.data[sourceIndex]!, alpha);
      target[targetIndex + 1] = compositeOverBlack(image.data[sourceIndex + 1]!, alpha);
      target[targetIndex + 2] = compositeOverBlack(image.data[sourceIndex + 2]!, alpha);
      target[targetIndex + 3] = 255;
    }
  }

  const encoded = jpeg.encode(
    { width: THUMBNAIL_SIZE, height: THUMBNAIL_SIZE, data: target },
    THUMBNAIL_JPEG_QUALITY,
  );
  if (encoded.data.length > MAX_THUMBNAIL_BYTES) {
    throw new Error('Live Activity album art thumbnail is too large');
  }
  return encoded.data.toString('base64');
}

function decodeImage(data: Buffer): DecodedImage {
  if (isPng(data)) {
    const png = PNG.sync.read(data);
    return { width: png.width, height: png.height, data: png.data };
  }
  if (isJpeg(data)) {
    const decoded = jpeg.decode(data, { useTArray: true });
    return { width: decoded.width, height: decoded.height, data: decoded.data };
  }
  throw new Error('Unsupported album art image format');
}

function compositeOverBlack(channel: number, alpha: number): number {
  return Math.round(channel * alpha);
}

function isPng(data: Buffer): boolean {
  return data.length >= 8
    && data[0] === 0x89
    && data[1] === 0x50
    && data[2] === 0x4e
    && data[3] === 0x47;
}

function isJpeg(data: Buffer): boolean {
  return data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff;
}

function toSwiftDate(unixSeconds: number): number {
  return unixSeconds - 978307200;
}
