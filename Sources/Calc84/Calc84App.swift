#if os(iOS)
import SwiftUI
import UIKit

@main
struct Calc84App: App {
    @UIApplicationDelegateAdaptor(PrivacyDelegate.self) private var delegate
    @StateObject private var vault = VaultModel()
    var body: some Scene {
        WindowGroup { CalculatorView().environmentObject(vault).environmentObject(vault.cloud) }
    }
}

/// A separate window also covers sheets and document previews in app-switcher snapshots.
@MainActor
final class PrivacyDelegate: NSObject, UIApplicationDelegate {
    private var shields: [UIWindow] = []
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        TemporaryFiles.clean()
        NotificationCenter.default.addObserver(self, selector: #selector(cover), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(uncover), name: UIApplication.didBecomeActiveNotification, object: nil)
        return true
    }
    @objc private func cover() {
        guard shields.isEmpty else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 10
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "0"
            label.font = .monospacedDigitSystemFont(ofSize: 56, weight: .regular)
            label.textColor = .label
            label.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.trailingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
                label.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor, constant: 100)
            ])
            window.rootViewController = controller
            window.isHidden = false
            shields.append(window)
        }
    }
    @objc private func uncover() {
        for window in shields { window.isHidden = true }
        shields.removeAll()
    }
}
#endif
