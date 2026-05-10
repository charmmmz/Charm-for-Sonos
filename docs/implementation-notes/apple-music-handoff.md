# Apple Music HANDOFF

## Status

Implemented. The Home screen exposes a single `HANDOFF` action above `UNGROUP`.
The action chooses direction automatically from the selected Sonos target's
transport state:

- Sonos is playing: move Apple Music playback from Sonos to the iPhone.
- Sonos is not playing: move the current iPhone Apple Music track to Sonos.

This avoids a direction picker while keeping the common Home-screen intent
simple: tap HANDOFF to move playback away from the place that is currently
active.

## Supported Flows

### iPhone To Sonos

The app reads the system Music player through MediaPlayer, captures the current
Apple Music title, artist, album, duration, playback position, and available
store identifiers, then searches the linked Apple Music service through Sonos.

Candidate matches are scored by `HandoffMatcher`. Title and artist confidence
matter most; album and duration improve confidence. If no candidate clears the
threshold, the app fails safely instead of playing a weak guess.

After Sonos playback starts, the app seeks near the captured iPhone position
when possible and pauses the iPhone Music player.

### Sonos To iPhone

The reverse path only supports Sonos tracks that resolve to Apple Music. It
starts with the current selected Sonos target, validates the source, and resolves
an Apple Music store ID by trying:

1. The Sonos track URI and object ID.
2. Sonos Cloud now-playing metadata when available.
3. Apple Music search fallback with the same confidence matcher.

The iPhone Music player starts only after a valid store ID is found. Sonos is
paused after iPhone playback succeeds, so a failed reverse handoff does not stop
the current Sonos playback.

## Forward HANDOFF: Apple Music iPhone -> Sonos

Forward HANDOFF still starts from the currently playing Apple Music item on the
iPhone. The app uses Sonos Cloud search to match that current item against the
linked Apple Music account, then attempts a best-effort album context upgrade:

1. Resolve the matched Sonos Cloud track's album/container id.
2. Browse the album through Sonos Cloud.
3. Convert playable album tracks into Sonos `BrowseItem` values.
4. Replace the selected Sonos target's LAN queue with the whole album.
5. Seek the Sonos queue to the matched album track.
6. Seek by time near the iPhone playback position.

The real Apple Music Up Next queue is not used because public iOS APIs do not
expose enumerable entries from the system Music app queue. This feature syncs
album context only. Playlists, stations, radio, and manually edited Up Next
continue to transfer as the current song.

Sonos queue mutation is LAN-only in this app. If the selected target is in
Cloud/remote mode, forward HANDOFF falls back to current-song transfer and
shows `Queue sync requires the same network`.

Remote current-song transfer is best-effort because Sonos Cloud can reject some
service URIs that play normally over LAN.

## Queue Behavior

Reverse handoff is queue-aware for Apple Music queues. When Sonos is playing
from its queue, the app reads the local Sonos queue and current track number,
then builds a Music-player queue from the current item onward.

Important constraints:

- The current item always uses the already-resolved store ID.
- Subsequent items are included when their Sonos URI or object ID resolves to
  an Apple Music store ID.
- Unsupported items are skipped and counted for the success toast.
- The queue is capped by `AppleMusicQueueHandoffPlanner.defaultMaxItems` to
  avoid overbuilding a very long queue.

Radio stations, generic streams, local library tracks, line-in, TV audio, and
other non-Apple-Music sources are intentionally out of scope.

## Main Components

| Component | Responsibility |
| --- | --- |
| `AppleMusicHandoffManager` | Reads and controls `MPMusicPlayerController.systemMusicPlayer` |
| `HandoffMatcher` | Scores Sonos Apple Music search candidates against a captured track |
| `SonosAppleMusicTrackResolver` | Extracts Apple Music store IDs from Sonos URIs, object IDs, and browse items |
| `AppleMusicQueueHandoffPlanner` | Converts a Sonos queue slice into an Apple Music store-ID queue |
| `HandoffDirectionResolver` | Chooses forward or reverse handoff from Sonos transport state |
| `SearchManager` | Orchestrates Sonos Cloud lookup, LAN queue reads, playback, seek, pause, and errors |
| `PlayerView` | Renders the Home `HANDOFF` action and toasts user-visible results |

## User-Facing Errors

The feature prefers explicit failures over surprising playback:

- Apple Music media access is denied.
- The iPhone is not playing an Apple Music track.
- Sonos Cloud is disconnected when search or metadata is required.
- Apple Music is not linked in the Sonos household.
- The selected Sonos target is unavailable.
- The current Sonos source is not Apple Music.
- No confident Apple Music match can be found.
- iPhone playback cannot be started.

## Verification

Automated coverage includes:

- `HandoffMatcherTests`
- `SonosAppleMusicTrackResolverTests`
- `AppleMusicQueueHandoffPlannerTests`
- `HandoffDirectionResolverTests`

Manual checks should use a physical iPhone because the feature depends on the
system Music player and real Sonos playback state.
