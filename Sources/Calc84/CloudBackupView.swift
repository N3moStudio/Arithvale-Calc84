#if os(iOS)
import SwiftUI
import CalcCore

struct CloudBackupView: View {
    var restoring = false
    @EnvironmentObject private var vault: VaultModel
    @EnvironmentObject private var cloud: CloudBackupModel
    @AppStorage("cloudAfterChanges") private var automatic = false
    @AppStorage("cloudUseCellular") private var cellular = false
    var body: some View {
        List {
            Section {
                Label(restoring ? "Bring your memories back" : cloud.phase, systemImage: "lock.icloud")
                    .font(.headline).padding(.vertical, 6)
                if cloud.running {
                    if let progress = cloud.progress { ProgressView(value: progress) }
                    else { ProgressView() }
                    Button("Pause") { cloud.pause() }
                }
                if let error = cloud.error { Text(error).font(.subheadline).foregroundStyle(.secondary) }
                if !restoring {
                    Button("Back Up Now", systemImage: "icloud.and.arrow.up") { cloud.backup(vault: vault) }
                        .disabled(vault.busy || cloud.connected.isEmpty).frame(minHeight: 44)
                }
            } footer: {
                Text(restoring ? "Use the recovery key belonging to the saved library. Cloud sign-in alone cannot decrypt it."
                     : "Originals, thumbnails, and dates are encrypted before upload. Backups stay in your own accounts.")
            }
            Section("Your services") {
                ForEach(CloudProvider.allCases) { provider in
                    NavigationLink {
                        CloudProviderView(provider: provider, restoring: restoring)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(provider.title).font(.headline)
                            Text(summary(provider)).font(.subheadline).foregroundStyle(.secondary)
                            if let date = cloud.receipts[provider]?.saved {
                                Text(date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 5)
                    }
                }
            }
            if !restoring {
                Section("When to back up") {
                    Toggle("Back up after changes", isOn: $automatic)
                    Toggle("Allow cellular data", isOn: $cellular)
                        .onChange(of: cellular) { _, _ in cloud.connectionChanged() }
                }.disabled(vault.busy)
                Section {
                    Text("Keep the app open and unlocked while transferring. Locking pauses the job. Tap Back Up Now to resume; completed files are reused.")
                    Text("Both connections back up the same library. Their storage allowances are not combined. This version does not merge changes from two phones.")
                    Text("Deleting from this phone never deletes cloud backups. Old recovery catalogs are kept; retained files can use extra cloud space.")
                    Text("The first upload includes a download check. Full recovery tests also download everything and need free space on your phone.")
                } header: { Text("How it works") }
            }
        }
        .navigationTitle(restoring ? "Cloud Recovery" : "Cloud Backup").navigationBarTitleDisplayMode(.inline)
        .onAppear { cloud.refresh() }
    }
    private func summary(_ provider: CloudProvider) -> String {
        guard cloud.connected.contains(provider) else { return "Not connected" }
        guard let receipt = cloud.receipts[provider], receipt.saved != nil else { return "Connected · first backup needed" }
        return receipt.needsBackup ? "Changes waiting for backup" : "Latest backup completed"
    }
}

struct CloudProviderView: View {
    let provider: CloudProvider
    var restoring = false
    @EnvironmentObject private var vault: VaultModel
    @EnvironmentObject private var cloud: CloudBackupModel
    @State private var email = ""
    @State private var password = ""
    @State private var appKey = ""
    @State private var code = ""
    @State private var disconnecting = false
    var body: some View {
        List {
            if !cloud.connected.contains(provider) {
                Section {
                    TextField("Email", text: $email).keyboardType(.emailAddress).textContentType(.username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password).textContentType(.password)
                    if provider == .mega {
                        TextField("Verification code, if enabled", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                        TextField("MEGA developer app key", text: $appKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Link("Register a MEGA App Key", destination: URL(string: "https://mega.nz/sdk")!)
                        Text("A developer app key identifies this app; it is different from your MEGA recovery key. Never enter your MEGA recovery key here.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Connect \(provider.title)") {
                        cloud.connect(provider, email: email, password: password, appKey: appKey, code: code, vault: vault)
                        password = ""; code = ""
                    }.disabled(vault.busy || email.isEmpty || password.isEmpty || (provider == .mega && appKey.isEmpty))
                } header: { Text("Connect your account") } footer: { Text("Sign-in goes directly to \(provider.title). Credentials stay in this phone’s Keychain and are not included in backups.") }
            } else {
                Section {
                    Label("Connected", systemImage: "checkmark.circle")
                    if !restoring {
                        Button("Back Up to \(provider.title)") { cloud.backup(vault: vault, only: provider) }.disabled(vault.busy)
                        Button("Recheck All Remote Files") { cloud.backup(vault: vault, only: provider, verifyAll: true) }.disabled(vault.busy)
                    }
                    NavigationLink(restoring ? "Find & Restore a Backup" : "Test Cloud Recovery") {
                        CloudRestoreView(provider: provider, testOnly: !restoring)
                    }.disabled(vault.busy)
                    Button("Disconnect", role: .destructive) { disconnecting = true }.disabled(vault.busy)
                }
            }
            if cloud.running || cloud.error != nil {
                Section {
                    Text(cloud.phase)
                    if cloud.running { ProgressView(); Button("Pause") { cloud.pause() } }
                    if let error = cloud.error { Text(error).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            Section("Your encrypted copy") {
                Text("Your normal gallery stays on this phone. This connection stores separate encrypted files and recovery catalogs in c84/v1 inside your account.")
                Text("Keep your Calc 84 recovery key separately. The cloud service cannot use your calculator code to recover this library.")
                if provider == .blomp {
                    Text("Blomp’s storage connection must pass HTTPS checks. If the service returns an insecure address or an invalid certificate, the connection stops.")
                } else {
                    Text("MEGA’s transfer allowance can delay downloads or verification. If you hit a limit, wait and retry; your previous backup remains available.")
                }
            }
        }
        .navigationTitle(provider.title).navigationBarTitleDisplayMode(.inline)
        .onDisappear { password = ""; code = "" }
        .confirmationDialog("Disconnect \(provider.title)?", isPresented: $disconnecting, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { cloud.disconnect(provider) }
        } message: { Text("Removes this phone’s saved sign-in. Files already backed up are not deleted.") }
    }
}

struct CloudRestoreView: View {
    let provider: CloudProvider
    let testOnly: Bool
    @EnvironmentObject private var vault: VaultModel
    @EnvironmentObject private var cloud: CloudBackupModel
    @State private var selected: UUID?
    @State private var recovery = ""
    @State private var code = ""
    @State private var repeatCode = ""
    var body: some View {
        List {
            Section {
                Text(testOnly ? "Download and authenticate a backup without replacing your library." : "Restore into this empty installation. Your saved capture dates and recovery key stay the same.")
                Button("Find Backups") { cloud.findBackups(provider, vault: vault) }.disabled(vault.busy)
            }
            Section("Saved backups") {
                ForEach(cloud.snapshots) { record in
                    Button { selected = record.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.snapshot.created, format: .dateTime.year().month().day().hour().minute())
                                Text("Library " + String(record.snapshot.vaultID.uuidString.prefix(8))).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected == record.id { Image(systemName: "checkmark").accessibilityLabel("Selected") }
                        }.frame(minHeight: 44)
                    }.disabled(vault.busy)
                }
            }
            if selected != nil {
                Section {
                    SecureField("Calc 84 recovery key", text: $recovery).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !testOnly {
                        SecureField("New calculator code", text: $code).keyboardType(.numberPad)
                        SecureField("Repeat code", text: $repeatCode).keyboardType(.numberPad)
                    }
                    Button(testOnly ? "Test Recovery" : "Restore Library") {
                        if let snapshot = cloud.snapshots.first(where: { $0.id == selected })?.snapshot {
                            cloud.restore(snapshot, provider: provider, recovery: recovery, code: code, vault: vault, testOnly: testOnly)
                            recovery = ""; code = ""; repeatCode = ""
                        }
                    }.disabled(vault.busy || recovery.isEmpty || (!testOnly && (!VaultCode.valid(code) || code != repeatCode)))
                } header: { Text("Unlock the saved library") } footer: { Text("This downloads the backup. Allow up to three times its size in free phone storage while recovery is checked.") }
            }
            Section {
                Text(cloud.phase)
                if cloud.running { ProgressView(); Button("Pause") { cloud.pause() } }
                if let error = cloud.error { Text(error).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(testOnly ? "Test Recovery" : "Restore Library").navigationBarTitleDisplayMode(.inline)
        .onAppear { cloud.snapshots = [] }
        .onDisappear { recovery = ""; code = ""; repeatCode = "" }
    }
}

struct CloudItemStatusView: View {
    let item: VaultItem
    @EnvironmentObject private var cloud: CloudBackupModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section { Text(item.name).font(.headline) }
            ForEach(CloudProvider.allCases) { provider in
                Section(provider.title) {
                    Text(cloud.itemStatus(item, provider: provider))
                    if cloud.receipts[provider]?.itemIDs.contains(item.id) == true, let date = cloud.receipts[provider]?.saved {
                        LabeledContent("Backup saved") { Text(date, format: .dateTime.month().day().hour().minute()) }
                    }
                }
            }
            Section { Text("A completed backup includes the original, its encrypted thumbnail, any Live Photo companion, and stored dates. This status records the last completed backup; it cannot detect files someone later removes from your cloud account.") }
        }.navigationTitle("Backup Status").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { cloud.refresh() }
    }
}
#endif
