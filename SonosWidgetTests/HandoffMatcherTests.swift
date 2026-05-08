import XCTest
@testable import SonosWidget

final class HandoffMatcherTests: XCTestCase {
    func testExactTitleArtistAlbumAndDurationMatchWins() {
        let source = AppleMusicHandoffTrack(
            title: "Dark Dune",
            artist: "Demuja",
            album: "Dark Dune",
            duration: 241,
            position: 81,
            playbackStoreID: nil,
            persistentID: nil
        )
        let candidates = [
            makeItem(title: "Dark Dune", artist: "Demuja", album: "Dark Dune", duration: 240),
            makeItem(title: "Dark Dune", artist: "Someone Else", album: "Dark Dune", duration: 240)
        ]

        let match = HandoffMatcher.bestMatch(for: source, candidates: candidates)

        XCTAssertEqual(match?.item.artist, "Demuja")
        XCTAssertGreaterThanOrEqual(match?.score ?? 0, HandoffMatcher.minimumConfidence)
    }

    func testPunctuationAndCaseDoNotPreventMatch() {
        let source = AppleMusicHandoffTrack(
            title: "Josephine (feat. Lisa Hannigan)",
            artist: "RITUAL",
            album: nil,
            duration: 190,
            position: 30,
            playbackStoreID: nil,
            persistentID: nil
        )
        let candidates = [
            makeItem(title: "josephine feat lisa hannigan", artist: "Ritual", album: "", duration: 191)
        ]

        let match = HandoffMatcher.bestMatch(for: source, candidates: candidates)

        XCTAssertNotNil(match)
    }

    func testRemasterSuffixCanStillMatchWhenArtistAndDurationMatch() {
        let source = AppleMusicHandoffTrack(
            title: "Blue Monday",
            artist: "New Order",
            album: "Power Corruption & Lies",
            duration: 449,
            position: 12,
            playbackStoreID: nil,
            persistentID: nil
        )
        let candidates = [
            makeItem(title: "Blue Monday - 2015 Remaster", artist: "New Order", album: "Power Corruption & Lies", duration: 450)
        ]

        let match = HandoffMatcher.bestMatch(for: source, candidates: candidates)

        XCTAssertNotNil(match)
    }

    func testWrongArtistDoesNotCrossThreshold() {
        let source = AppleMusicHandoffTrack(
            title: "Intro",
            artist: "The xx",
            album: "xx",
            duration: 127,
            position: 4,
            playbackStoreID: nil,
            persistentID: nil
        )
        let candidates = [
            makeItem(title: "Intro", artist: "M83", album: "Hurry Up, We're Dreaming", duration: 127)
        ]

        let match = HandoffMatcher.bestMatch(for: source, candidates: candidates)

        XCTAssertNil(match)
    }

    func testLargeDurationMismatchDoesNotCrossThreshold() {
        let source = AppleMusicHandoffTrack(
            title: "Nights",
            artist: "Frank Ocean",
            album: "Blonde",
            duration: 307,
            position: 64,
            playbackStoreID: nil,
            persistentID: nil
        )
        let candidates = [
            makeItem(title: "Nights", artist: "Frank Ocean", album: "Blonde", duration: 90)
        ]

        let match = HandoffMatcher.bestMatch(for: source, candidates: candidates)

        XCTAssertNil(match)
    }

    private func makeItem(title: String, artist: String, album: String, duration: TimeInterval) -> BrowseItem {
        BrowseItem(
            id: UUID().uuidString,
            title: title,
            artist: artist,
            album: album,
            albumArtURL: nil,
            uri: "x-sonos-http:test.mp4?sid=204&flags=8232&sn=1",
            metaXML: nil,
            duration: duration,
            isContainer: false,
            serviceId: 204,
            cloudType: "TRACK"
        )
    }
}
