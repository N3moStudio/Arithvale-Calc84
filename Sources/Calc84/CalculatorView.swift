#if os(iOS)
import SwiftUI
import CalcCore

enum CalcTheme {
    static let accent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.63, green: 0.76, blue: 1, alpha: 1)
        : UIColor(red: 0.16, green: 0.28, blue: 0.63, alpha: 1) })
    static let display = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.12, green: 0.15, blue: 0.19, alpha: 1)
        : UIColor(red: 0.88, green: 0.91, blue: 0.95, alpha: 1) })
}

struct CalculatorView: View {
    @EnvironmentObject private var vault: VaultModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var expression = ""
    @State private var result = "0"
    @State private var degrees = true
    @State private var scientific = false
    @State private var didEvaluate = false
    @State private var access = false
    @State private var help = false
    @ScaledMetric(relativeTo: .title2) private var keyHeight = 58.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(AppBrand.calculatorTitle).font(.headline).tracking(2)
                        Spacer()
                        Button("Help", systemImage: "ellipsis.circle") { help = true }
                            .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        Button(degrees ? "DEG" : "RAD") { degrees.toggle() }
                            .font(.subheadline.monospaced().weight(.semibold))
                            .frame(minWidth: 52, minHeight: 44)
                            .accessibilityLabel(degrees ? "Degrees. Switch to radians" : "Radians. Switch to degrees")
                    }
                    display
                    if scientific {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: textSize.isAccessibilitySize ? 2 : 4), spacing: 10) {
                            ForEach(["sin", "cos", "tan", "sqrt", "ln", "log", "π", "^", "(", ")", "e", "⌫"], id: \.self) { key in
                                keyButton(key == "sqrt" ? "√" : key, value: key, utility: true)
                            }
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(["AC", "+/−", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "2nd", "0", ".", "="], id: \.self) { key in
                            keyButton(key, value: key, utility: !key.allSatisfy(\.isNumber))
                        }
                    }
                }
                .frame(maxWidth: 510)
                .padding(20)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .bottom)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .tint(CalcTheme.accent)
        .sheet(isPresented: $help) {
            NavigationStack {
                List {
                    Section("Calculator") {
                        Text("Use 2nd for scientific functions. DEG and RAD change angle units. Enter a calculation, then tap =.")
                    }
                    Section("Private library") {
                        Text("Enter your code and hold = to open your library. On a new installation, use 160160. Normal taps on = only calculate.")
                        Text("Incorrect codes are rate limited. After repeated attempts, wait up to five minutes before trying again.")
                    }
                    Section("Recovery") {
                        Button("Restore or Recover Library") { help = false; access = true }
                        Text("A recovery key or your original 0.1 password is required. Recovery never replaces an existing library.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.navigationTitle("Help")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { help = false } } }
            }
        }
        .fullScreenCover(isPresented: $access, onDismiss: { vault.lock() }) {
            PrivateSpaceView { vault.lock(); access = false }.environmentObject(vault)
        }
        .alert("Couldn’t Complete", isPresented: Binding(get: { !access && !help && vault.message != nil }, set: { if !$0 { vault.message = nil } })) {
            Button("Close", role: .cancel) { vault.message = nil }
        } message: { Text(vault.message ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                vault.lock()
                access = false; help = false
                expression = ""; result = "0"; didEvaluate = false
            }
        }
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 18) {
            Text(expression.isEmpty ? " " : expression)
                .font(.title3.monospaced()).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
            Text(result).font(.system(.largeTitle, design: .monospaced).weight(.medium))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(minHeight: 154)
        .background(CalcTheme.display, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.10)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calculator display")
        .accessibilityValue(expression + ", " + result)
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
    @ViewBuilder
    private func keyButton(_ title: String, value: String, utility: Bool) -> some View {
        if value == "=" {
            keyFace(title, value: value, utility: utility)
                .highPriorityGesture(LongPressGesture(minimumDuration: 0.6).onEnded { _ in unlockLibrary() })
                .accessibilityAction(named: "Open private library") { unlockLibrary() }
        } else { keyFace(title, value: value, utility: utility) }
    }
    private func keyFace(_ title: String, value: String, utility: Bool) -> some View {
        Button { press(value) } label: {
            Text(title).font(utility ? .headline.monospaced() : .title2.monospaced())
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .foregroundStyle(value == "=" ? Color(uiColor: .systemBackground) : utility ? CalcTheme.accent : .primary)
                .background(value == "=" ? CalcTheme.accent : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(CalcKeyStyle())
        .accessibilityLabel(label(for: value))
    }

    private func press(_ value: String) {
        switch value {
        case "AC": expression = ""; result = "0"; didEvaluate = false
        case "⌫": if !expression.isEmpty { expression.removeLast() }; didEvaluate = false
        case "2nd": scientific.toggle()
        case "=":
            do { result = Calculator.display(try Calculator.evaluate(expression, degrees: degrees)); didEvaluate = true }
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
        ["2nd": "Scientific functions", "⌫": "Delete last character", "AC": "Clear all", "+/−": "Change sign",
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
