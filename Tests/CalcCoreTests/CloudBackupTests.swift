import XCTest
@testable import CalcCore

private actor MemoryCloud: CloudStore {
    var files: [String: Data] = [:]
    var uploaded: [String] = []
    var failAfter: Int?
    var corruptDownload = false
    func configure(failAfter: Int? = nil, corruptDownload: Bool = false) {
        self.failAfter = failAfter; self.corruptDownload = corruptDownload
    }
    func listPage(prefix: String, after: String?, limit: Int) async throws -> CloudListingPage {
        let paths = Array(files.keys.filter { $0.hasPrefix(prefix) && $0 > (after ?? "") }.sorted().prefix(limit))
        return CloudListingPage(paths: paths, next: paths.count == limit ? paths.last : nil)
    }
    func size(path: String) async throws -> Int? { files[path]?.count }
    func upload(file: URL, path: String) async throws {
        if let failAfter, uploaded.count >= failAfter { throw CloudError.retry }
        files[path] = try Data(contentsOf: file); uploaded.append(path)
    }
    func download(path: String, to: URL, maximum: Int) async throws {
        guard var bytes = files[path], bytes.count <= maximum else { throw CloudError.missing }
        if corruptDownload, !bytes.isEmpty { bytes[0] ^= 1 }
        try bytes.write(to: to, options: .withoutOverwriting)
    }
    func uploads() -> [String] { uploaded }
    func raw(_ path: String) -> Data? { files[path] }
}

