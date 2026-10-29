#if os(iOS)
import SwiftUI
import AVFoundation
import CalcCore

struct WallpaperEditorRequest: Identifiable {
    let id = UUID()
    var source: URL?
    var ownsSource = false
    var libraryID: UUID?
    var edit = WallpaperEdit()
}

struct WallpaperEditor: View {
    let area: AppearanceArea
    let request: WallpaperEditorRequest
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scene
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var edit: WallpaperEdit
    @State private var source: URL?
    @State private var duration = 0.0
    @State private var poster: UIImage?
    @State private var error: String?
    @State private var loading = true
    @State private var saving = false
    @State private var preparingPreview = false
    @State private var previewing = false
    @State private var operation: Task<Void, Never>?
    @State private var previewTask: Task<Void, Never>?
    @State private var active = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var thermal = ProcessInfo.processInfo.thermalState
    @StateObject private var playback = WallpaperPlayback()
    init(area: AppearanceArea, request: WallpaperEditorRequest) {
        self.area = area; self.request = request; _edit = State(initialValue: request.edit)
    }
    private var previewAllowed: Bool { scene == .active && !lowPower && !reduceMotion && thermal != .serious && thermal != .critical }
    private var imageIdentity: String { "\(edit.start)|\(edit.still)|\(source?.path ?? "")" }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let poster {
                        CroppedWallpaper(image: poster, player: previewing && previewAllowed ? playback.player : nil, edit: edit)
                            .aspectRatio(9.0 / 19.5, contentMode: .fit).frame(maxHeight: 310)
                            .clipShape(RoundedRectangle(cornerRadius: 22)).frame(maxWidth: .infinity)
                            .accessibilityLabel("Background preview at the selected still frame")
                    } else { ProgressView("Preparing video…").frame(maxWidth: .infinity, minHeight: 180) }
                    Button(previewing ? "Stop Preview" : "Preview Loop", systemImage: previewing ? "pause.circle" : "play.circle") { previewLoop() }
                        .disabled(loading || saving || preparingPreview || !previewAllowed)
                    if preparingPreview { ProgressView("Preparing silent loop…") }
                    if !previewAllowed { Text("The still frame is shown while motion is disabled.").font(.footnote).foregroundStyle(.secondary) }
                }
                if duration > 0 {
                    Section {
                        labeledSlider("Start", value: $edit.start, range: 0...max(0.001, duration - min(0.5, duration)), suffix: "s")
                        labeledSlider("Loop length", value: $edit.duration, range: min(0.5, duration)...max(min(0.5, duration), min(30, duration - edit.start)), suffix: "s")
                        labeledSlider("Still frame within loop", value: $edit.still, range: 0...max(0.001, edit.duration - 0.01), suffix: "s")
                    } header: { Text("Choose the moment") } footer: { Text("Up to 30 seconds, without sound. The still frame is used in Low Power Mode and when Reduce Motion is enabled.") }
                    Section {
                        labeledSlider("Horizontal position", value: $edit.horizontal, range: 0...1)
                        labeledSlider("Vertical position", value: $edit.vertical, range: 0...1)
                        Button("Center Crop") { edit.horizontal = 0.5; edit.vertical = 0.5 }
                    } header: { Text("Position the crop") } footer: { Text("Move the image within the screen. An edge-to-edge image may have room to move in only one direction. The crop adapts to the device’s shape.") }
                }
                if let error { Section { Text(error).foregroundStyle(.secondary) } }
                if saving { Section { ProgressView("Saving your background…") } }
            }.navigationTitle("Edit Background").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { operation?.cancel(); dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Use Background") { save() }.disabled(loading || saving || source == nil || duration <= 0) }
                }
                .interactiveDismissDisabled(saving)
        }
        .task { await load() }
        .task(id: imageIdentity) {
            guard let source, duration > 0 else { return }
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
                let image = try await WallpaperVideo.poster(source, seconds: edit.start + edit.still)
                try Task.checkCancellation()
                if active { poster = image }
            } catch { if active, !Task.isCancelled { self.error = error.localizedDescription } }
        }
        .onChange(of: edit) { _, value in
            if let normalized = value.normalized(sourceDuration: duration), normalized != edit { edit = normalized }
            previewTask?.cancel(); playback.clear(); previewing = false
        }
        .onChange(of: previewAllowed) { _, allowed in playback.playback(allowed && previewing) }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification).receive(on: RunLoop.main)) { _ in thermal = ProcessInfo.processInfo.thermalState }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in previewTask?.cancel(); playback.clear(); previewing = false }
        .onChange(of: vault.unlocked) { _, unlocked in if area == .library && !unlocked { operation?.cancel(); dismiss() } }
        .onDisappear {
            active = false; operation?.cancel(); previewTask?.cancel(); playback.clear(); poster = nil
            let pending = operation, preview = previewTask
            let file = source ?? request.source
            let owned = request.ownsSource || area == .library
            Task {
                await pending?.value; await preview?.value
                if owned, let file { try? FileManager.default.removeItem(at: file) }
            }
        }
    }
    private func labeledSlider(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text(name); Spacer(); Text(suffix.isEmpty ? "\(Int(value.wrappedValue * 100))%" : String(format: "%.1f", value.wrappedValue) + suffix).monospacedDigit().foregroundStyle(.secondary) }
            if range.upperBound > range.lowerBound {
                Slider(value: value, in: range).accessibilityLabel(name)
            } else {
                Text("The entire clip is selected.").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
    private func load() async {
        let generation = vault.generation
        var temporary: URL?
        var keep = false
        defer { loading = false; if !keep, let temporary { try? FileManager.default.removeItem(at: temporary) } }
        do {
            let file: URL
            if area == .library {
                guard vault.unlocked, let id = request.libraryID,
                      let item = vault.items.first(where: { $0.id == id && $0.visible && $0.deletedAt == nil }),
                      item.byteCount <= WallpaperPolicy.maximumSourceBytes else { throw WallpaperError.invalid }
                try StoragePreflight.require(bytes: Int64(item.byteCount) + 80 * 1024 * 1024)
                file = try TemporaryFiles.fresh(extension: "mov"); temporary = file
                try await vault.engine.materialize(id: id, to: file)
                guard vault.unlocked, generation == vault.generation else { throw VaultError.locked }
            } else if let input = request.source { file = input }
            else { throw WallpaperError.invalid }
            let seconds = try await AVURLAsset(url: file).load(.duration).seconds
            guard let valid = edit.normalized(sourceDuration: seconds) else { throw WallpaperError.invalid }
            let image = try await WallpaperVideo.poster(file, seconds: valid.start + valid.still)
            try Task.checkCancellation()
            guard active, area != .library || (vault.unlocked && generation == vault.generation) else { return }
            duration = seconds; edit = valid; source = file; poster = image; keep = true
        } catch { if active, !Task.isCancelled { self.error = error.localizedDescription } }
    }
    private func previewLoop() {
        if previewing { previewTask?.cancel(); playback.clear(); previewing = false; return }
        guard let source, !preparingPreview else { return }
        preparingPreview = true; let chosen = edit
        previewTask = Task {
            defer { preparingPreview = false }
            do {
                try await playback.preview(source, edit: chosen)
                try Task.checkCancellation()
                guard active, chosen == edit else { playback.clear(); return }
                previewing = true; playback.playback(previewAllowed)
            } catch { if active, !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func save() {
        guard let source, let chosen = edit.normalized(sourceDuration: duration), !saving else { return }
        saving = true; error = nil; previewTask?.cancel(); playback.clear(); previewing = false
        let generation = vault.generation
        operation = Task {
            defer { saving = false }
            var newID: String?
            var loopURL: URL?
            var committed = false
            defer {
                if let loopURL { try? FileManager.default.removeItem(at: loopURL) }
                if !committed, let newID { WallpaperFiles.remove(newID) }
            }
            do {
                let data = try JSONEncoder().encode(chosen)
                let selectedID: String
                if area == .calculator {
                    let bytes = Int64(try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                    try StoragePreflight.require(bytes: bytes + 100 * 1024 * 1024)
                    let prepared = try await WallpaperVideo.prepare(source, edit: chosen); loopURL = prepared
                    try Task.checkCancellation()
                    let id = UUID().uuidString; newID = id
                    let worker = Task.detached(priority: .utility) {
                        try Task.checkCancellation(); try WallpaperFiles.prepareDirectory()
                        guard let target = WallpaperFiles.url(id), let original = WallpaperFiles.source(id) else { throw WallpaperError.invalid }
                        try FileManager.default.copyItem(at: source, to: original)
                        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: original.path)
                        try Task.checkCancellation()
                        try FileManager.default.moveItem(at: prepared, to: target)
                    }
                    try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                    selectedID = id
                } else {
                    guard vault.unlocked, vault.generation == generation, let id = request.libraryID,
                          vault.items.contains(where: { $0.id == id && $0.deletedAt == nil }) else { throw VaultError.locked }
                    loopURL = try await WallpaperVideo.prepare(source, edit: chosen)
                    guard vault.unlocked, vault.generation == generation else { throw VaultError.locked }
                    selectedID = id.uuidString
                }
                try Task.checkCancellation(); guard active else { return }
                let previous = UserDefaults.standard.string(forKey: area.videoKey) ?? ""
                UserDefaults.standard.set(data, forKey: area.editKey)
                UserDefaults.standard.set(selectedID, forKey: area.videoKey)
                UserDefaults.standard.set(WallpaperStyle.video.rawValue, forKey: area.backgroundKey)
                committed = true
                if area == .calculator { WallpaperFiles.remove(previous) }
                dismiss()
            } catch { if active, !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
}
#endif
