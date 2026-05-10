import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { test } from 'node:test';
import { SonosEvents } from '@svrooij/sonos';
import pino from 'pino';

import { albumArtUriFromMetadata, SonosBridge, trackMetadataFromMetadata } from './sonos.js';

test('album art extraction accepts parsed Sonos Track metadata objects', () => {
  assert.equal(
    albumArtUriFromMetadata({ AlbumArtUri: '/getaa?s=1&u=x-sonos-http%3atrack' }),
    '/getaa?s=1&u=x-sonos-http%3atrack',
  );
});

test('album art extraction accepts raw DIDL strings', () => {
  assert.equal(
    albumArtUriFromMetadata(
      '<DIDL-Lite><item><upnp:albumArtURI>/getaa?s=1&amp;u=x-sonos-http%3atrack</upnp:albumArtURI></item></DIDL-Lite>',
    ),
    '/getaa?s=1&u=x-sonos-http%3atrack',
  );
});

test('track metadata extraction accepts raw DIDL strings', () => {
  assert.deepEqual(
    trackMetadataFromMetadata(
      '<DIDL-Lite><item><dc:title>Blue Train</dc:title><dc:creator>John Coltrane</dc:creator><upnp:album>Blue Train</upnp:album><upnp:albumArtURI>/getaa?s=1&amp;u=x-sonos-http%3atrack</upnp:albumArtURI></item></DIDL-Lite>',
    ),
    {
      title: 'Blue Train',
      artist: 'John Coltrane',
      album: 'Blue Train',
      albumArtUri: '/getaa?s=1&u=x-sonos-http%3atrack',
    },
  );
});

test('track metadata extraction accepts parsed Sonos Track metadata objects', () => {
  assert.deepEqual(
    trackMetadataFromMetadata({
      Title: 'Teardrop',
      Artist: 'Massive Attack',
      Album: 'Mezzanine',
      AlbumArtUri: '/getaa?s=1&u=x-sonos-http%3ateardrop',
    }),
    {
      title: 'Teardrop',
      artist: 'Massive Attack',
      album: 'Mezzanine',
      albumArtUri: '/getaa?s=1&u=x-sonos-http%3ateardrop',
    },
  );
});

test('bridge refreshes snapshots when the Sonos library emits real event names', () => {
  const bridge = new SonosBridge(pino({ enabled: false }));
  const events = new EventEmitter();
  const refreshedDevices: string[] = [];
  const device = { Name: 'Office', Events: events };

  (bridge as unknown as { refreshSnapshot: (device: unknown) => Promise<void> }).refreshSnapshot = async refreshed => {
    refreshedDevices.push((refreshed as { Name: string }).Name);
  };
  (bridge as unknown as { attachDeviceListeners: (device: unknown) => void }).attachDeviceListeners(device);

  events.emit(SonosEvents.AVTransport, {});
  events.emit(SonosEvents.CurrentTrackUri, 'x-rincon-queue:RINCON_1#0');
  events.emit(SonosEvents.CurrentTrackMetadata, { Title: 'Blue Train' });
  events.emit(SonosEvents.CurrentTransportState, 'PLAYING');
  events.emit(SonosEvents.CurrentTransportStateSimple, 'PLAYING');
  events.emit(SonosEvents.PlaybackStopped);
  events.emit(SonosEvents.GroupName, 'Office');

  assert.deepEqual(refreshedDevices, [
    'Office',
    'Office',
    'Office',
    'Office',
    'Office',
    'Office',
    'Office',
  ]);
});
