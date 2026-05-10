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

    func testSnapshotUsesSelectedSpeakerAndVisibleGroupMembers() {
        let selected = SonosPlayer(
            id: "living",
            name: "Living",
            ipAddress: "192.168.1.10",
            isCoordinator: true,
            groupId: "group-1"
        )
        let kitchen = SonosPlayer(
            id: "kitchen",
            name: "Kitchen",
            ipAddress: "192.168.1.11",
            isCoordinator: false,
            groupId: "group-1"
        )
        let info = TrackInfo(
            title: "Song",
            artist: "Artist",
            album: "Album",
            albumArtURL: "https://example.com/art.jpg"
        )

        let snapshot = SonosManager.musicAmbienceSnapshot(
            selectedSpeaker: selected,
            currentGroupMembers: [selected, kitchen],
            trackInfo: info,
            isPlaying: true,
            albumArtData: Data([1, 2, 3])
        )

        XCTAssertEqual(snapshot.selectedSonosID, "living")
        XCTAssertEqual(snapshot.selectedSonosName, "Living")
        XCTAssertEqual(snapshot.groupMemberIDs, ["living", "kitchen"])
        XCTAssertEqual(snapshot.groupMemberNamesByID["kitchen"], "Kitchen")
        XCTAssertEqual(snapshot.trackTitle, "Song")
        XCTAssertEqual(snapshot.artist, "Artist")
        XCTAssertEqual(snapshot.albumArtURL, "https://example.com/art.jpg")
        XCTAssertTrue(snapshot.isPlaying)
        XCTAssertEqual(snapshot.albumArtImage, Data([1, 2, 3]))
    }

    func testAreaOptionsPreferEntertainmentAreasOverRoomsAndZones() {
        let areas = [
            HueAreaResource(id: "room-1", name: "Living Room", kind: .room, childLightIDs: ["light-1"]),
            HueAreaResource(id: "ent-1", name: "Living Sync", kind: .entertainmentArea, childLightIDs: ["light-1"]),
            HueAreaResource(id: "zone-1", name: "Downstairs", kind: .zone, childLightIDs: ["light-2"])
        ]

        let options = HueAmbienceAreaOptions.displayAreas(from: areas)

        XCTAssertEqual(options.map(\.id), ["ent-1"])
    }

    func testAreaOptionsCreateRoomMappingWithGradientCapability() {
        let room = HueAreaResource(id: "room-1", name: "Living Room", kind: .room, childLightIDs: ["light-1"])
        let lights = [
            HueLightResource(
                id: "light-1",
                name: "Gradient Strip",
                ownerID: "room-1",
                supportsColor: true,
                supportsGradient: true,
                supportsEntertainment: true
            )
        ]

        let mapping = HueAmbienceAreaOptions.mapping(
            sonosID: "living",
            sonosName: "Living",
            selectedArea: room,
            lights: lights
        )

        XCTAssertEqual(mapping.preferredTarget, .room("room-1"))
        XCTAssertEqual(mapping.capability, .gradientReady)
    }

    private func makeStore() -> HueAmbienceStore {
        let suiteName = "MusicAmbienceManagerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return HueAmbienceStore(storage: HueAmbienceDefaults(defaults: defaults))
    }
}
