#if os(iOS)
import SwiftUI
import UIKit
import Combine
import CalcCore

/// UIKit owns presentation, interruption and cancellation. SwiftUI owns content.
@MainActor
final class MediaViewerController: UIHostingController<AnyView>, UIAdaptivePresentationControllerDelegate {
    let previews = MediaPreviewStore()
    private(set) var currentID: UUID
    private var finished = false
    private var unlocked: AnyCancellable?
    private let sourceView: (UUID, UIImage?) -> UIView?
    private let closed: (UUID) -> Void

    init(items: [VaultItem], initial: UUID, vault: VaultModel,
         sourceView: @escaping (UUID, UIImage?) -> UIView?, closed: @escaping (UUID) -> Void) {
        currentID = initial; self.sourceView = sourceView; self.closed = closed
        super.init(rootView: AnyView(EmptyView()))
        modalPresentationStyle = .fullScreen
        rootView = AnyView(MediaBrowser(items: items, initial: initial, previews: previews,
            close: { [weak self] in self?.close() },
            didShow: { [weak self] id in self?.currentID = id }).environmentObject(vault))
        configureTransition()
        NotificationCenter.default.addObserver(self, selector: #selector(motionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        unlocked = vault.$unlocked.removeDuplicates().sink { [weak self] value in
            if !value { self?.closeForPrivacy() }
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    deinit { NotificationCenter.default.removeObserver(self) }

    private func configureTransition() {
        modalTransitionStyle = UIAccessibility.isReduceMotionEnabled ? .crossDissolve : .coverVertical
        if #available(iOS 18.0, *) {
            if UIAccessibility.isReduceMotionEnabled { preferredTransition = .crossDissolve }
            else {
                let options = UIViewController.Transition.ZoomOptions()
                options.interactiveDismissShouldBegin = { [weak self] context in
                    guard let self, !self.finished, context.willBegin,
                          self.presentedViewController == nil,
                          self.previews.zoomedID == nil else { return false }
                    // Horizontal intent belongs to the pager; upward intent belongs
                    // to media/Details. Leave eligible downward interaction to UIKit.
                    let velocity = context.velocity
                    return velocity.dy >= 0 && abs(velocity.dy) >= abs(velocity.dx) * 1.2
                }
                preferredTransition = .zoom(options: options) { [weak self] _ in
                    guard let self, !self.finished else { return nil }
                    return self.sourceView(self.currentID, self.previews.image(for: self.currentID))
                }
            }
        }
    }
    @objc private func motionChanged() {
        // Native UIKit owns any in-flight transition; update its next transition.
        configureTransition()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentationController?.delegate = self
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Covering the viewer with another sheet is not a completed dismissal.
        if isBeingDismissed || presentingViewController == nil { finish() }
    }
    func close() {
        guard !finished, !isBeingDismissed else { return }
        dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { [weak self] in self?.finish() }
    }
    func closeForPrivacy() {
        guard !finished else { return }
        viewIfLoaded?.isHidden = true
        previews.clear()
        dismiss(animated: false) { [weak self] in self?.finish() }
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { finish() }
    private func finish() {
        guard !finished else { return }
        finished = true; unlocked = nil; previews.clear(); closed(currentID)
    }
}
#endif
