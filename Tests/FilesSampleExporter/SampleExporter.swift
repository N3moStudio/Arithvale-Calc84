import SwiftUI
import UIKit
import CalcCore

// Separate simulator-only application. It can hand disposable samples to Files,
// but has no access to Arithen's sandbox and never supplies a URL to Arithen.
@main
struct SampleExporter: App {
    var body: some Scene { WindowGroup { SampleView() } }
}

private struct SampleView: View {
    @State private var files: [URL] = []
    @State private var exporting = false
    @State private var error: String?
    var body: some View {
        VStack {
            Button("Save samples to Files") {
                do {
                    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let repo = VaultRepository(root: dir.appendingPathComponent("source"))
                    try repo.create(password: "orchard-rain-test-key")
                    _ = try repo.add(data: Data("Rain gauge reading 47".utf8),
                                     name: "Orchard-rain-47.txt", contentType: "public.plain-text")
                    let original = dir.appendingPathComponent("Orchard-sample.arithenbackup")
                    try repo.exportBackup(to: original)
                    let generic = dir.appendingPathComponent("Generic-sample.bin")
                    try FileManager.default.copyItem(at: original, to: generic)
                    let invalid = dir.appendingPathComponent("Invalid-sample.arithenbackup")
                    try Data("Invalid archive sample".utf8).write(to: invalid)
                    let note = dir.appendingPathComponent("River-reading-52.txt")
                    try Data("Gauge 52".utf8).write(to: note)
                    files = [original, generic, invalid, note]
                    exporting = true
                } catch { self.error = error.localizedDescription }
            }
            if let error { Text(error) }
        }.sheet(isPresented: $exporting) { ExportPicker(files: files) }
    }
}

private struct ExportPicker: UIViewControllerRepresentable {
    let files: [URL]
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: files, asCopy: true)
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
}
