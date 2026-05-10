import XCTest
@testable import SonosWidget

final class MusicAmbienceManagerTests: XCTestCase {
    func testAllMappedRoomsStrategyResolvesEveryGroupMemberMapping() {
        let store = makeStore()
        store.isEnabled = true
        store.upsertMapping(HueSonosMapping(
            sonosID: "living",
            sonosName: "Living",
            preferredTarget: .entertainmentArea("ent-living")
        ))
        store.upsertMapping(HueSonosMapping(
            sonosID: "kitchen",
            sonosName: "Kitchen",
            preferredTarget: .entertainmentArea("ent-kitchen")
        ))
        store.groupStrategy = .allMappedRooms

        let manager = MusicAmbienceManager(store: store)
        let snapshot = HueAmbiencePlaybackSnapshot(
            selectedSonosID: "living",
            selectedSonosName: "Living",
            groupMemberIDs: ["living", "kitchen"],
            groupMemberNamesByID: ["living": "Living", "kitchen": "Kitchen"],
            trackTitle: "Song",
            artist: "Artist",
            albumArtURL: "art",
            isPlaying: true,
            albumArtImage: nil
        )

        let targets = manager.mappingsForCurrentPlayback(snapshot)

        XCTAssertEqual(
            targets.map(\.preferredTarget),
            [.entertainmentArea("ent-living"), .entertainmentArea("ent-kitchen")]
        )
    }

    func testCoordinatorOnlyStrategyResolvesSelectedMapping() {
        let store = makeStore()
        store.isEnabled = true
        store.upsertMapping(HueSonosMapping(
            sonosID: "living",
            sonosName: "Living",
            preferredTarget: .entertainmentArea("ent-living")
        ))
        store.upsertMapping(HueSonosMapping(
            sonosID: "kitchen",
            sonosName: "Kitchen",
            preferredTarget: .entertainmentArea("ent-kitchen")
        ))
        store.groupStrategy = .coordinatorOnly

        let manager = MusicAmbienceManager(store: store)
        let snapshot = HueAmbiencePlaybackSnapshot(
            selectedSonosID: "living",
            selectedSonosName: "Living",
            groupMemberIDs: ["living", "kitchen"],
            groupMemberNamesByID: [:],
            trackTitle: "Song",
            artist: "Artist",
            albumArtURL: "art",
            isPlaying: true,
            albumArtImage: nil
        )

        XCTAssertEqual(manager.mappingsForCurrentPlayback(snapshot).map(\.sonosID), ["living"])
    }

    private func makeStore() -> HueAmbienceStore {
        let suiteName = "MusicAmbienceManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return HueAmbienceStore(storage: HueAmbienceDefaults(defaults: defaults))
    }
}
