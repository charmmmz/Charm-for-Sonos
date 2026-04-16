import SwiftUI

struct SpeakerPickerView: View {
    @Bindable var manager: SonosManager
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false

    private var visibleSpeakers: [SonosPlayer] {
        var seen = Set<String>()
        return manager.allSpeakers
            .filter { !$0.isInvisible && seen.insert($0.id).inserted }
    }

    private var currentGroupId: String? {
        guard let sel = manager.selectedSpeaker else { return nil }
        return sel.groupId ?? sel.id
    }

    private func isInCurrentGroup(_ speaker: SonosPlayer) -> Bool {
        guard let gid = currentGroupId else { return false }
        return speaker.groupId == gid
    }

    private var accent: Color { manager.albumArtDominantColor ?? .accentColor }

    var body: some View {
        NavigationStack {
            List {
                if visibleSpeakers.isEmpty {
                    ContentUnavailableView("No Speakers Found",
                                           systemImage: "hifispeaker.slash",
                                           description: Text("Make sure your Sonos speakers are on the same network."))
                } else {
                    ForEach(visibleSpeakers) { speaker in
                        speakerRow(speaker)
                    }
                }
            }
            .navigationTitle("Speakers")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(accent)
    }

    private func speakerRow(_ speaker: SonosPlayer) -> some View {
        let inGroup = isInCurrentGroup(speaker)
        let isCoord = speaker.id == manager.selectedSpeaker?.id

        return Button {
            guard !isProcessing else { return }
            Task { await handleTap(speaker, inGroup: inGroup, isCoord: isCoord) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if isProcessing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: inGroup ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(inGroup ? accent : .secondary)
                    }
                }
                .frame(width: 28)

                Image(systemName: "hifispeaker.fill")
                    .font(.title3)
                    .foregroundStyle(inGroup ? accent : .primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(speaker.name)
                        .font(.body.weight(inGroup ? .semibold : .regular))
                    if isCoord {
                        Text("Currently Playing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func handleTap(_ speaker: SonosPlayer, inGroup: Bool, isCoord: Bool) async {
        isProcessing = true
        defer { isProcessing = false }

        if inGroup {
            if isCoord {
                let others = manager.currentGroupMembers.filter { $0.id != speaker.id }
                if let target = others.first {
                    await manager.transferPlayback(to: target)
                }
            } else {
                await manager.removeSpeakerFromGroup(speaker)
            }
        } else {
            await manager.addSpeakerToGroup(speaker)
        }
    }
}
