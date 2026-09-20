import LauncherCore
import SwiftUI

struct MainWindow: View {
    @Bindable var model: LauncherModel

    var body: some View {
        NavigationSplitView {
            sidebar.navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } content: {
            Group {
                if model.selectedSection == .settings {
                    SettingsView(model: model)
                } else {
                    ContentLibraryView(model: model)
                }
            }
            .navigationSplitViewColumnWidth(min: 420, ideal: 580)
        } detail: {
            LaunchConfigurationView(model: model)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Search addons and DLC", text: $model.search)
                    .textFieldStyle(.roundedBorder).frame(width: 280)
                    .disabled(model.selectedSection == .settings)
            }
            ToolbarItem {
                Button {
                    model.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isScanning || model.handoffBusy)
            }
        }
    }

    private var sidebar: some View {
        List(selection: $model.selectedSection) {
            Section("Library") {
                ForEach(SidebarSection.allCases.filter { $0 != .settings }) { section in
                    Label(section.rawValue, systemImage: section.icon).tag(section)
                }
            }
            Section("Presets") {
                ForEach(model.presets) { preset in
                    Button {
                        model.selectPreset(preset.id)
                    } label: {
                        Label(preset.name, systemImage: "doc")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        model.selectedPresetID == preset.id ? Color.accentColor.opacity(0.18) : nil)
                }
                Button {
                    model.createPreset()
                } label: {
                    Label("New preset", systemImage: "plus")
                }
                .buttonStyle(.plain)
            }
            Section {
                Label(SidebarSection.settings.rawValue, systemImage: SidebarSection.settings.icon)
                    .tag(SidebarSection.settings)
            }
        }
        .listStyle(.sidebar).navigationTitle("Arma 3 Launcher")
    }
}

struct ContentLibraryView: View {
    @Bindable var model: LauncherModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title2.bold())
                    Text("Discovered from your Steam libraries").foregroundStyle(.secondary)
                }
                Spacer()
                if model.isScanning { ProgressView().controlSize(.small) }
            }
            .padding(20)
            Divider()
            if model.isScanning && model.snapshot == nil {
                ContentUnavailableView(
                    "Finding Arma 3", systemImage: "externaldrive.badge.magnifyingglass",
                    description: Text("Reading Steam metadata…"))
            } else if model.filteredContent.isEmpty {
                ContentUnavailableView(
                    "No matching content", systemImage: "puzzlepiece.extension",
                    description: Text("Refresh or choose a Steam library in Settings."))
            } else {
                List(model.filteredContent, selection: $model.selectedItemID) { item in
                    ContentRow(
                        item: item, selected: model.configuration.selectedContentIDs.contains(item.id),
                        artwork: model.artwork[item.id]
                    ) { model.toggle(item) }
                    .tag(item.id)
                }
                .listStyle(.inset)
            }
            if let item = model.snapshot?.content.first(where: { $0.id == model.selectedItemID }) {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    ContentArtworkView(item: item, artwork: model.artwork[item.id], size: 72)
                    Text(item.displayName).font(.headline)
                    Text(item.status).font(.callout).foregroundStyle(.secondary)
                    if item.copies.count > 1 { Text("Copies: \(item.copies.count)").font(.caption) }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }
        }
    }

    private var title: String {
        model.selectedSection == .all ? "Your content" : model.selectedSection.rawValue
    }

}

struct ContentArtworkView: View {
    let item: ContentItem
    let artwork: PresentedArtwork?
    let size: CGFloat

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork.image).resizable().scaledToFit().accessibilityHidden(true)
            } else {
                Image(
                    systemName: item.source == .workshop
                        ? "puzzlepiece.extension.fill" : "shippingbox.fill")
            }
        }
        .frame(width: fittedSize.width, height: fittedSize.height)
        .background(
            artwork.map { canvasColor($0.canvas) } ?? Color.secondary.opacity(0.12),
            in: RoundedRectangle(cornerRadius: size > 40 ? 9 : 7)
        )
        .frame(width: size, height: size).padding(size > 40 ? 6 : 2)
        .accessibilityLabel(artwork == nil ? "No artwork available" : "Artwork for \(item.displayName)")
    }

    private var fittedSize: CGSize {
        guard let dimensions = artwork?.image.size,
            dimensions.width > 0, dimensions.height > 0
        else { return CGSize(width: size, height: size) }
        let scale = size / max(dimensions.width, dimensions.height)
        return CGSize(width: dimensions.width * scale, height: dimensions.height * scale)
    }

    private func canvasColor(_ canvas: ArtworkCanvas) -> Color {
        canvas == .light ? Color(white: 0.88) : Color(white: 0.14)
    }
}

struct ContentRow: View {
    let item: ContentItem
    let selected: Bool
    let artwork: PresentedArtwork?
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .font(.title3).foregroundStyle(selected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!item.availability.allowsSelection || item.source == .platformDLC)
            .accessibilityLabel(selected ? "Disable \(item.displayName)" : "Enable \(item.displayName)")
            ContentArtworkView(item: item, artwork: artwork, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).fontWeight(.medium)
                Text(sourceLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusLabel).font(.caption).foregroundStyle(statusColor)
        }
        .padding(.vertical, 7).contentShape(Rectangle())
    }

    private var sourceLabel: String {
        switch item.source {
        case .workshop: "Steam Workshop"
        case .optionalDLC: "Optional DLC · ownership unverified"
        case .platformDLC: "Platform DLC · managed by game"
        }
    }
    private var statusLabel: String {
        item.availability == .ready ? "Installed" : item.availability.rawValue.capitalized
    }
    private var statusColor: Color { item.availability == .ready ? .secondary : .orange }
}

