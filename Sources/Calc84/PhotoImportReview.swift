#if os(iOS)
import SwiftUI

struct ImportedOriginal {
    let vaultID: UUID
    let source: PhotoOriginal
}

struct PhotoImportReview: Identifiable {
    let id = UUID()
    let imported: Int
    let requested: Int
    let originals: [ImportedOriginal]
    let importError: String?
    var originalCount: Int { Set(originals.map { $0.source.identifier }).count }
    var keptCount: Int { imported - originals.count }
}

struct PhotoImportReviewView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.dismiss) private var dismiss
    let review: PhotoImportReview
    @State private var error: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "checkmark.shield").font(.largeTitle).accessibilityHidden(true)
                    Text("\(review.imported) imported").font(.largeTitle.bold())
                    Text("Your encrypted copies were saved and checked. Keep the originals in Photos, or delete the imported originals you no longer want there.")
                        .foregroundStyle(.secondary)
                    if review.imported < review.requested {
                        Text("\(review.requested - review.imported) weren’t imported. Those originals will stay in Photos.").fontWeight(.semibold)
                    }
                    if let importError = review.importError { Text(importError).font(.footnote).foregroundStyle(.secondary) }
                    if review.keptCount > 0 {
                        Text("\(review.keptCount) imported items can’t be removed here. Photos access may be limited, or they contain edits or extra resources. Their originals will stay.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if review.originalCount > 0 {
                        Text("Deletion also syncs through iCloud Photos when enabled. Originals may remain in Photos → Recently Deleted; this app does not empty it.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Before making the vault your only copy, save and test an external backup.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if vault.busy { HStack { ProgressView(); Text("Checking copies…").font(.subheadline) } }
                    if let error { Text(error).font(.footnote).foregroundStyle(.red).accessibilityLabel("Deletion not completed. " + error) }
                    Button("Keep Originals") { dismiss() }
                        .buttonStyle(.borderedProminent).tint(.primary).frame(maxWidth: .infinity)
                    if review.originalCount > 0 {
                        Button("Delete \(review.originalCount) Imported Originals", role: .destructive) {
                            Task { error = await vault.deleteImportedOriginals(review) }
                        }.frame(maxWidth: .infinity, minHeight: 44)
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Import Complete").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(vault.busy) } }
            .disabled(vault.busy)
        }
        .interactiveDismissDisabled(vault.busy)
    }
}
#endif
