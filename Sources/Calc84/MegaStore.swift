#if os(iOS)
import Foundation
import Network
import CalcCore
import CalcMega

private final class MegaCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var result: Result<String, Error>?
    func install(_ continuation: CheckedContinuation<String, Error>) -> Bool {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result); return false }
        self.continuation = continuation; lock.unlock(); return true
    }
    func finish(_ result: Result<String, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result; let pending = continuation; continuation = nil; lock.unlock()
        pending?.resume(with: result)
    }
}

private let megaCallback: C84MegaCallback = { context, error, result in
    guard let context else { return }
    let completion = Unmanaged<MegaCompletion>.fromOpaque(context).takeRetainedValue()
    if error == 0 { completion.finish(.success(result.map(String.init(cString:)) ?? "")) }
    else {
        let failure: Error
        switch error {
        case -3, -4, -6: failure = CloudError.retry
        case -9: failure = CloudError.missing
        case -11: failure = CloudError.permission
        case -15, -26: failure = CloudError.authentication
        case -17, -24: failure = CloudError.quota
        case -18, -19: failure = CloudError.retry
        default: failure = CloudError.service
        }
        completion.finish(.failure(failure))
    }
}

/// Official MEGA SDK handles its account encryption and protocol. Arithvale sends
/// only its own ciphertext through it; it never implements MEGA cryptography.
final class MegaStore: CloudStore, @unchecked Sendable {
    private let client: UnsafeMutableRawPointer
    private let cellular: Bool
    private let monitor = NWPathMonitor()
    private let networkLock = NSLock()
    private var permitted = false
    private var networkKnown = false
    init(appKey: String, cellular: Bool) throws {
        let key = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count <= 128, let client = c84mega_create(key) else { throw CloudError.configuration }
        self.client = client; self.cellular = cellular
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let allowed = path.status == .satisfied && (cellular || !path.isExpensive) && !path.isConstrained
            self.networkLock.lock(); self.permitted = allowed; self.networkKnown = true; self.networkLock.unlock()
            if !allowed { c84mega_cancel(self.client) }
        }
        monitor.start(queue: DispatchQueue(label: "studio.n3mo.calc84.cloud-network"))
    }
    deinit { monitor.cancel(); c84mega_destroy(client) }
    private func networkState() -> (Bool, Bool) {
        networkLock.lock(); defer { networkLock.unlock() }; return (networkKnown, permitted)
    }
    private func checkNetwork() async throws {
        for _ in 0..<40 {
            try Task.checkCancellation()
            let (known, allowed) = networkState()
            if known { if !allowed { throw URLError(.dataNotAllowed) }; return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw URLError(.notConnectedToInternet)
    }
    private func request(_ invoke: (C84MegaCallback?, UnsafeMutableRawPointer) -> Void) async throws -> String {
        try await checkNetwork()
        let completion = MegaCompletion()
        // Transfer quotas can wait indefinitely in the SDK. Bound the wait so a
        // paused/expired connection cannot leave the app permanently busy.
        let timeout = Task { [self] in
            do {
                try await Task.sleep(nanoseconds: 3600_000_000_000)
                completion.finish(.failure(CloudError.retry)); c84mega_cancel(client)
            } catch {}
        }
        defer { timeout.cancel() }
        let result: String = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard completion.install(continuation) else { return }
                invoke(megaCallback, Unmanaged.passRetained(completion).toOpaque())
            }
        } onCancel: { completion.finish(.failure(CancellationError())); c84mega_cancel(self.client) }
        try Task.checkCancellation(); return result
    }
    func signIn(email: String, password: String, code: String) async throws -> String {
        let session = try await request { c84mega_login(client, email, password, code, $0, $1) }
        guard !session.isEmpty else { throw CloudError.authentication }
        _ = try await request { c84mega_fetch(client, $0, $1) }
        return session
    }
    func resume(session: String) async throws {
        _ = try await request { c84mega_resume(client, session, $0, $1) }
        _ = try await request { c84mega_fetch(client, $0, $1) }
    }
    func refresh() async throws { _ = try await request { c84mega_fetch(client, $0, $1) } }
    private func validate(_ path: String) throws {
        _ = try BlompEndpoint.object(base: URL(string: "https://swiftproxy.acs.ai.net/v1/AUTH_validation")!, container: "validation", path: path)
    }
    func listPage(prefix: String, after: String?, limit: Int) async throws -> CloudListingPage {
        guard prefix == "c84/v1/", (1...CloudDiscovery.pageSize).contains(limit) else { throw CloudError.configuration }
        if after == nil { try await refresh() }
        let listing = try await request { c84mega_list(client, after ?? "", Int32(limit), $0, $1) }
        let paths = listing.split(separator: "\n").map(String.init)
        guard paths.count <= limit, paths == paths.sorted(), paths.allSatisfy({ $0 > (after ?? "") }) else { throw CloudError.service }
        return CloudListingPage(paths: paths, next: paths.count == limit ? paths.last : nil)
    }
    func size(path: String) async throws -> Int? {
        try validate(path); try await checkNetwork()
        let size = c84mega_size(client, "/" + path)
        return size < 0 ? nil : Int(size)
    }
    func upload(file: URL, path: String) async throws {
        try validate(path)
        let parts = path.split(separator: "/").map(String.init)
        var parent = "/"
        for part in parts.dropLast() {
            _ = try await request { c84mega_mkdir(client, parent, part, $0, $1) }
            parent += part + "/"
        }
        _ = try await request { c84mega_upload(client, file.path, parent, parts.last!, $0, $1) }
    }
    func download(path: String, to: URL, maximum: Int) async throws {
        guard let size = try await size(path: path), size <= maximum, size >= 0 else { throw CloudError.missing }
        guard !FileManager.default.fileExists(atPath: to.path) else { throw VaultError.exists }
        do {
            _ = try await request { c84mega_download(client, "/" + path, to.path, $0, $1) }
            guard try to.resourceValues(forKeys: [.fileSizeKey]).fileSize == size else { throw VaultError.invalidBackup }
        } catch { try? FileManager.default.removeItem(at: to); throw error }
    }
}
#endif