struct LaunchConfigurationView: View {
    @Bindable var model: LauncherModel
    @State private var advanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Launch configuration").font(.title3.bold())
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Preset").font(.headline)
                        if model.selectedPresetID != nil {
                            TextField(
                                "Preset name",
                                text: Binding(
                                    get: { model.selectedPresetName }, set: model.renameSelectedPreset))
                            Button("Delete preset", role: .destructive) { model.deleteSelectedPreset() }
                                .font(.caption)
                        } else {
                            Text("Current configuration").foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Game version").font(.headline)
                        Picker("Game version", selection: $model.configuration.mode) {
                            ForEach(GameMode.allCases) { mode in
                                Text(mode.title).tag(mode).disabled(!modeAvailable(mode))
                            }
                        }.labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Launch options").font(.headline)
                        Toggle("Skip intro", isOn: $model.configuration.options.skipIntro)
                        Toggle("No splash screens", isOn: $model.configuration.options.noSplash)
                        Toggle("Windowed mode", isOn: $model.configuration.options.windowed)
                    }
                    DisclosureGroup("Advanced options", isExpanded: $advanced) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("One literal argument per line. Shell syntax is not evaluated.")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(
                                "Mod folders load in selection order. Dependency and compatibility checks are not available."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $model.configuration.advancedArguments)
                                .font(.system(.caption, design: .monospaced)).frame(height: 70)
                                .border(.separator)
                            Text("Argument preview").font(.caption.bold())
                            ScrollView {
                                Text(model.planPreview).font(.system(.caption2, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.frame(height: 75)
                        }.padding(.top, 8)
                    }
                    launchStatus
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(spacing: 10) {
                Text(selectionSummary).font(.callout)
                    .foregroundStyle(missingSelectionIDs.isEmpty ? Color.secondary : Color.orange)
                    .frame(maxWidth: .infinity, alignment: .center)
                Button {
                    model.play()
                } label: {
                    Label("Play Arma 3", systemImage: "play.fill").frame(maxWidth: .infinity).padding(
                        .vertical, 6)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.snapshot == nil || model.isScanning || busy)
                HStack {
                    Circle().fill(model.steamRunning ? Color.green : Color.orange).frame(
                        width: 9, height: 9)
                    Text(model.steamRunning ? "Steam is running" : "Steam is not running").font(.caption)
                    Spacer()
                    if !model.steamRunning { Button("Open Steam") { model.openSteam() }.font(.caption) }
                }.foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxHeight: .infinity).padding(16)
        .onChange(of: model.configuration) { _, _ in model.persist() }
    }

    @ViewBuilder private var launchStatus: some View {
        switch model.handoffState {
        case .idle: EmptyView()
        case .validating: Label("Revalidating Steam content…", systemImage: "checkmark.shield")
        case .handingOff: Label("Handing off to LaunchServices…", systemImage: "arrow.up.forward.app")
        case .handedOff(let message), .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Button("Dismiss") { model.clearHandoff() }.font(.caption)
            }
        }
    }

    private var busy: Bool { model.handoffState == .validating || model.handoffState == .handingOff }
    private func modeAvailable(_ mode: GameMode) -> Bool {
        model.snapshot?.installation.selectedGame?.bundles.contains { $0.mode == mode } == true
    }
    private var selectionSummary: String {
        let count = model.configuration.selectedContentIDs.count
        guard !missingSelectionIDs.isEmpty else {
            return "\(count) selected content item\(count == 1 ? "" : "s")"
        }
        return "\(count) selected · Missing: \(missingSelectionIDs.joined(separator: ", "))"
    }
    private var missingSelectionIDs: [String] {
        let known = Set(model.snapshot?.content.map(\.id) ?? [])
        return model.configuration.selectedContentIDs.filter { !known.contains($0) }
    }
}

struct SettingsView: View {
    @Bindable var model: LauncherModel

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $model.appearance) {
                    ForEach(AppAppearance.allCases) { value in Text(value.rawValue).tag(value) }
                }.pickerStyle(.segmented)
                Text("System follows your Mac. Light and Dark apply only to this app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Game installation") {
                LabeledContent(
                    "Detected games", value: "\(model.snapshot?.installation.candidates.count ?? 0)")
                if let game = model.snapshot?.installation.selectedGame {
                    Text(game.directory.path).font(.caption).textSelection(.enabled)
                    Text(game.status).font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Choose Game Folder…") { model.chooseGameFolder() }
                    Button("Add Steam Library…") { model.addSteamLibrary() }
                }
            }
            Section("Steam libraries") {
                if model.explicitSteamRoots.isEmpty {
                    Text("Using automatic Steam discovery").foregroundStyle(.secondary)
                }
                ForEach(model.explicitSteamRoots, id: \.self) { root in
                    Text(root.path).font(.caption).textSelection(.enabled)
                }
            }
            if let error = model.persistenceError {
                Section("Settings file needs attention") {
                    Text(error).foregroundStyle(.red).textSelection(.enabled)
                    Button("Reset Settings File", role: .destructive) { model.resetUnreadableSettings() }
                }
            }
            Section {
                Text(
                    "Arma3Launcher reads Steam and game files in place. It does not copy, move, stage, edit, or symlink Workshop addons."
                )
                .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).padding().navigationTitle("Settings")
    }
}
