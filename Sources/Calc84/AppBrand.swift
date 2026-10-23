#if os(iOS)
import Foundation

enum AppBrand {
    static let name = "Arithvale"
    static let calculatorTitle = "ARITHVALE"
    static let support = URL(string: "https://github.com/N3moStudio/Calc-84/issues")!
    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "–") (\(info["CFBundleVersion"] as? String ?? "–"))"
    }
}
#endif
