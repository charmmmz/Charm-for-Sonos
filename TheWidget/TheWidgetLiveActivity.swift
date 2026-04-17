import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct SonosLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SonosActivityAttributes.self) { context in
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ArtView(data: context.state.albumArtThumbnail, size: 50)
                        .padding(.leading, 2)
                        .padding(.trailing, 6)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                DynamicIslandExpandedRegion(.center) {
                    let accent = themeColor(from: context.state.dominantColorHex)
                    let extra = context.state.groupMemberCount > 1
                        ? " + \(context.state.groupMemberCount - 1)" : ""
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.trackTitle)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(context.state.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("ON \(context.attributes.speakerName.uppercased())\(extra)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(accent.opacity(0.8))
                                .lineLimit(1)
                            if context.state.isPlaying {
                                AnimatedWaveform(accent: accent, barCount: 3, height: 7)
                            }
                        }
                        .padding(.top, 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    let source = context.state.playbackSourceRaw
                        .flatMap(PlaybackSource.init(rawValue:)) ?? .unknown
                    VStack(alignment: .trailing, spacing: 4) {
                        if source != .unknown {
                            SourceBadgeView(source: source,
                                            tintColor: themeColor(from: context.state.dominantColorHex),
                                            compact: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.trailing, 4)
                    .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let accent = themeColor(from: context.state.dominantColorHex)
                    VStack(spacing: 8) {
                        LiveProgressView(state: context.state)
                        HStack(spacing: 40) {
                            Button(intent: PreviousTrackIntent()) {
                                Image(systemName: "backward.fill")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.85))
                            }.buttonStyle(.plain)

                            Button(intent: PlayPauseIntent()) {
                                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundStyle(accent)
                            }.buttonStyle(.plain)

                            Button(intent: NextTrackIntent()) {
                                Image(systemName: "forward.fill")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.85))
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            } compactLeading: {
                // Compact/minimal views are static-only per Apple docs — no animation supported.
                ArtView(data: context.state.albumArtThumbnail, size: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } compactTrailing: {
                // Compact/minimal regions are static-only — no animation supported by Apple.
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: context.state.isPlaying ? 12 : 10, weight: .medium))
                    .foregroundStyle(themeColor(from: context.state.dominantColorHex))
                    .padding(.trailing, 4)
            } minimal: {
                ArtView(data: context.state.albumArtThumbnail, size: 20)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let context: ActivityViewContext<SonosActivityAttributes>

    var body: some View {
        let accent = themeColor(from: context.state.dominantColorHex)
        let extra = context.state.groupMemberCount > 1
            ? " + \(context.state.groupMemberCount - 1)" : ""
        let source = context.state.playbackSourceRaw
            .flatMap(PlaybackSource.init(rawValue:)) ?? .unknown

        VStack(spacing: 6) {
            // ── Single row: art | text | controls ──
            HStack(spacing: 12) {
                ArtView(data: context.state.albumArtThumbnail, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.trackTitle)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text(context.state.artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text("ON \(context.attributes.speakerName.uppercased())\(extra)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.8))
                            .lineLimit(1)
                        if context.state.isPlaying {
                            AnimatedWaveform(accent: accent, barCount: 4, height: 8)
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.fill").font(.callout)
                    }.buttonStyle(.plain)

                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(accent)
                    }.buttonStyle(.plain)

                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.fill").font(.callout)
                    }.buttonStyle(.plain)
                }
            }

            // ── Progress bar ──
            LiveProgressView(state: context.state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            ZStack {
                if let data = context.state.albumArtThumbnail,
                   let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 40)
                        .scaleEffect(1.5)
                        .clipped()
                }
                LinearGradient(
                    colors: [.black.opacity(0.55), .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Animated Waveform (lock screen + expanded DI only)
// Compact/minimal Dynamic Island does NOT support animation.
//
// SF Symbol system animations are driven by the OS renderer — the only reliable way
// to get continuous animation in a Live Activity extension process.

private struct AnimatedWaveform: View {
    let accent: Color
    var barCount: Int = 4
    var height: CGFloat = 10

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.08)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h = 0.25 + 0.75 * abs(sin(t * 5.0 + Double(i) * 1.3))
                    Capsule()
                        .frame(width: 2, height: height * h)
                }
            }
            .frame(height: height)
            .foregroundStyle(accent)
        }
    }
}

// MARK: - Real-time Progress

private struct LiveProgressView: View {
    let state: SonosActivityAttributes.ContentState

    var body: some View {
        let accent = themeColor(from: state.dominantColorHex)

        if state.isPlaying,
           let start = state.startedAt,
           let end = state.endsAt,
           end > Date() {
            ProgressView(timerInterval: start...end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(accent)
        } else if state.durationSeconds > 0 {
            ProgressView(value: state.positionSeconds, total: state.durationSeconds)
                .progressViewStyle(.linear)
                .tint(accent)
        }
    }
}

// MARK: - Album Art

private struct ArtView: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        if let data, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
        } else {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(Color.white.opacity(0.15))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.38))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Helpers

private func themeColor(from hex: String?) -> Color {
    hex.flatMap { Color(hex: $0) } ?? .white
}
