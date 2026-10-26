#if os(iOS)
import SwiftUI
import Photos
import PhotosUI

/// The PhotoKit handler may produce degraded results before the final result.
private final class LivePhotoRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PHLivePhoto, Error>?
    private var request: PHLivePhotoRequestID?
    private var finished = false
    func start(_ urls: [URL], _ continuation: CheckedContinuation<PHLivePhoto, Error>) {
        lock.lock()
        if finished { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation; lock.unlock()
        let id = PHLivePhoto.request(withResourceFileURLs: urls, placeholderImage: nil, targetSize: CGSize(width: 2048, height: 2048), contentMode: .aspectFit) { [self] photo, info in
            if info[PHLivePhotoInfoIsDegradedKey] as? Bool == true { return }
            if let photo { complete(.success(photo)) }
            else { complete(.failure(info[PHLivePhotoInfoErrorKey] as? Error ?? CocoaError(.fileReadCorruptFile))) }
        }
        lock.lock(); request = id; let done = finished; lock.unlock()
        if done { PHLivePhoto.cancelRequest(withRequestID: id) }
    }
    private func complete(_ result: Result<PHLivePhoto, Error>) {
        lock.lock(); guard !finished else { lock.unlock(); return }
        finished = true; let pending = continuation; continuation = nil; lock.unlock()
        pending?.resume(with: result)
    }
    func cancel() {
        complete(.failure(CancellationError()))
        lock.lock(); let id = request; lock.unlock()
        if let id { PHLivePhoto.cancelRequest(withRequestID: id) }
    }
}
enum LivePhotoLoader {
    static func load(_ urls: [URL]) async throws -> PHLivePhoto {
        let request = LivePhotoRequest()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { request.start(urls, $0) }
        } onCancel: { request.cancel() }
    }
}
struct LivePhotoPreview: UIViewRepresentable {
    let photo: PHLivePhoto
    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView(); view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = true; view.accessibilityLabel = "Live Photo"
        view.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "Play Live Photo", actionHandler: { [weak view] _ in
            view?.startPlayback(with: .full); return true
        })]
        return view
    }
    func updateUIView(_ view: PHLivePhotoView, context: Context) { view.livePhoto = photo }
    static func dismantleUIView(_ view: PHLivePhotoView, coordinator: ()) { view.stopPlayback(); view.livePhoto = nil }
}
#endif
