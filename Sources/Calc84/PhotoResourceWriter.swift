#if os(iOS)
import Foundation
import Photos
import CalcCore

private final class PhotoResourceWriter: @unchecked Sendable {
    private let lock = NSLock()
    private var handle: FileHandle?
    private var completion: CheckedContinuation<Void, Error>?
    private var requestID: PHAssetResourceDataRequestID?
    private var finished = false
    private var cancelled = false
    private var bytes = 0
    init(url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path),
              FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.protectionKey: FileProtectionType.complete]) else { throw VaultError.exists }
        handle = try FileHandle(forWritingTo: url)
    }
    func start(_ resource: PHAssetResource, completion: CheckedContinuation<Void, Error>) {
        lock.lock()
        if cancelled { lock.unlock(); completion.resume(throwing: CancellationError()); return }
        self.completion = completion
        lock.unlock()
        let options = PHAssetResourceRequestOptions(); options.isNetworkAccessAllowed = true
        let id = PHAssetResourceManager.default().requestData(for: resource, options: options,
            dataReceivedHandler: { [self] data in receive(data) }, completionHandler: { [self] error in finish(error) })
        lock.lock(); requestID = id; let shouldCancel = finished || cancelled; lock.unlock()
        if shouldCancel { PHAssetResourceManager.default().cancelDataRequest(id) }
    }
    private func receive(_ data: Data) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        do {
            guard bytes <= VaultLimits.fileBytes - data.count else { throw VaultError.limit }
            try handle?.write(contentsOf: data); bytes += data.count
            lock.unlock()
        } catch { lock.unlock(); finish(error); cancelRequest() }
    }
    private func finish(_ error: Error?) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        var result = error
        do { try handle?.close() } catch { if result == nil { result = error } }
        handle = nil
        let pending = completion; completion = nil
        lock.unlock()
        if let result { pending?.resume(throwing: result) } else { pending?.resume() }
    }
    private func cancelRequest() {
        lock.lock(); let id = requestID; lock.unlock()
        if let id { PHAssetResourceManager.default().cancelDataRequest(id) }
    }
    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        finish(CancellationError()); cancelRequest()
    }
    static func write(_ resource: PHAssetResource, to url: URL) async throws {
        let writer = try PhotoResourceWriter(url: url)
        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { writer.start(resource, completion: $0) }
            } onCancel: { writer.cancel() }
            try Task.checkCancellation()
        } catch { writer.cancel(); try? FileManager.default.removeItem(at: url); throw error }
    }
}

enum PhotoResource {
    static func write(_ resource: PHAssetResource, to url: URL) async throws {
        try await PhotoResourceWriter.write(resource, to: url)
    }
}
#endif