final class CloudBackupTests: XCTestCase {
    var root: URL!
    let password = "four long words recovery secret"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func library(_ name: String = "vault") throws -> VaultRepository {
        let repo = VaultRepository(root: root.appendingPathComponent(name)); try repo.create(password: password); return repo
    }
    func testCloudRoundTripRestoresOriginalBytesDatesAndLivePhotoRelations() async throws {
        let repo = try library()
        let captured = Date(timeIntervalSince1970: 1590000000)
        let item = try repo.add(data: Data("original photo bytes".utf8), name: "private original.heic", contentType: "public.heic", details: .init(captured: captured))
        let companion = try repo.add(data: Data("paired video".utf8), name: "video.mov", contentType: "com.apple.quicktime-movie")
        let thumbnail = try repo.add(data: Data("private thumbnail".utf8), name: "thumb.jpg", contentType: "public.jpeg")
        try repo.associate(primary: item.id, companion: companion.id, thumbnail: thumbnail.id)
        try repo.update(id: item.id, favorite: true, album: "secret album")
        let plan = try repo.cloudPlanIncludingAllForTest(); let store = MemoryCloud()
        try await CloudTransfer.upload(plan, store: store, scratch: root, progress: { _ in })
        let rawCatalog = await store.raw(plan.snapshot.path)
        let catalog = try XCTUnwrap(rawCatalog)
        XCTAssertNil(catalog.range(of: Data("private original".utf8)))
        XCTAssertNil(catalog.range(of: Data("secret album".utf8)))
        XCTAssertNil(catalog.range(of: Data(password.utf8)))
        let snapshot = try CloudSnapshot.decode(catalog)
        XCTAssertEqual(try VaultRepository.validateCloudRecovery(snapshot, password: password), 1)
        let archive = root.appendingPathComponent("cloud.c84backup")
        try await CloudTransfer.download(snapshot, store: store, scratch: root, destination: archive, progress: { _ in })
        repo.lock(); try FileManager.default.removeItem(at: repo.root)
        let restored = VaultRepository(root: root.appendingPathComponent("restored"))
        try restored.restore(from: archive, password: password)
        let recovered = try XCTUnwrap(restored.items.first(where: { $0.id == item.id }))
        XCTAssertEqual(recovered.captured, captured); XCTAssertEqual(recovered.album, "secret album")
        XCTAssertEqual(recovered.favorite, true); XCTAssertEqual(recovered.companionID, companion.id)
        XCTAssertEqual(recovered.thumbnailID, thumbnail.id)
        XCTAssertEqual(try restored.contents(of: item.id), Data("original photo bytes".utf8))
    }
    func testInterruptedUploadNeverPublishesRecoveryCatalog() async throws {
        let repo = try library()
        try repo.add(data: Data([1, 2]), name: "a", contentType: "public.data")
        try repo.add(data: Data([3, 4]), name: "b", contentType: "public.data")
        let plan = try repo.cloudPlanIncludingAllForTest(); let store = MemoryCloud()
        await store.configure(failAfter: 1)
        do { try await CloudTransfer.upload(plan, store: store, scratch: root, progress: { _ in }); XCTFail("Must fail") } catch {}
        let missing = await store.raw(plan.snapshot.path); XCTAssertNil(missing)
        await store.configure()
        try await CloudTransfer.upload(plan, store: store, scratch: root, progress: { _ in })
        let paths = await store.uploads()
        XCTAssertEqual(paths.filter { $0.contains("/objects/") }.count, 2, "Resume should reuse the first object")
        XCTAssertEqual(paths.last, plan.snapshot.path)
    }
    func testCorruptReadBackDoesNotReportComplete() async throws {
        let repo = try library(); try repo.add(data: Data([1]), name: "a", contentType: "public.data")
        let plan = try repo.cloudPlanIncludingAllForTest(); let store = MemoryCloud(); await store.configure(corruptDownload: true)
        do { try await CloudTransfer.upload(plan, store: store, scratch: root, progress: { _ in }); XCTFail("Must fail") } catch {}
        let catalog = await store.raw(plan.snapshot.path); XCTAssertNil(catalog)
    }
    func testIncrementalUploadRetainsEarlierDeletedObjectAndSnapshot() async throws {
        let repo = try library()
        let original = try repo.add(data: Data([1, 2, 3]), name: "a", contentType: "public.data")
        let first = try repo.cloudPlanIncludingAllForTest(); let store = MemoryCloud()
        try await CloudTransfer.upload(first, store: store, scratch: root, progress: { _ in })
        try repo.remove(id: original.id)
        try repo.add(data: Data([4, 5]), name: "b", contentType: "public.data")
        let second = try repo.cloudPlanIncludingAllForTest()
        try await CloudTransfer.upload(second, store: store, scratch: root, previouslyVerified: Set(first.snapshot.records.map(\.filename)), progress: { _ in })
        let old = await store.raw(first.snapshot.path); XCTAssertNotNil(old)
        let object = await store.raw(first.snapshot.objectPath(first.snapshot.records[0])); XCTAssertNotNil(object)
        let uploads = await store.uploads(); XCTAssertEqual(uploads.count, 4)
    }
    func testBadRecoveryKeyAndMissingInventoryFailBeforeDownload() throws {
        let repo = try library(); try repo.add(data: Data([1]), name: "a", contentType: "public.data")
        let snapshot = try repo.cloudPlanIncludingAllForTest().snapshot
        XCTAssertThrowsError(try VaultRepository.validateCloudRecovery(snapshot, password: "incorrect recovery secret"))
        let bad = CloudSnapshot(id: snapshot.id, vaultID: snapshot.vaultID, created: snapshot.created, header: snapshot.header, index: snapshot.index, records: [])
        XCTAssertThrowsError(try VaultRepository.validateCloudRecovery(bad, password: password))
    }
    func testCatalogBoundsAndTransportURLRestrictions() throws {
        let repo = try library(); try repo.add(data: Data([1]), name: "a", contentType: "public.data")
        let snapshot = try repo.cloudPlanIncludingAllForTest().snapshot
        let record = CloudRecord(id: UUID(), bytes: 30, sha256: "../../outside")
        let bad = CloudSnapshot(id: UUID(), vaultID: snapshot.vaultID, created: Date(), header: snapshot.header, index: snapshot.index, records: [record])
        XCTAssertThrowsError(try bad.validate())
        let base = try BlompEndpoint.storage("http://swiftproxy.acs.ai.net:8080/v1/AUTH_example")
        XCTAssertEqual(base.scheme, "https"); XCTAssertNil(base.port)
        for url in ["https://evil.example/v1/AUTH_a", "https://swiftproxy.acs.ai.net.evil.example/v1/AUTH_a", "https://user:pass@swiftproxy.acs.ai.net/v1/AUTH_a", "https://swiftproxy.acs.ai.net/v1/AUTH_a?token=secret"] {
            XCTAssertThrowsError(try BlompEndpoint.storage(url))
        }
        XCTAssertThrowsError(try BlompEndpoint.object(base: base, container: "mail@example.com", path: "c84/v1/../../secret"))
        XCTAssertThrowsError(try BlompEndpoint.object(base: base, container: "../outside", path: snapshot.path))
    }
}
