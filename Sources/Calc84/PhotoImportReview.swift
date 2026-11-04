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

/// A compact completion card; deletion still verifies the committed originals and
/// asks Photos for system confirmation. Failed imports are never deletion targets.
struct PhotoImportReviewView: View {
    @EnvironmentObject private var vault: VaultModel
    let review: PhotoImportReview
    let close: () -> Void
    @State private var error: String?
    var body: some View {
        VStack(spacing: 20) {
            Text("\(review.imported.formatted()) \(review.imported == 1 ? "Snap Imported" : "Snaps Imported")").font(.title2.bold()).multilineTextAlignment(.center)
            if review.imported < review.requested {
                Text("\(review.requested - review.imported) couldn’t be imported. Their originals are unchanged.").font(.subheadline).foregroundStyle(ArithenPalette.color(.muted))
            }
            if let importError = review.importError { Text(importError).font(.footnote).foregroundStyle(ArithenPalette.color(.muted)) }
            if review.originalCount > 0 {
                Text("Delete \(review.originalCount.formatted()) verified \(review.originalCount == 1 ? "original" : "originals") from Photos?").font(.body).multilineTextAlignment(.center)
                Text("Deletion also syncs with iCloud Photos. Originals go to Recently Deleted.").font(.footnote).foregroundStyle(ArithenPalette.color(.muted)).multilineTextAlignment(.center)
                Button("Delete Originals", role: .destructive) {
                    Task { error = await vault.deleteImportedOriginals(review) }
                }.buttonStyle(ImportButtonStyle())
            }
            if vault.busy { ProgressView("Checking copies…") }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            Button(review.originalCount > 0 ? "Keep Originals" : "Done", action: close)
                .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
        }.padding(24).frame(maxWidth: 360)
            .background(ArithenPalette.color(.surface), in: RoundedRectangle(cornerRadius: 26))
            .disabled(vault.busy).accessibilityAddTraits(.isModal)
    }
}
#endif
