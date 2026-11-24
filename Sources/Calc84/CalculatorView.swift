#if os(iOS)
import SwiftUI
import UIKit
import CalcCore

enum CalcTheme {
    static var accent: Color { ArithenPalette.color(.accent) }
    static var display: Color { ArithenPalette.color(.surface) }
}

private struct CalculationRecord: Identifiable {
    let id = UUID()
    let expression: String
    let result: String
}

struct CalculatorView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var textSize
    @AppStorage("calculatorGlassTint") private var glassTintValue = GlassTint.plum.rawValue
    @Environment(\.arithenTheme) private var theme
    @State private var expression = ""
    @State private var result = "0"
    @State private var degrees = true
    @State private var scientific = false
    @State private var didEvaluate = false
    @State private var calculationError: String?
    // Editing a computed/history value must never turn it into an access code.
    @State private var directCodeEntry = true
    @State private var access = false
    @State private var unlockInFlight = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @State private var history: [CalculationRecord] = []
    private var ink: Color { ArithenPalette.color(.text, theme: theme) }
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
                        if !textSize.isAccessibilitySize { calculatorTitle }
                        Spacer(minLength: 2)
                        Menu {
                            Button(scientific ? "Basic Calculator" : "Scientific Calculator") { scientific.toggle() }
                            Button(degrees ? "Use Radians" : "Use Degrees") { degrees.toggle() }
                        } label: {
                            Image(systemName: "plus.forwardslash.minus").frame(width: 44, height: 44).modifier(ArithenGlass(tint: glassTint, shape: Circle()))
                        }.accessibilityLabel("Calculator mode")
                        Button("Settings", systemImage: "gearshape") { showingSettings = true }
                            .labelStyle(.iconOnly).frame(width: 44, height: 44)
                            .modifier(ArithenGlass(tint: glassTint, shape: Circle()))
                    }.font(.system(size: 22)).padding(.top, 6)
                    if textSize.isAccessibilitySize { calculatorTitle.padding(.top, 8) }
                    Spacer(minLength: 32)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(expression.isEmpty ? " " : expression).font(.title3).foregroundStyle(ink.opacity(0.52))
                            .lineLimit(2).minimumScaleFactor(0.65)
                        Text(calculationError ?? (didEvaluate || expression.isEmpty ? result : expression))
                            .font(.system(size: 52, weight: .regular, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.3)
                    }.frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 6).padding(.bottom, 16)
                        .accessibilityElement(children: .combine).accessibilityLabel("Calculator display")
                        .accessibilityValue(calculationError ?? (didEvaluate || expression.isEmpty ? result : expression))
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
                                Button { press("⌫") } label: { Image(systemName: "delete.left").font(.system(size: min(27, side * 0.34))).frame(width: side, height: side) }
                                    .accessibilityLabel("Delete last character")
                                Button("AC") { press("AC") }.font(.system(size: min(27, side * 0.34), design: .rounded)).frame(width: side + 7, height: side).accessibilityLabel("Clear all")
                            }.modifier(ArithenGlass(tint: glassTint, shape: Capsule()))
                                .contextMenu { Button("Clear Current Entry") { press("C") } }
                            key("%", side: side, utility: true)
                            key("÷", side: side)
                        }
                        ForEach([["7", "8", "9", "×"], ["4", "5", "6", "−"], ["1", "2", "3", "+"], ["+/−", "0", ".", "="]], id: \.self) { row in
                            HStack(spacing: 7) { ForEach(row, id: \.self) { value in key(value, side: side) } }
                        }
                    }.buttonStyle(CalcKeyStyle()).padding(.bottom, 10)
                // Keep the header and display readable when short windows shrink the keys.
                }.foregroundStyle(ink).frame(width: availableWidth, alignment: .center)
                    .frame(minHeight: geometry.size.height, alignment: .bottom).frame(maxWidth: .infinity)
                }
            }.background { ArithenPalette.color(.canvas, theme: theme).ignoresSafeArea() }
        }
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    ThemedForm {
                        Section { AppearanceSettingsCard() }
                        Section("Calculator") {
                            Toggle("Scientific buttons", isOn: $scientific)
                            Toggle("Use degrees", isOn: $degrees)
                        }
                        Section { LabeledContent(AppBrand.name, value: AppBrand.version) }
                    }.contentMargins(.top, 16, for: .scrollContent)
                        .navigationTitle("Calculator Settings").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSettings = false } } }
                }.tint(ArithenPalette.color(.accent, theme: theme))
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack {
                    ThemedList {
                        if history.isEmpty { Text("Your calculations appear here.").foregroundStyle(ArithenPalette.color(.muted, theme: theme)) }
                        ForEach(history) { item in
                            Button { expression = item.result; result = item.result; didEvaluate = true; directCodeEntry = false; calculationError = nil; showingHistory = false } label: {
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(item.expression).font(.subheadline).foregroundStyle(ArithenPalette.color(.muted, theme: theme))
                                    Text(item.result).font(.title2).foregroundStyle(ArithenPalette.color(.text, theme: theme))
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
                    expression = ""; result = "0"; didEvaluate = false; directCodeEntry = true; calculationError = nil; history = []
                }
            }
    }
    private var calculatorTitle: some View {
        Text(AppBrand.name).font(.subheadline.weight(.semibold))
            .foregroundStyle(ArithenPalette.color(.muted, theme: theme))
            .fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func key(_ value: String, side: CGFloat, utility: Bool = false) -> some View {
        if value == "=" {
            keyFace(value, side: side, utility: utility)
                // Recognize at the threshold while still held; a short tap remains Equals.
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
                    .onEnded { _ in unlockLibrary() })
                .accessibilityAction(named: "Hold Equals") { unlockLibrary() }
        } else { keyFace(value, side: side, utility: utility) }
    }
    private func keyFace(_ value: String, side: CGFloat, utility: Bool) -> some View {
        let operation = ["÷", "×", "−", "+", "="].contains(value)
        return Button { press(value) } label: {
            Text(value).font(.system(size: min(29, side * 0.36), weight: .regular, design: .rounded))
                .frame(width: side, height: side)
                .foregroundStyle(ArithenPalette.color(operation && (reduceTransparency || contrast == .increased) ? .onAccent : .text, theme: theme))
                .modifier(ArithenGlass(tint: glassTint, shape: Circle(), prominent: operation))
        }.accessibilityLabel(label(for: value))
    }
    private func unlockLibrary() {
        guard directCodeEntry, VaultCode.isDirectEntry(expression, evaluated: didEvaluate),
              scenePhase == .active, !access, !unlockInFlight, !vault.busy else { return }
        let code = expression
        unlockInFlight = true
        Task {
            defer { unlockInFlight = false }
            if await vault.enter(code: code) {
                guard expression == code, directCodeEntry, !didEvaluate, scenePhase == .active else { vault.lock(); return }
                expression = ""; result = "0"; didEvaluate = false; directCodeEntry = true; calculationError = nil
                // Authentication stays unchanged; only the successful reveal skips the modal slide.
                var reveal = Transaction(animation: nil)
                reveal.disablesAnimations = true
                withTransaction(reveal) { access = true }
            }
        }
    }
    private func press(_ value: String) {
        calculationError = nil
        switch value {
        case "AC": expression = ""; result = "0"; didEvaluate = false; directCodeEntry = true
        case "C":
            expression = Calculator.clearEntry(expression)
            result = "0"; didEvaluate = false
            if expression.isEmpty { directCodeEntry = true }
        case "⌫":
            if !expression.isEmpty { expression.removeLast() }
            didEvaluate = false
            if expression.isEmpty { directCodeEntry = true }
        case "2nd": scientific.toggle()
        case "=":
            directCodeEntry = false
            do {
                result = Calculator.display(try Calculator.evaluate(expression, degrees: degrees))
                if !VaultCode.isDirectEntry(expression, evaluated: false) {
                    history.insert(CalculationRecord(expression: expression, result: result), at: 0)
                    history = Array(history.prefix(30))
                }
                didEvaluate = true
            }
            catch {
                calculationError = error.localizedDescription; didEvaluate = false
                UIAccessibility.post(notification: .announcement, argument: error.localizedDescription)
            }
        case "+/−":
            guard !expression.isEmpty, expression.count < 252 else { return }
            directCodeEntry = false
            expression = Calculator.toggleSign(didEvaluate ? result : expression); didEvaluate = false
        default:
            guard expression.count < 248 else { return }
            if didEvaluate {
                let continuesResult = ["+", "−", "×", "÷", "^", "%"].contains(value)
                expression = continuesResult ? result : ""
                directCodeEntry = !continuesResult
                didEvaluate = false
            }
            directCodeEntry = directCodeEntry && value.count == 1 && "0123456789".contains(value)
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
