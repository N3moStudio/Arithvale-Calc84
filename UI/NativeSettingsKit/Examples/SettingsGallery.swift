import SwiftUI
import NativeSettingsKit

/// In-memory demonstration ONLY: no real permissions, storage, backup or account actions.
/// Add the Examples product to a disposable preview host, never the shipping target.
public struct SettingsGallery: View {
    @State private var theme: NSKTheme
    @State private var surface = NSKSurface.solid
    @State private var search = ""
    @State private var notifications = false
    @State private var nickname = "My collection"
    @State private var path: [Destination] = []

    public init(theme: NSKTheme = .bloom) { _theme = State(initialValue: theme) }

    private enum Destination: String, Hashable, CaseIterable {
        case appearance, notifications, collection
        var title: String { rawValue.capitalized }
        var group: String { self == .collection ? "Your data" : "Look & feel" }
        var symbol: String {
            switch self {
            case .appearance: return "paintpalette"
            case .notifications: return "bell"
            case .collection: return "folder"
            }
        }
        var keywords: String {
            switch self {
            case .appearance: return "theme surface solid glass"
            case .notifications: return "alerts sound"
            case .collection: return "name label"
            }
        }
    }

    public var body: some View {
        NavigationStack(path: $path) {
            NSKList {
                if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    NSKSection {
                        NavigationLink(value: Destination.appearance) {
                            NSKIdentityLabel(subtitle: "\(theme.title) · \(surface.title)") {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .resizable().scaledToFit().padding(14)
                                    .foregroundStyle(.white)
                                    .background(.purple.gradient, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    NSKSection("Look & feel") { row(.notifications) }
                    NSKSection("Your data") { row(.collection) }
                    Section {
                        Text("Preview only. Values reset when this demo closes.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.listRowBackground(Color.clear)
                } else {
                    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
                    let matches = Destination.allCases.filter {
                        ($0.title + " " + $0.keywords).localizedCaseInsensitiveContains(query)
                    }
                    if matches.isEmpty {
                        ContentUnavailableView.search(text: search).listRowBackground(Color.clear)
                    } else {
                        NSKSection("Results") { ForEach(matches, id: \.self) { row($0) } }
                    }
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Find a setting")
            // Outside List so destinations remain registered even if their row scrolls away.
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .appearance:
                    NSKAppearanceSettings(theme: $theme, surface: $surface)
                case .notifications:
                    NSKList {
                        NSKSection("Notifications") {
                            Toggle("Allow alerts", isOn: $notifications)
                            Text("Demo switch only; a real app must retain its permission flow.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }.navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
                case .collection:
                    CollectionEditor(name: $nickname)
                }
            }
        }.nativeSettingsAppearance(theme: theme, surface: surface)
    }

    private func row(_ destination: Destination) -> some View {
        NavigationLink(value: destination) {
            NSKRow(destination.title, symbol: destination.symbol,
                   value: destination == .notifications ? (notifications ? "On" : "Off") : nickname)
        }
    }
}

private struct CollectionEditor: View {
    @Binding var name: String
    @State private var showsEditor = false
    var body: some View {
        NSKList {
            NSKSection("Collection") {
                Button { showsEditor = true } label: { NSKRow("Name", symbol: "pencil", value: name) }
            }
        }.navigationTitle("Collection").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsEditor) { NameEditor(name: $name) }
    }
}

private struct NameEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var name: String
    @State private var draft: String
    init(name: Binding<String>) {
        _name = name
        _draft = State(initialValue: name.wrappedValue)
    }
    var body: some View {
        NavigationStack {
            NSKList {
                NSKSection("Name") { TextField("Collection name", text: $draft) }
            }.navigationTitle("Edit name").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { name = draft; dismiss() }
                            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
        // Inherits theme/surface from the presenting view; no second compact-size reduction.
    }
}

#Preview("Bloom - default") { SettingsGallery() }
#Preview("Ion - dark") { SettingsGallery(theme: .ion) }
#Preview("Largest accessibility text") { SettingsGallery().environment(\.dynamicTypeSize, .accessibility5) }
#Preview("Narrow phone") { SettingsGallery().frame(width: 320) }
#Preview("Less transparency, more contrast") {
    SettingsGallery(theme: .glacier)
        .environment(\.accessibilityReduceTransparency, true)
        .environment(\.colorSchemeContrast, .increased)
}
