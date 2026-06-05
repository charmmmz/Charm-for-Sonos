import Foundation
import MusicKit
import Observation

@MainActor
@Observable
final class LocalLibraryStore {
    private let client: LocalMusicLibraryClient

    var authorizationStatus = MusicAuthorization.currentStatus
    var snapshot = LocalMusicLibrarySnapshot()
    var recentlyPlayed: [RecentlyPlayedMusicItem] = []
    var recommendations: [MusicPersonalRecommendation] = []
    var searchSnapshot: LocalMusicLibrarySnapshot?
    var isLoading = false
    var isSearching = false
    var isStartingPlayback = false
    var activePlaybackItemID: String?
    var errorMessage: String?
    var hasLoaded = false

    convenience init() {
        self.init(client: .shared)
    }

    init(client: LocalMusicLibraryClient) {
        self.client = client
    }

    var displayedSnapshot: LocalMusicLibrarySnapshot {
        searchSnapshot ?? snapshot
    }

    var hasHomeContent: Bool {
        !snapshot.isEmpty || !recentlyPlayed.isEmpty || !recommendations.isEmpty
    }

    var summary: LocalLibrarySnapshotSummary {
        displayedSnapshot.summary
    }

    func itemsAreEmpty(for category: LocalLibraryCategory) -> Bool {
        summary.count(for: category) == 0
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            authorizationStatus = try await client.authorize()
            let content = try await client.loadHomeContent()
            snapshot = content.snapshot
            recentlyPlayed = content.recentlyPlayed
            recommendations = content.recommendations
            searchSnapshot = nil
            hasLoaded = true
        } catch {
            authorizationStatus = MusicAuthorization.currentStatus
            errorMessage = displayMessage(for: error)
        }
    }

    func search(term: String) async {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchSnapshot = nil
            isSearching = false
            return
        }

        isSearching = true
        errorMessage = nil
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }

        do {
            authorizationStatus = try await client.authorize()
            searchSnapshot = try await client.search(term: trimmed)
        } catch {
            guard !Task.isCancelled else { return }
            searchSnapshot = nil
            authorizationStatus = MusicAuthorization.currentStatus
            errorMessage = displayMessage(for: error)
        }

        isSearching = false
    }

    func play(song: Song) async {
        await runPlayback(id: song.id.rawValue) {
            try await client.play(song: song)
        }
    }

    func play(track: Track) async {
        await runPlayback(id: track.id.rawValue) {
            try await client.play(track: track)
        }
    }

    func play(album: Album) async {
        await runPlayback(id: album.id.rawValue) {
            try await client.play(album: album)
        }
    }

    func play(recentlyPlayed item: RecentlyPlayedMusicItem) async {
        await runPlayback(id: item.id.rawValue) {
            try await client.play(recentlyPlayed: item)
        }
    }

    func play(recommendation item: MusicPersonalRecommendation.Item) async {
        await runPlayback(id: item.id.rawValue) {
            try await client.play(recommendation: item)
        }
    }

    func play(artist: Artist) async {
        await runPlayback(id: artist.id.rawValue) {
            try await client.play(artist: artist)
        }
    }

    func play(playlist: Playlist) async {
        await runPlayback(id: playlist.id.rawValue) {
            try await client.play(playlist: playlist)
        }
    }

    func play(station: Station) async {
        await runPlayback(id: station.id.rawValue) {
            try await client.play(station: station)
        }
    }

    func playOnSonos(
        playable: LocalServiceAppleMusicPlayable?,
        displayID: String,
        manager: SonosManager,
        searchManager: SearchManager
    ) async {
        await runPlayback(id: displayID) {
            guard let playable else {
                throw LocalServiceSonosPlaybackError.noPlayableCatalogID
            }

            let didStart = await searchManager.playLocalAppleMusic(playable, manager: manager)
            guard didStart else {
                throw LocalServiceSonosPlaybackError.playbackFailed(searchManager.errorMessage)
            }
        }
    }

    private func runPlayback(id: String, action: () async throws -> Void) async {
        isStartingPlayback = true
        activePlaybackItemID = id
        errorMessage = nil
        defer { isStartingPlayback = false }

        do {
            try await action()
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    private func displayMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
