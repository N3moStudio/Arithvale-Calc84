#if os(iOS)
import SwiftUI
import CalcCore

enum AppAppearance: String, CaseIterable {
    case system, light, dark
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? { self == .system ? nil : self == .dark ? .dark : .light }
}

enum CalculatorAccent: String, CaseIterable {
    case blue, mint, lilac, amber
    var color: Color {
        switch self {
        case .blue: Color(red: 0.384, green: 0.624, blue: 0.914)
        case .mint: Color(red: 0.482, green: 0.792, blue: 0.710)
        case .lilac: Color(red: 0.702, green: 0.604, blue: 0.878)
        case .amber: Color(red: 0.957, green: 0.714, blue: 0.341)
        }
    }
}

/// Glass belongs to controls. Content remains opaque and fully legible.
struct FloatingLibraryBar: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.25)))
        } else if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 3)
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("galleryStyle") private var style = GalleryStyle.initial.rawValue
    @AppStorage("appAppearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage("calculatorAppearance") private var calculatorAppearance = AppAppearance.dark.rawValue
    @AppStorage("calculatorAccent") private var accent = CalculatorAccent.blue.rawValue
    @AppStorage("libraryDateSource") private var dateSource = LibraryDateSource.captured.rawValue
    @AppStorage("libraryNewestFirst") private var newestFirst = true
    var body: some View {
        List {
            Section("Library layout") {
                ForEach(GalleryStyle.allCases, id: \.rawValue) { option in
                    Button { style = option.rawValue } label: {
                        HStack(spacing: 14) {
                            Image(systemName: symbol(option)).font(.title2).frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.title).font(.body.weight(.medium)).foregroundStyle(.primary)
                                Text(option.subtitle).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if style == option.rawValue { Image(systemName: "checkmark").fontWeight(.semibold) }
                        }.padding(.vertical, 6).frame(minHeight: 44)
                    }.accessibilityAddTraits(style == option.rawValue ? .isSelected : [])
                }
            }
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Dates", selection: $dateSource) {
                    ForEach(LibraryDateSource.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                Toggle("Newest first", isOn: $newestFirst)
            } header: { Text("Library") } footer: { Text("Nightroom always uses a dark background. Each layout keeps its own photo size.") }
            Section("Calculator") {
                Picker("Color", selection: $accent) {
                    ForEach(CalculatorAccent.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                }
                Picker("Appearance", selection: $calculatorAppearance) {
                    ForEach(AppAppearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }
        }.navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline)
    }
    private func symbol(_ style: GalleryStyle) -> String {
        switch style {
        case .clearGlass: "square.on.square"
        case .photoLibrary: "square.grid.3x3"
        case .nightroom: "moon"
        case .albumsFirst: "rectangle.stack"
        case .timeline: "calendar"
        case .contactSheet: "square.grid.4x3.fill"
        }
    }
}
#endif
