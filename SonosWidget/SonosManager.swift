import Foundation
import SwiftUI
import WidgetKit

@Observable
final class SonosManager {
    var speakers: [SonosPlayer] = []
    var selectedSpeaker: SonosPlayer?
    var trackInfo: TrackInfo?
    var transportState: TransportState = .stopped
    var volume: Int = 0
    var isLoading = false
    var errorMessage: String?
    var albumArtImage: UIImage?
    var showingAddSpeaker = false

    let discovery = SonosDiscovery()

    private var refreshTimer: Timer?
    private var lastAlbumArtURL: String?

    var isPlaying: Bool { transportState == .playing }
    var isConfigured: Bool { selectedSpeaker != nil }

    func loadSavedState() {
        speakers = SharedStorage.savedSpeakers
        if let ip = SharedStorage.speakerIP,
           let speaker = speakers.first(where: { $0.ipAddress == ip }) {
            selectedSpeaker = speaker
            Task { await refreshState() }
        } else if let first = speakers.first {
            selectedSpeaker = first
            SharedStorage.speakerIP = first.ipAddress
            SharedStorage.speakerName = first.name
            Task { await refreshState() }
        } else {
            discovery.startScan()
        }
    }

    func connectFromDiscovery(_ speaker: SonosPlayer) async {
        isLoading = true
        errorMessage = nil

        discovery.stopScan()
        speakers = discovery.discoveredSpeakers
        SharedStorage.savedSpeakers = speakers
        await selectSpeaker(speaker)

        isLoading = false
    }

    func addSpeaker(ip: String) async {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        do {
            let discovered = try await SonosAPI.getZoneGroupState(ip: trimmed)
            if discovered.isEmpty {
                let name = try await SonosAPI.getDeviceName(ip: trimmed)
                speakers = [SonosPlayer(id: UUID().uuidString, name: name, ipAddress: trimmed, isCoordinator: true)]
            } else {
                speakers = discovered
            }
            SharedStorage.savedSpeakers = speakers

            let speaker = speakers.first(where: { $0.isCoordinator }) ?? speakers.first
            if let speaker {
                await selectSpeaker(speaker)
            }
        } catch {
            errorMessage = "Cannot connect to \(trimmed): \(error.localizedDescription)"
        }
        isLoading = false
    }

    func rescan() {
        speakers.removeAll()
        selectedSpeaker = nil
        SharedStorage.savedSpeakers = []
        SharedStorage.speakerIP = nil
        discovery.startScan()
    }

    func selectSpeaker(_ speaker: SonosPlayer) async {
        selectedSpeaker = speaker
        SharedStorage.speakerIP = speaker.ipAddress
        SharedStorage.speakerName = speaker.name
        await refreshState()
    }

    func refreshState() async {
        guard let ip = selectedSpeaker?.ipAddress else { return }
        do {
            transportState = try await SonosAPI.getTransportInfo(ip: ip)
            trackInfo = try await SonosAPI.getPositionInfo(ip: ip)
            volume = try await SonosAPI.getVolume(ip: ip)

            updateSharedCache()
            await loadAlbumArt()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayPause() async {
        guard let ip = selectedSpeaker?.ipAddress else { return }
        do {
            if isPlaying {
                try await SonosAPI.pause(ip: ip)
            } else {
                try await SonosAPI.play(ip: ip)
            }
            try? await Task.sleep(for: .milliseconds(300))
            await refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextTrack() async {
        guard let ip = selectedSpeaker?.ipAddress else { return }
        do {
            try await SonosAPI.next(ip: ip)
            try? await Task.sleep(for: .milliseconds(500))
            await refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previousTrack() async {
        guard let ip = selectedSpeaker?.ipAddress else { return }
        do {
            try await SonosAPI.previous(ip: ip)
            try? await Task.sleep(for: .milliseconds(500))
            await refreshState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateVolume(_ newVolume: Int) async {
        guard let ip = selectedSpeaker?.ipAddress else { return }
        volume = newVolume
        do {
            try await SonosAPI.setVolume(ip: ip, volume: newVolume)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refreshState()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Private

    private func updateSharedCache() {
        SharedStorage.isPlaying = isPlaying
        SharedStorage.cachedTrackTitle = trackInfo?.title
        SharedStorage.cachedArtist = trackInfo?.artist
        SharedStorage.cachedAlbum = trackInfo?.album
        SharedStorage.cachedAlbumArtURL = trackInfo?.albumArtURL
        WidgetCenter.shared.reloadTimelines(ofKind: "SonosWidget")
    }

    private func loadAlbumArt() async {
        guard let urlStr = trackInfo?.albumArtURL, urlStr != lastAlbumArtURL else { return }
        lastAlbumArtURL = urlStr
        guard let url = URL(string: urlStr) else {
            albumArtImage = nil
            SharedStorage.albumArtData = nil
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            albumArtImage = UIImage(data: data)
            SharedStorage.albumArtData = data
        } catch {
            albumArtImage = nil
        }
    }
}
