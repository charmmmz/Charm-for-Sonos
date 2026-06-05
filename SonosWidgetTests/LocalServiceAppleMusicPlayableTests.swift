import XCTest
@testable import SonosWidget

final class LocalServiceAppleMusicPlayableTests: XCTestCase {
    func testSongPrefersCatalogCandidateOverRawLibraryID() {
        let playable = LocalServiceAppleMusicPlayable.make(
            kind: .song,
            rawID: "i.local-library-song",
            playParameterCandidates: ["1440857781"],
            title: "Nikes",
            artist: "Frank Ocean",
            album: "Blonde",
            artworkURLString: nil,
            duration: 312
        )

        XCTAssertEqual(playable?.catalogID, "1440857781")
        XCTAssertEqual(playable?.sonosObjectID, "100320201440857781")
        XCTAssertEqual(playable?.cloudType, "TRACK")
        XCTAssertFalse(playable?.isContainer ?? true)
    }

    func testAlbumNormalizesNamespacedCatalogCandidate() {
        let playable = LocalServiceAppleMusicPlayable.make(
            kind: .album,
            rawID: "library-album-id",
            playParameterCandidates: ["catalog:albums:1440864059"],
            title: "Blonde",
            artist: "Frank Ocean",
            album: "Blonde",
            artworkURLString: "https://example.com/cover.jpg",
            duration: nil
        )

        XCTAssertEqual(playable?.catalogID, "1440864059")
        XCTAssertEqual(playable?.sonosObjectID, "1440864059")
        XCTAssertEqual(playable?.cloudType, "ALBUM")
        XCTAssertTrue(playable?.isContainer ?? false)
    }

    func testPlaylistKeepsCatalogPlaylistID() {
        let playable = LocalServiceAppleMusicPlayable.make(
            kind: .playlist,
            rawID: "library-playlist-id",
            playParameterCandidates: ["pl.abc123"],
            title: "Sunday",
            artist: "Apple Music",
            album: "",
            artworkURLString: nil,
            duration: nil
        )

        XCTAssertEqual(playable?.catalogID, "pl.abc123")
        XCTAssertEqual(playable?.sonosObjectID, "pl.abc123")
        XCTAssertEqual(playable?.cloudType, "PLAYLIST")
        XCTAssertTrue(playable?.isContainer ?? false)
    }

    func testRejectsLibraryOnlySongID() {
        let playable = LocalServiceAppleMusicPlayable.make(
            kind: .song,
            rawID: "i.local-library-song",
            playParameterCandidates: [],
            title: "Local File",
            artist: "Unknown",
            album: "",
            artworkURLString: nil,
            duration: nil
        )

        XCTAssertNil(playable)
    }
}
