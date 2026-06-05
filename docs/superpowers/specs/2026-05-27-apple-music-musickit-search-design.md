# Apple Music MusicKit Search Design

## Goal

Use MusicKit for Apple Music search results so Apple Music browsing can avoid
the slower Sonos Cloud search bridge. Playback still goes through the existing
Sonos LAN/Cloud control paths.

## Scope

This is an experiment, not a full search rewrite.

In scope:

- Search Apple Music catalog songs, albums, artists, and playlists with
  `MusicCatalogSearchRequest`.
- Convert MusicKit catalog results into existing `BrowseItem` values using the
  linked Sonos Apple Music account.
- Prefer MusicKit results for Apple Music while leaving non-Apple services on
  Sonos Cloud search.
- Fall back to Sonos Cloud Apple Music search if MusicKit fails, so the app
  remains usable before the MusicKit App Service is enabled.
- Reuse existing detail pages, playback, queue, and favorites UI.

Out of scope:

- Replacing Sonos Cloud search for other services.
- Direct MusicKit playback to the iPhone.
- Apple Music library search or personalized shelves.
- Queue-save-to-Apple-Music playlist features.

## Data Flow

1. User submits a search query.
2. `SearchManager` checks for a linked Apple Music account in Sonos.
3. If Apple Music search is enabled, `AppleMusicCatalogSearchClient` runs a
   MusicKit catalog search.
4. Results become `BrowseItem` values through the same factories used by Sonos
   Cloud resources.
5. Search results show one Apple Music section sourced by MusicKit.
6. Tapping a result still calls existing `playNow`, `playNext`, and
   `addToQueue` methods, so Sonos remains the playback backend.

## Error Handling

- If MusicKit authorization or developer-token setup fails, Apple Music falls
  back to the existing Sonos Cloud search path.
- If the selected Sonos household does not have Apple Music linked, MusicKit
  results are skipped because they cannot be turned into Sonos playback URIs.
- Non-Apple Music services keep the current Sonos Cloud behavior.

## Testing

Automated tests cover the local catalog-result model and conversion decisions.
The live MusicKit search and Sonos playback handoff require device testing with
MusicKit enabled.
