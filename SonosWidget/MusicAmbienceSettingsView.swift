import SwiftUI

struct MusicAmbienceSettingsView: View {
    @Bindable var store: HueAmbienceStore
    @Bindable var manager: MusicAmbienceManager
    let sonosSpeakers: [SonosPlayer]

    @State private var showingSetup = false

    var body: some View {
        Section {
            statusRow

            Toggle("Enable Music Ambience", isOn: $store.isEnabled)
                .disabled(store.bridge == nil || store.mappings.isEmpty)

            Button {
                showingSetup = true
            } label: {
                Label(
                    store.bridge == nil ? "Set Up Hue Bridge" : "Edit Hue Assignments",
                    systemImage: "sparkles"
                )
            }

            if store.bridge != nil {
                Picker("Group Playback", selection: $store.groupStrategy) {
                    ForEach(HueGroupSyncStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.label).tag(strategy)
                    }
                }
            }
        } header: {
            Text("Hue Music Ambience")
        } footer: {
            Text("Uses album artwork colors for Hue ambience. Without a NAS, continuous background syncing is limited by iOS.")
        }
        .sheet(isPresented: $showingSetup) {
            HueAmbienceSetupSheet(
                store: store,
                manager: manager,
                sonosSpeakers: sonosSpeakers
            )
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(manager.status.title)
                    .font(.subheadline.weight(.semibold))
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        switch manager.status {
        case .disabled:
            return "lightswitch.off"
        case .unconfigured:
            return "link.badge.plus"
        case .idle:
            return "checkmark.circle.fill"
        case .syncing:
            return "sparkles"
        case .paused:
            return "pause.circle"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch manager.status {
        case .syncing, .idle:
            return .green
        case .paused, .unconfigured:
            return .orange
        case .error:
            return .red
        case .disabled:
            return .secondary
        }
    }

    private var statusSubtitle: String {
        if let bridge = store.bridge {
            return "\(bridge.name) · \(store.mappings.count) assignment\(store.mappings.count == 1 ? "" : "s")"
        }
        return "Pair a Hue Bridge and assign Entertainment Areas to Sonos rooms."
    }
}

private struct HueAmbienceSetupSheet: View {
    @Bindable var store: HueAmbienceStore
    @Bindable var manager: MusicAmbienceManager
    let sonosSpeakers: [SonosPlayer]

    @Environment(\.dismiss) private var dismiss
    @State private var bridgeIP = ""
    @State private var bridgeName = "Hue Bridge"

    var body: some View {
        NavigationStack {
            Form {
                bridgeSection
                assignmentsSection
                enhancedSection
            }
            .navigationTitle("Music Ambience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        manager.refreshStatus()
                        dismiss()
                    }
                }
            }
            .onAppear {
                bridgeIP = store.bridge?.ipAddress ?? bridgeIP
                bridgeName = store.bridge?.name ?? bridgeName
            }
        }
    }

    private var bridgeSection: some View {
        Section("Bridge") {
            TextField("192.168.1.20", text: $bridgeIP)
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Hue Bridge", text: $bridgeName)
            Button {
                let trimmedIP = bridgeIP.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedName = bridgeName.trimmingCharacters(in: .whitespacesAndNewlines)
                let id = trimmedIP.replacingOccurrences(of: ".", with: "-")
                store.bridge = HueBridgeInfo(
                    id: id,
                    ipAddress: trimmedIP,
                    name: trimmedName.isEmpty ? "Hue Bridge" : trimmedName
                )
                manager.refreshStatus()
            } label: {
                Label("Save Bridge", systemImage: "link")
            }
            .disabled(bridgeIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var assignmentsSection: some View {
        Section("Assignments") {
            if sonosSpeakers.isEmpty {
                Text("Connect Sonos speakers before assigning Hue areas.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sonosSpeakers) { speaker in
                    HueMappingRow(store: store, manager: manager, speaker: speaker)
                }
            }
        }
    }

    private var enhancedSection: some View {
        Section("NAS Enhanced") {
            LabeledContent("Live Entertainment", value: "Available after NAS runtime is configured")
        }
    }
}

private struct HueMappingRow: View {
    @Bindable var store: HueAmbienceStore
    @Bindable var manager: MusicAmbienceManager
    let speaker: SonosPlayer

    @State private var areaID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(speaker.name)
                .font(.subheadline.weight(.semibold))
            TextField("Entertainment Area ID", text: $areaID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                let trimmedID = areaID.trimmingCharacters(in: .whitespacesAndNewlines)
                store.upsertMapping(HueSonosMapping(
                    sonosID: speaker.id,
                    sonosName: speaker.name,
                    preferredTarget: .entertainmentArea(trimmedID),
                    fallbackTarget: nil,
                    capability: .liveEntertainment
                ))
                manager.refreshStatus()
            } label: {
                Label("Save Assignment", systemImage: "checkmark.circle")
            }
            .disabled(areaID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 2)
        .onAppear {
            if case .entertainmentArea(let id) = store.mapping(forSonosID: speaker.id)?.preferredTarget {
                areaID = id
            }
        }
    }
}
