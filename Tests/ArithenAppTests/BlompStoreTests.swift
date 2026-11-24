import Foundation
import XCTest
@testable import Arithen

final class BlompStoreTests: XCTestCase {
    private let request = URLRequest(url: URL(string: "https://download.invalid/file")!)

    func testPreCancelledCloudDownloadRemovesDestination() async {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let finished = expectation(description: "Cancelled download finished")
        let request = self.request
        let download = Task {
            defer { finished.fulfill() }
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            do {
                _ = try await CloudHTTP.run(request, destination: destination, limit: 100, cellular: false,
                                            protocolClasses: [PartialDownloadProtocol.self])
                XCTFail("The pre-cancelled transfer succeeded")
            } catch {
                XCTAssertTrue(error is CancellationError, "Unexpected transfer error: \(error)")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
        defer { download.cancel() }
        await fulfillment(of: [finished], timeout: 5)
    }

    func testCancellingCloudDownloadRemovesWrittenPartialFile() async throws {
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let finished = expectation(description: "Cancelled download finished")
        let request = self.request
        let download = Task {
            defer { finished.fulfill() }
            do {
                _ = try await CloudHTTP.run(request, destination: destination, limit: 100, cellular: false,
                                            protocolClasses: [PartialDownloadProtocol.self])
                XCTFail("The interrupted transfer succeeded")
            } catch {
                XCTAssertTrue(error is CancellationError, "Unexpected transfer error: \(error)")
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        }
        defer { download.cancel() }
        var bytes: Data?
        for _ in 0..<500 {
            bytes = try? Data(contentsOf: destination)
            if bytes == PartialDownloadProtocol.bytes { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(bytes, PartialDownloadProtocol.bytes)
        download.cancel()
        await fulfillment(of: [finished], timeout: 5)
    }
}

private final class PartialDownloadProtocol: URLProtocol {
    static let bytes = Data("partial download".utf8)

    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "download.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Length": "100"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.bytes)
        // Keep the transfer open until the task is cancelled.
    }
    override func stopLoading() {}
}
