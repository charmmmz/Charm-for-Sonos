# Apple Music Favorites Sheet Design

## Goal

When the user opens the favorite action for an Apple Music-backed item, show a
small control sheet that displays both Sonos Favorites and Apple Music Favorites
state. The user can control each side independently.

## Scope

In scope:

- Songs, albums, artists, and playlists that can be identified as Apple Music
  catalog resources.
- Sonos Favorite add/remove using the existing `SearchManager` methods.
- Apple Music Favorite status read using the resource's `inFavorites`
  attribute.
- Apple Music Favorite add using `POST /v1/me/favorites`.

Out of scope:

- Saving the current Sonos queue as an Apple Music playlist.
- Removing an item from Apple Music Favorites. Apple documents add and
  `inFavorites` reads clearly, but there is no equally clear public remove
  endpoint. The sheet will show existing Apple Music favorites as already
  favorited and leave removal to the Music app for now.
- Apple Music library browsing, recommendations, Replay, and metadata shelves.

## Interaction

Existing favorite actions keep their behavior for non-Apple-Music resources.

For Apple Music resources, tapping the favorite action opens a sheet:

- The header shows the item artwork, title, and artist/subtitle.
- `Sonos Favorites` shows current state and an `Add` or `Remove` button.
- `Apple Music Favorites` loads current state. If not favorited, it shows an
  `Add` button. If already favorited, it shows `Favorited` and disables removal.
- Errors are shown inline in the Apple Music row without blocking Sonos actions.

## Architecture

`AppleMusicFavoritesClient` owns the MusicKit-backed API calls. It exposes:

- resource resolution from `BrowseItem` to Apple Music API resource type and id
- status loading through catalog resource attributes
- add-to-favorites through `MusicDataRequest`

`SearchManager` remains the app-facing coordinator. It keeps the existing Sonos
favorite API and adds lightweight wrappers for Apple Music favorite status and
add operations.

`SearchView` and `FavoriteCategoryDetailView` present the same reusable
`FavoriteControlSheet`. Context menu actions call a shared helper: Apple Music
items open the sheet, other items immediately toggle Sonos Favorites.

## Error Handling

- If MusicKit authorization is denied, Apple Music state shows an authorization
  error and Sonos controls remain available.
- If a Sonos item cannot resolve to a supported Apple Music resource, the app
  falls back to the current Sonos-only behavior.
- If Apple Music add succeeds, the sheet updates optimistically to favorited and
  then can be refreshed later by reopening the sheet.

## Testing

Automated tests cover:

- mapping `BrowseItem.cloudType` to Apple Music API resource types
- extracting catalog ids for tracks from existing Sonos Apple Music URI parsing
- preserving unsupported resource behavior for stations and collections
- encoding the add-to-favorites request payload

Manual verification on a physical iPhone is required for real MusicKit user
authorization and Apple Music account mutation.
