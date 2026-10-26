#if os(iOS)
import SwiftUI

/// Real work drives this status. No simulated percentage or premature success.
struct OperationProgressView: View {
    let title: String
    let detail: String
    var progress: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                if progress == nil { ProgressView() }
                Text(title).font(.subheadline.weight(.semibold))
            }
            if let progress { ProgressView(value: min(1, max(0, progress))) }
            if !detail.isEmpty { Text(detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
