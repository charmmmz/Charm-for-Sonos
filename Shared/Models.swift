import Foundation
import SwiftUI
import ActivityKit

// MARK: - Playback Source

enum PlaybackSource: String, Codable, Sendable {
    case spotify
    case appleMusic
    case amazonMusic
    case tidal
    case youtubeMusic
    case airplay
    case radio
    case lineIn
    case library
    case unknown

    var displayName: String {
        switch self {
        case .spotify:      return "Spotify"
        case .appleMusic:   return "Apple Music"
        case .amazonMusic:  return "Amazon Music"
        case .tidal:        return "Tidal"
        case .youtubeMusic: return "YouTube Music"
        case .airplay:      return "AirPlay"
        case .radio:        return "Radio"
        case .lineIn:       return "Line-In"
        case .library:      return "Library"
        case .unknown:      return ""
        }
    }

    var iconName: String {
        switch self {
        case .airplay:  return "airplayaudio"
        case .radio:    return "radio"
        case .lineIn:   return "cable.connector"
        case .library:  return "externaldrive"
        default:        return "music.note"
        }
    }

    var badgeColor: Color {
        switch self {
        case .spotify:      return Color(.sRGB, red: 0.12, green: 0.84, blue: 0.38, opacity: 1)
        case .appleMusic:   return Color(.sRGB, red: 0.98, green: 0.24, blue: 0.35, opacity: 1)
        case .amazonMusic:  return Color(.sRGB, red: 0.14, green: 0.74, blue: 0.85, opacity: 1)
        case .tidal:        return Color(.sRGB, red: 0.0, green: 0.0, blue: 0.0, opacity: 1)
        case .youtubeMusic: return Color(.sRGB, red: 1.0, green: 0.0, blue: 0.0, opacity: 1)
        case .airplay:      return Color(.sRGB, red: 0.0, green: 0.48, blue: 1.0, opacity: 1)
        case .radio:        return Color(.sRGB, red: 1.0, green: 0.58, blue: 0.0, opacity: 1)
        case .lineIn:       return .gray
        case .library:      return .purple
        case .unknown:      return .clear
        }
    }

    static func from(trackURI: String) -> PlaybackSource {
        let uri = trackURI.lowercased()

        if uri.hasPrefix("x-sonos-spotify:") || uri.contains("sid=9&") || uri.hasSuffix("sid=9") {
            return .spotify
        }
        if uri.hasPrefix("x-sonosprog-http:") || uri.contains("sid=204") {
            return .appleMusic
        }
        if uri.contains("sid=203") {
            return .amazonMusic
        }
        if uri.contains("sid=174") {
            return .tidal
        }
        if uri.contains("sid=284") {
            return .youtubeMusic
        }
        if uri.hasPrefix("x-sonos-vli:") || uri.hasPrefix("x-rincon-stream:") {
            return .airplay
        }
        if uri.hasPrefix("x-sonosapi-stream:") || uri.hasPrefix("x-sonosapi-radio:")
            || uri.hasPrefix("x-rincon-mp3radio:") || uri.hasPrefix("aac:") {
            return .radio
        }
        if uri.hasPrefix("x-file-cifs:") || uri.hasPrefix("x-rincon-playlist:") {
            return .library
        }
        return .unknown
    }
}

// MARK: - Speaker

struct SonosPlayer: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var ipAddress: String
    var isCoordinator: Bool
    var groupId: String?
    var coordinatorIP: String?

    var playbackIP: String { coordinatorIP ?? ipAddress }
}

// MARK: - Transport

enum TransportState: String, Codable, Sendable {
    case playing = "PLAYING"
    case paused = "PAUSED_PLAYBACK"
    case stopped = "STOPPED"
    case transitioning = "TRANSITIONING"
    case noMedia = "NO_MEDIA_PRESENT"
    case unknown = "UNKNOWN"
}

// MARK: - Track

struct TrackInfo: Codable, Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var albumArtURL: String?
    var duration: String?
    var position: String?
    var source: PlaybackSource = .unknown

    var durationSeconds: TimeInterval { SonosTime.parse(duration ?? "") }
    var positionSeconds: TimeInterval { SonosTime.parse(position ?? "") }
}

// MARK: - Queue

struct QueueItem: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var albumArtURL: String?
}

// MARK: - Live Activity

struct SonosActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var trackTitle: String
        var artist: String
        var album: String
        var isPlaying: Bool
        var positionSeconds: Double
        var durationSeconds: Double
    }
    var speakerName: String
}

// MARK: - Time Helpers

enum SonosTime {
    nonisolated static func parse(_ str: String) -> TimeInterval {
        let parts = str.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2: return parts[0] * 60 + parts[1]
        default: return 0
        }
    }

    nonisolated static func display(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    nonisolated static func apiFormat(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
