import SwiftUI
import UniformTypeIdentifiers
import CalcCore

/// Only this disposable simulator app exposes its Documents folder in Files.
@main
struct SampleExporter: App {
    var body: some Scene { WindowGroup { SampleView() } }
}

private struct SampleView: View {
    @State private var choosing = false
    @State private var ready = false
    @State private var status = ""
    private let downloads = URL.documentsDirectory.appendingPathComponent("Downloads", isDirectory: true)

    var body: some View {
        VStack {
            Button("Export samples to folder") { choosing = true }.disabled(!ready)
            Text(status)
        }.task {
            do {
                try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
                try Data("Local simulator samples".utf8).write(to: downloads.appendingPathComponent("Readme.txt"))
                ready = true
            } catch { status = error.localizedDescription }
        }
        .fileDialogDefaultDirectory(downloads)
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.folder]) { result in
            do {
                let folder = try result.get()
                let access = folder.startAccessingSecurityScopedResource()
                defer { if access { folder.stopAccessingSecurityScopedResource() } }
                let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                let repo = VaultRepository(root: root)
                try repo.create(password: "orchard-rain-test-key")
                _ = try repo.add(data: Data("Rain gauge reading 47".utf8),
                                 name: "Orchard-rain-47.txt", contentType: "public.plain-text")
                var failure: NSError?
                var written: Result<Void, Error>?
                NSFileCoordinator().coordinate(writingItemAt: folder, options: [], error: &failure) { target in
                    written = Result {
                        let archive = target.appendingPathComponent("Orchard-sample.arithenbackup")
                        try repo.exportBackup(to: archive)
                        try FileManager.default.copyItem(at: archive, to: target.appendingPathComponent("Generic-sample.bin"))
                        try Data("Invalid archive sample".utf8).write(to: target.appendingPathComponent("Invalid-sample.arithenbackup"))
                        try Data("Gauge 52".utf8).write(to: target.appendingPathComponent("River-reading-52.txt"))
                    }
                }
                if let failure { throw failure }
                guard let written else { throw CocoaError(.fileWriteUnknown) }
                try written.get()
                status = "Saved four samples to " + folder.lastPathComponent
            } catch { status = error.localizedDescription }
        }
    }
}
