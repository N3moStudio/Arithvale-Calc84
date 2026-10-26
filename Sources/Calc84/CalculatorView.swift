#if os(iOS)
import SwiftUI
import CalcCore

enum CalcTheme {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.76, green: 0.67, blue: 0.95, alpha: 1)
        : UIColor(red: 0.39, green: 0.28, blue: 0.64, alpha: 1) })
    static let display = Color(uiColor: .secondarySystemBackground)
}

private struct CalculationRecord: Identifiable {
    let id = UUID()
    let expression: String
    let result: String
}

struct CalculatorView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    @AppStorage("calculatorGlassTint") private var glassTintValue = GlassTint.plum.rawValue
    @AppStorage("calculatorAppearance") private var appearance = AppAppearance.dark.rawValue
    @State private var expression = ""
    @State private var result = "0"
    @State private var degrees = true
    @State private var scientific = false
    @State private var didEvaluate = false
    @State private var access = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var history: [CalculationRecord] = []
    private var dark: Bool { appearance == "dark" || (appearance == "system" && scheme == .dark) }
    private var ink: Color { dark ? Color(white: 0.98) : Color(white: 0.08) }
    private var glassTint: GlassTint { GlassTint(rawValue: glassTintValue) ?? .plum }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = min(geometry.size.width - 36, 390)
            let side = max(44, min((availableWidth - 21) / 4, (geometry.size.height - 215) / 5))
            ScrollView {
                ArithenGlassGroup {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Button("History", systemImage: "clock.arrow.circlepath") { showingHistory = true }
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                            .modifier(ArithenGlass(tint: glassTint, shape: Circle()))
                        Spacer(minLength: 2)
                        Text(AppBrand.name).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 2)
                        Menu {
                            Button(scientific ? "Basic Calculator" : "Scientific Calculator") { scientific.toggle() }
                            Button(degrees ? "Use Radians" : "Use Degrees") { degrees.toggle() }
                        } label: {
                            Image(systemName: "calculator").frame(width: 44, height: 44).modifier(ArithenGlass(tint: glassTint, shape: Circle()))
                        }.accessibilityLabel("Calculator mode")
                        Button("Settings", systemImage: "gearshape") { showingSettings = true }
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                            .modifier(ArithenGlass(tint: glassTint, shape: Circle()))
                    }.padding(.top, 6)
                    Spacer(minLength: 32)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(expression.isEmpty ? " " : expression).font(.title3).foregroundStyle(ink.opacity(0.52))
                            .lineLimit(2).minimumScaleFactor(0.65)
                        Text(didEvaluate || expression.isEmpty ? result : expression)
                            .font(.system(size: 58, weight: .regular)).lineLimit(1).minimumScaleFactor(0.3)
                    }.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 6).padding(.bottom, 16)
                        .accessibilityElement(children: .combine).accessibilityLabel("Calculator display")
                    if scientific {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                            ForEach(["sin", "cos", "tan", "sqrt", "ln", "log", "π", "^", "(", ")", "e", degrees ? "DEG" : "RAD"], id: \.self) { key in
                                Button(key == "sqrt" ? "√" : key) {
                                    if key == "DEG" || key == "RAD" { degrees.toggle() } else { press(key) }
                                }.font(.headline).frame(maxWidth: .infinity, minHeight: 44).modifier(ArithenGlass(tint: glassTint, shape: Capsule()))
                            }
                        }.padding(.bottom, 8)
                    }
                    VStack(spacing: 7) {
                        HStack(spacing: 7) {
                            HStack(spacing: 0) {
                                Button { press("⌫") } label: { Image(systemName: "delete.left").font(.title2).frame(width: side, height: side) }
                                    .accessibilityLabel("Delete last character")
                                Button("AC") { press("AC") }.font(.title).frame(width: side + 7, height: side).accessibilityLabel("Clear all")
                            }.modifier(ArithenGlass(tint: glassTint, shape: Capsule()))
                                .contextMenu { Button("Clear Current Entry") { press("C") } }
                            key("%", side: side, utility: true)
                            key("÷", side: side)
                        }
                        ForEach([["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["+/−", "0", ".", "="]], id: \.self) { row in
                            HStack(spacing: 7) { ForEach(row, id: \.self) { value in key(value, side: side) } }
                        }
                    }.buttonStyle(CalcKeyStyle()).padding(.bottom, 10)
                }.foregroundStyle(ink).frame(width: side * 4 + 21, alignment: .center)
                    .frame(minHeight: geometry.size.height, alignment: .bottom).frame(maxWidth: .infinity)
                }
            }.background { ArithenWallpaper(area: .calculator, visible: !access && !showingSettings && !showingHistory) }
        }.preferredColorScheme((AppAppearance(rawValue: appearance) ?? .dark).scheme)
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    Form {
                        Section("Calculator") {
                            Toggle("Scientific buttons", isOn: $scientific)
                            Toggle("Use degrees", isOn: $degrees)
                        }
                        Section {
                            NavigationLink("Glass Tint & Video Background") { SurfaceAppearanceSettings(area: .calculator) }
                            Picker("Appearance", selection: $appearance) {
                                ForEach(AppAppearance.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                            }
                        }
                        Section { ArithenIdentity() }
                    }.navigationTitle("Calculator Settings").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSettings = false } } }
                }.tint(CalcTheme.accent)
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack {
                    List {
                        if history.isEmpty { Text("Your calculations appear here.").foregroundStyle(.secondary) }
                        ForEach(history) { item in
                            Button { expression = item.result; result = item.result; didEvaluate = true; showingHistory = false } label: {
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(item.expression).font(.subheadline).foregroundStyle(.secondary)
                                    Text(item.result).font(.title2).foregroundStyle(.primary)
                                }.frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }.navigationTitle("History").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Clear", role: .destructive) { history = [] }.disabled(history.isEmpty) }
                            ToolbarItem(placement: .confirmationAction) { Button("Done") { showingHistory = false } }
                        }
                }
            }
            .fullScreenCover(isPresented: $access, onDismiss: { vault.lock() }) {
                PrivateSpaceView { vault.lock(); access = false }.environmentObject(vault)
            }
            .alert("Couldn’t Complete", isPresented: Binding(get: { !access && vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
                Button("Close", role: .cancel) { vault.message = nil }
            } message: { Text(vault.message ?? "") }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    vault.lock(); access = false; showingHistory = false; showingSettings = false
                    expression = ""; result = "0"; didEvaluate = false; history = []
                }
            }
    }
    @ViewBuilder private func key(_ value: String, side: CGFloat, utility: Bool = false) -> some View {
        if value == "=" {
            keyFace(value, side: side, utility: utility)
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in unlockLibrary() })
                .accessibilityAction(named: "Hold Equals") { unlockLibrary() }
        } else { keyFace(value, side: side, utility: utility) }
    }
    private func keyFace(_ value: String, side: CGFloat, utility: Bool) -> some View {
        let operation = ["÷", "×", "−", "+", "="].contains(value)
        return Button { press(value) } label: {
            Text(value).font(.system(size: min(36, side * 0.44), weight: .regular))
                .frame(width: side, height: side)
                .foregroundStyle(.primary)
                .modifier(ArithenGlass(tint: glassTint, shape: Circle(), prominent: operation))
        }.accessibilityLabel(label(for: value))
    }
    private func unlockLibrary() {
        guard VaultCode.isDirectEntry(expression, evaluated: didEvaluate), !vault.busy else { return }
        let code = expression
        Task {
            if await vault.enter(code: code) {
                guard expression == code, scenePhase == .active else { vault.lock(); return }
                expression = ""; result = "0"; didEvaluate = false; access = true
            }
        }
    }
    private func press(_ value: String) {
        switch value {
        case "AC": expression = ""; result = "0"; didEvaluate = false
        case "C": expression = Calculator.clearEntry(expression); result = "0"; didEvaluate = false
        case "⌫": if !expression.isEmpty { expression.removeLast() }; didEvaluate = false
        case "2nd": scientific.toggle()
        case "=":
            do {
                result = Calculator.display(try Calculator.evaluate(expression, degrees: degrees))
                if !VaultCode.isDirectEntry(expression, evaluated: false) {
                    history.insert(CalculationRecord(expression: expression, result: result), at: 0)
                    history = Array(history.prefix(30))
                }
                didEvaluate = true
            }
            catch { result = error.localizedDescription; didEvaluate = false }
        case "+/−":
            guard !expression.isEmpty, expression.count < 252 else { return }
            expression = "-(" + expression + ")"; didEvaluate = false
        default:
            guard expression.count < 248 else { return }
            if didEvaluate {
                expression = ["+", "−", "×", "÷", "^", "%"].contains(value) ? result : ""
                didEvaluate = false
            }
            expression += ["sin", "cos", "tan", "sqrt", "ln", "log"].contains(value) ? value + "(" : value
        }
    }

    private func label(for key: String) -> String {
        ["2nd": "Scientific functions", "⌫": "Delete last character", "AC": "Clear all", "C": "Clear current entry", "+/−": "Change sign",
         "÷": "Divide", "×": "Multiply", "−": "Subtract", "+": "Add", "=": "Equals",
         "^": "Power", "sqrt": "Square root", "π": "Pi", "%": "Percent" ][key] ?? key
    }
}

struct CalcKeyStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 1), value: configuration.isPressed)
    }
}
#endif
