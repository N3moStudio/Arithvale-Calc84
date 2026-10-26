#if os(iOS)
import Foundation
import CalcCore

/// A bounded HTTP request. Redirects are refused so tokens cannot leak to a
/// different host. No cookies, disk cache, analytics or relaxed TLS settings.
private final class CloudHTTP: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let mutex = NSLock()
    private var continuation: CheckedContinuation<(Data, HTTPURLResponse), Error>?
    private var task: URLSessionTask?
    private var cancelled = false
    private var session: URLSession?
    private var response: HTTPURLResponse?
    private var data = Data()
    private var output: FileHandle?
    private var count = 0
    private let limit: Int
    private init(limit: Int) { self.limit = limit }
    static func run(_ request: URLRequest, upload: URL? = nil, destination: URL? = nil,
                    limit: Int, cellular: Bool) async throws -> (Data, HTTPURLResponse) {
        let operation = CloudHTTP(limit: limit)
        if let destination {
            guard FileManager.default.createFile(atPath: destination.path, contents: nil,
                attributes: [.protectionKey: FileProtectionType.complete]) else { throw CloudError.service }
            operation.output = try FileHandle(forWritingTo: destination)
        }
        do {
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { completion in
                    operation.mutex.lock()
                    defer { operation.mutex.unlock() }
                    if operation.cancelled { completion.resume(throwing: CancellationError()); return }
                    operation.continuation = completion
                    let config = URLSessionConfiguration.ephemeral
                    config.urlCache = nil; config.httpCookieStorage = nil
                    config.allowsCellularAccess = cellular
                    config.allowsExpensiveNetworkAccess = cellular
                    config.allowsConstrainedNetworkAccess = false
                    config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 3600
                    let session = URLSession(configuration: config, delegate: operation, delegateQueue: nil)
                    operation.session = session
                    let task: URLSessionTask = upload.map { session.uploadTask(with: request, fromFile: $0) } ?? session.dataTask(with: request)
                    operation.task = task; task.resume()
                }
            } onCancel: {
                operation.mutex.lock(); operation.cancelled = true; operation.task?.cancel(); operation.mutex.unlock()
            }
        } catch {
            try? operation.output?.close(); operation.output = nil
            if let destination { try? FileManager.default.removeItem(at: destination) }; throw error
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse,
              dataTask.originalRequest?.httpMethod == "HEAD" || response.expectedContentLength <= Int64(limit) else {
            completionHandler(.cancel); return
        }
        self.response = http; completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        count += data.count
        guard count <= limit else { dataTask.cancel(); return }
        do { if let output { try output.write(contentsOf: data) } else { self.data.append(data) } }
        catch { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? output?.close(); output = nil
        mutex.lock(); let completion = continuation; continuation = nil; mutex.unlock()
        if let error { completion?.resume(throwing: error) }
        else if let response { completion?.resume(returning: (data, response)) }
        else { completion?.resume(throwing: CloudError.service) }
        session.finishTasksAndInvalidate(); self.session = nil; self.task = nil
    }
}

actor BlompStore: CloudStore {
    private let email: String
    private let password: String
    private let cellular: Bool
    private var base: URL?
    private var token: String?
    init(email: String, password: String, cellular: Bool) { self.email = email; self.password = password; self.cellular = cellular }
    func connect() async throws {
        var request = URLRequest(url: URL(string: "https://authenticate.blomp.com/v2.0/tokens")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["auth": ["tenantName": "storage",
            "passwordCredentials": ["username": email, "password": password]]])
        let (data, response) = try await CloudHTTP.run(request, limit: 1024 * 1024, cellular: cellular)
        try Self.check(response.statusCode)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let access = json["access"] as? [String: Any],
              let token = (access["token"] as? [String: Any])?["id"] as? String, !token.isEmpty, token.count < 16384,
              let services = access["serviceCatalog"] as? [[String: Any]],
              let service = services.first(where: { $0["type"] as? String == "object-store" }),
              let endpoint = (service["endpoints"] as? [[String: Any]])?.first?["publicURL"] as? String else { throw CloudError.authentication }
        let base = try BlompEndpoint.storage(endpoint)
        self.base = base; self.token = token
        // Test the user's existing container; Blomp doesn't permit creating one.
        _ = try await listPage(prefix: "c84/v1/", after: nil, limit: 1)
    }
    private func request(path: String?, method: String) throws -> URLRequest {
        guard let base, let token else { throw CloudError.configuration }
        let url = try path.map { try BlompEndpoint.object(base: base, container: email, path: $0) } ?? base.appendingPathComponent(email)
        var request = URLRequest(url: url); request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "X-Auth-Token")
        return request
    }
    func listPage(prefix: String, after: String?, limit: Int) async throws -> CloudListingPage {
        guard prefix == "c84/v1/", (1...CloudDiscovery.pageSize).contains(limit) else { throw CloudError.configuration }
        var marker = after ?? ""
        var catalogs: [String] = []
        // Bound each interaction to 25 provider requests. If exhausted, expose the
        // continuation rather than declaring the account too large to recover.
        for _ in 0..<25 {
            try Task.checkCancellation()
            var request = try request(path: nil, method: "GET")
            var url = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            url.queryItems = [URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "prefix", value: prefix),
                URLQueryItem(name: "limit", value: "1000"), URLQueryItem(name: "marker", value: marker)]
            request.url = url.url
            let (data, response) = try await CloudHTTP.run(request, limit: 2 * 1024 * 1024, cellular: cellular)
            try Self.check(response.statusCode)
            let names = try JSONDecoder().decode([ObjectName].self, from: data).map(\.name)
            guard names.count <= 1000, names.allSatisfy({ $0.hasPrefix(prefix) && $0 > marker && $0.count < 512 }),
                  names == names.sorted(), Set(names).count == names.count else { throw CloudError.service }
            for name in names {
                marker = name
                if name.hasSuffix(".c84cloud") { catalogs.append(name) }
                if catalogs.count == limit { return .init(paths: catalogs, next: marker) }
            }
            if names.count < 1000 { return .init(paths: catalogs, next: nil) }
        }
        return .init(paths: catalogs, next: marker)
    }
    func size(path: String) async throws -> Int? {
        let (_, response) = try await CloudHTTP.run(request(path: path, method: "HEAD"), limit: 8192, cellular: cellular)
        if response.statusCode == 404 { return nil }
        try Self.check(response.statusCode)
        return response.value(forHTTPHeaderField: "Content-Length").flatMap(Int.init)
    }
    func upload(file: URL, path: String) async throws {
        var request = try request(path: path, method: "PUT")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await CloudHTTP.run(request, upload: file, limit: 8192, cellular: cellular)
        try Self.check(response.statusCode)
    }
    func download(path: String, to: URL, maximum: Int) async throws {
        let (_, response) = try await CloudHTTP.run(request(path: path, method: "GET"), destination: to, limit: maximum, cellular: cellular)
        do { try Self.check(response.statusCode) }
        catch { try? FileManager.default.removeItem(at: to); throw error }
    }
    private struct ObjectName: Decodable { let name: String }
    private static func check(_ status: Int) throws {
        switch status {
        case 200..<300: return
        case 401: throw CloudError.authentication
        case 403: throw CloudError.permission
        case 404: throw CloudError.missing
        case 413, 507: throw CloudError.quota
        case 429, 500...599: throw CloudError.retry
        default: throw CloudError.service
        }
    }
}
#endif
