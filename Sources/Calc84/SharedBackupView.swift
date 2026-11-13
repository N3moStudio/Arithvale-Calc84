#if os(iOS)
import SwiftUI
import CalcCore

/// File coordination and copying run outside the main actor, serially.
private actor SharedBackupStorage {
    private let inbox = BackupInbox(root: FileManager.default.urls(for: .applicationSupportDirectory,
        in: .userDomainMask)[0].appendingPathComponent("ArithvaleIncomingBackup", isDirectory: true))
    func load() throws -> BackupInbox.Entry? { try inbox.load() }
    func discard() throws { try inbox.discard() }
    func receive(_ access: BackupSelection) throws -> BackupInbox.Entry {
        defer { withExtendedLifetime(access) {} }
        var failure: NSError?
        var result: Result<BackupInbox.Entry, Error>?
        NSFileCoordinator().coordinate(readingItemAt: access.url, options: [], error: &failure) { url in
            result = Result {
                try BackupFileProbe.validate(url)
                let bytes = Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
                try StoragePreflight.require(bytes: bytes * 2)
                return try inbox.receive(url)
            }
        }
        if let failure { throw failure }
        guard let result else { throw VaultError.invalidBackup }
        return try result.get()
    }
}

/// App lifetime: receiving survives the private form closing on backgrounding.
/// No incoming URL opens, decrypts, or navigates into the private library.
@MainActor
final class SharedBackupModel: ObservableObject {
    @Published private(set) var entry: BackupInbox.Entry?
    @Published private(set) var working = false
    @Published private(set) var error: String?
    private let storage = SharedBackupStorage()
    private var startup: Task<Void, Never>?
    init() {
        startup = Task {
            do { entry = try await storage.load() }
            catch { self.error = "Couldn’t read the received copy. Remove it here and share the original again. " + error.localizedDescription }
        }
    }
    func receive(_ url: URL) {
        do { try BackupInbox.requireLocalFile(url) }
        catch { self.error = error.localizedDescription; return }
        // Acquire permission synchronously, before returning from onOpenURL.
        let access = BackupSelection(url)
        Task {
            await startup?.value
            guard !working else { return } // Duplicate callbacks cannot start another copy.
            guard entry == nil else { error = BackupInbox.InboxError.occupied.localizedDescription; return }
            working = true; error = nil
            defer { working = false }
            do { entry = try await storage.receive(access) }
            catch { self.error = "Couldn’t receive the backup. Download it in Files, then share the file again. " + error.localizedDescription }
        }
    }
    func discard() {
        guard !working else { return }
        working = true
        Task {
            await startup?.value
            defer { working = false }
            do { try await storage.discard(); entry = nil; error = nil }
            catch { self.error = "Couldn’t remove the received copy. " + error.localizedDescription }
        }
    }
}

struct SharedBackupSection: View {
    @EnvironmentObject private var shared: SharedBackupModel
    @EnvironmentObject private var vault: VaultModel
    @ObservedObject var input: BackupInputModel
    var use: () -> Void = {}
    var body: some View {
        Section {
            NavigationLink { SharedBackupGuide() } label: {
                Label("Receive Backup from Files", systemImage: "square.and.arrow.down")
            }
            if shared.working { ProgressView("Receiving encrypted backup…") }
            if let entry = shared.entry {
                Label(entry.displayName, systemImage: "doc.badge.arrow.up")
                    .font(.subheadline).lineLimit(3).textSelection(.enabled)
                Button("Use Received Backup") { use(); input.prepare(entry.url, displayName: entry.displayName) }
                    .disabled(vault.busy || input.working || shared.working)
                    .accessibilityIdentifier("backup.useReceived")
                Text("Received, not yet authenticated. Enter its original recovery key to restore or test it.")
                    .font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
            } else if !shared.working {
                Text("No shared backup received yet.").font(.footnote).foregroundStyle(ArithenPalette.color(.muted))
            }
            if let error = shared.error { Text(error).font(.footnote).foregroundStyle(ArithenPalette.color(.muted)) }
            if shared.entry != nil || shared.error != nil {
                Button("Remove Received Copy", role: .destructive) { shared.discard() }
                    .disabled(vault.busy || input.working || shared.working)
            }
        } header: { Text("Receive without the Picker") } footer: {
            Text("Only an encrypted copy is received. Removing it here leaves the original in Files.")
        }
    }
}

struct SharedImportInstructions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In Files, share the downloaded file, then unlock your library.")
            Text("Direct install: choose Arithen.")
            Text("LiveContainer: choose LiveContainer, then Arithen and your data container.")
        }.font(.subheadline)
    }
}

struct SharedBackupGuide: View {
    var body: some View {
        ThemedList {
            Section("Share from Files") { SharedImportInstructions() }
            Section("Use the received copy") {
                Text("Return here and choose Use Received Backup. Enter the backup's original recovery key to import or check it. Your original file stays in Files.")
            }
            Section("If nothing arrives") {
                Text("Download the file first. Share the file itself, not a folder or collaboration link. If the filename does not appear here, the installer has not delivered it to Arithen.")
            }
        }.navigationTitle("Receive a Backup").navigationBarTitleDisplayMode(.inline)
    }
}
#endif
