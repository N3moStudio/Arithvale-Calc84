import XCTest
@testable import CalcCore

private actor DiscoveryProbe {
    var found: [CloudSnapshotSummary] = []
    var skipped = 0
    func add(_ value: CloudSnapshotSummary) { found.append(value) }
    func skip() { skipped += 1 }
    func counts() -> (Int, Int) { (found.count, skipped) }
}
private actor CatalogStore: CloudStore {
    var data: [String: Data]
    var failing: String?
    init(_ data: [String: Data], failing: String? = nil) { self.data = data; self.failing = failing }
    func listPage(prefix: String, after: String?, limit: Int) async throws -> CloudListingPage {
        let values = Array(data.keys.filter { $0.hasPrefix(prefix) && $0 > (after ?? "") }.sorted().prefix(limit))
        return .init(paths: values, next: values.count == limit ? values.last : nil)
    }
    func size(path: String) async throws -> Int? { if path == failing { throw CloudError.authentication }; return data[path]?.count }
    func upload(file: URL, path: String) async throws { data[path] = try Data(contentsOf: file) }
    func download(path: String, to: URL, maximum: Int) async throws {
        guard let value = data[path] else { throw CloudError.missing }
        guard value.count <= maximum else { throw VaultError.limit }
        try value.write(to: to, options: .withoutOverwriting)
    }
}
final class ReliabilityTests: XCTestCase {
    func testSetupRequiresARealAcknowledgedKeyAndClearsTogether() {
        var session = SetupSession()
        XCTAssertFalse(session.canCreate)
        let original = session.recovery
        session.saved = true; session.confirmation = String(VaultCode.normalizeRecovery(original).suffix(8)).lowercased()
        XCTAssertTrue(session.canCreate)
        // A child's navigation does not mutate this value; the displayed key stays identical.
        XCTAssertEqual(session.recovery, original)
        session.clear(); XCTAssertFalse(session.canCreate); XCTAssertFalse(session.saved)
        XCTAssertTrue(session.recovery.isEmpty); XCTAssertTrue(session.confirmation.isEmpty)
        session.saved = true; XCTAssertFalse(session.canCreate, "Empty key plus empty confirmation must never enable creation")
    }
    func testBackupSummaryUsesOnlyCurrentConnectedDestinations() {
        let date = Date()
        let files = BackupDestinationStatus(name: "Files", saved: nil, needsBackup: true)
        let mega = BackupDestinationStatus(name: "MEGA", saved: date, needsBackup: false)
        XCTAssertEqual(BackupStatus.summary([files, mega]), "MEGA backup checked")
        XCTAssertEqual(BackupStatus.summary([.init(name: "Files", saved: date, needsBackup: false)]), "Files backup checked")
        XCTAssertEqual(BackupStatus.summary([.init(name: "MEGA", saved: date, needsBackup: true)]), "Back up changes")
        XCTAssertEqual(BackupStatus.summary([files, .init(name: "MEGA", saved: date, needsBackup: false, connected: false)]), "Back up")
        XCTAssertEqual(BackupStatus.summary([mega, .init(name: "Blomp", saved: date, needsBackup: true)]), "MEGA backup checked")
    }
    func testDiscoveryKeepsGoodNeighborsAndSkipsCorruptAndMissingCatalogs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = VaultRepository(root: root.appendingPathComponent("library"))
        try repo.create(password: "a disposable recovery secret")
        let first = try repo.cloudPlan().snapshot, second = try repo.cloudPlan().snapshot
        let broken = first.prefix + "snapshots/" + UUID().uuidString + ".c84cloud"
        let missing = first.prefix + "snapshots/" + UUID().uuidString + ".c84cloud"
        let store = CatalogStore([first.path: try JSONEncoder().encode(first), second.path: try JSONEncoder().encode(second), broken: Data("corrupt".utf8)])
        let probe = DiscoveryProbe()
        try await CloudDiscovery.scan(.init(paths: [first.path, broken, missing, second.path], next: nil), store: store, scratch: root,
            found: { await probe.add($0) }, skipped: { await probe.skip() })
        let counts = await probe.counts(); XCTAssertEqual(counts.0, 2); XCTAssertEqual(counts.1, 2)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["library"], "Catalog scratch files must be cleaned")
    }
    func testAuthenticationFailureIsRetryableNotReportedAsDamaged() async throws {
        let path = "c84/v1/" + UUID().uuidString + "/snapshots/" + UUID().uuidString + ".c84cloud"
        let probe = DiscoveryProbe(), store = CatalogStore([:], failing: path)
        do {
            try await CloudDiscovery.scan(.init(paths: [path], next: nil), store: store, scratch: .temporaryDirectory,
                found: { await probe.add($0) }, skipped: { await probe.skip() })
            XCTFail("Authentication must fail")
        } catch CloudError.authentication {} catch { XCTFail("Unexpected \(error)") }
        let counts = await probe.counts(); XCTAssertEqual(counts.1, 0)
    }
    func testHistoryBeyondTwoThousandUsesBoundedPagesWithoutDuplicates() async throws {
        let base = "c84/v1/" + UUID().uuidString + "/snapshots/"
        let paths = (0..<2005).map { _ in base + UUID().uuidString + ".c84cloud" }
        let store = CatalogStore(Dictionary(uniqueKeysWithValues: paths.map { ($0, Data([0])) }))
        var seen = Set<String>(), cursor: String?
        repeat {
            let page = try await store.listPage(prefix: "c84/v1/", after: cursor, limit: CloudDiscovery.pageSize)
            XCTAssertLessThanOrEqual(page.paths.count, CloudDiscovery.pageSize)
            for path in page.paths { XCTAssertTrue(seen.insert(path).inserted) }
            if let next = page.next { XCTAssertGreaterThan(next, cursor ?? "") }
            cursor = page.next
        } while cursor != nil
        XCTAssertEqual(seen.count, 2005)
    }
    func testDiscoveryRejectsUnboundedPagesAndDoesNotSkipCancellation() async throws {
        XCTAssertFalse(CloudDiscovery.isDamagedCatalog(CancellationError()))
        XCTAssertFalse(CloudDiscovery.isDamagedCatalog(CloudError.quota))
        XCTAssertFalse(CloudDiscovery.isDamagedCatalog(URLError(.networkConnectionLost)))
        let probe = DiscoveryProbe()
        do {
            try await CloudDiscovery.scan(.init(paths: Array(repeating: "bad", count: 41), next: nil), store: CatalogStore([:]), scratch: .temporaryDirectory,
                found: { await probe.add($0) }, skipped: { await probe.skip() })
            XCTFail("Unbounded page")
        } catch CloudError.service {} catch { XCTFail("Unexpected \(error)") }
    }
}
