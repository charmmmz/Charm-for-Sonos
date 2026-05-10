import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class MusicAmbienceManager {
    static let shared = MusicAmbienceManager()

    enum Status: Equatable {
        case disabled
        case unconfigured
        case idle
        case syncing(String)
        case paused(String)
        case error(String)

        var title: String {
            switch self {
            case .disabled:
                return "Disabled"
            case .unconfigured:
                return "Set Up Music Ambience"
            case .idle:
                return "Ready"
            case .syncing(let detail), .paused(let detail):
                return detail
            case .error(let message):
                return message
            }
        }
    }

    private(set) var status: Status = .unconfigured

    @ObservationIgnored private let store: HueAmbienceStore
    @ObservationIgnored private var lastTrackKey: String?
    @ObservationIgnored private var lastPalette: [HueRGBColor] = []

    init(store: HueAmbienceStore? = nil) {
        self.store = store ?? .shared
        refreshStatus()
    }

    func refreshStatus() {
        if !store.isEnabled {
            setStatus(.disabled)
        } else if store.bridge == nil || store.mappings.isEmpty {
            setStatus(.unconfigured)
        } else {
            setStatus(.idle)
        }
    }

    func mappingsForCurrentPlayback(_ snapshot: HueAmbiencePlaybackSnapshot) -> [HueSonosMapping] {
        guard store.isEnabled else { return [] }

        let ids: [String]
        switch store.groupStrategy {
        case .allMappedRooms:
            ids = snapshot.groupMemberIDs.isEmpty
                ? snapshot.selectedSonosID.map { [$0] } ?? []
                : snapshot.groupMemberIDs
        case .coordinatorOnly:
            ids = snapshot.selectedSonosID.map { [$0] } ?? []
        }

        var seenIDs = Set<String>()
        return ids.compactMap { sonosID in
            guard seenIDs.insert(sonosID).inserted else { return nil }
            return store.mapping(forSonosID: sonosID)
        }
    }

    func receive(snapshot: HueAmbiencePlaybackSnapshot) {
        guard store.isEnabled else {
            setStatus(.disabled)
            return
        }
        guard store.bridge != nil else {
            setStatus(.unconfigured)
            return
        }
        guard snapshot.isPlaying else {
            setStatus(.idle)
            return
        }

        let mappings = mappingsForCurrentPlayback(snapshot)
        guard !mappings.isEmpty else {
            setStatus(.paused("No Hue area mapped"))
            return
        }

        let trackKey = [snapshot.trackTitle, snapshot.artist, snapshot.albumArtURL]
            .compactMap { $0 }
            .joined(separator: "|")
        if trackKey != lastTrackKey {
            lastTrackKey = trackKey
            if let data = snapshot.albumArtImage, let image = UIImage(data: data) {
                lastPalette = AlbumPaletteExtractor.palette(from: image)
            }
        }

        setStatus(.syncing("Syncing \(mappings.count) Hue area\(mappings.count == 1 ? "" : "s")"))
    }

    private func setStatus(_ newStatus: Status) {
        status = newStatus
        store.statusText = newStatus.title
    }
}
