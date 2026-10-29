import XCTest
@testable import CalcCore

final class LibraryToolsTests: XCTestCase {
    private var directory: URL!
    private let secret = "a sufficiently long recovery password"
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func library(_ name: String = UUID().uuidString) throws -> VaultRepository {
        let repo = VaultRepository(root: directory.appendingPathComponent(name))
        try repo.create(password: secret); return repo
    }
    private func item(_ repo: VaultRepository, data: String = "original bytes") throws -> VaultItem {
        try repo.add(data: Data(data.utf8), name: "IMG_1234.jpg", contentType: "public.jpeg")
    }
    private func restored(_ repo: VaultRepository) throws -> VaultRepository {
        let file = directory.appendingPathComponent(UUID().uuidString + ".c84backup")
        try repo.exportBackup(to: file)
        let result = VaultRepository(root: directory.appendingPathComponent(UUID().uuidString))
        try result.restore(from: file, password: secret); return result
    }
    func testOldSingleAlbumJSONStillDecodesAndSearches() throws {
        let repo = try library(), photo = try item(repo)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(photo)) as? [String: Any])
        object["album"] = "Summer"; object.removeValue(forKey: "albums"); object.removeValue(forKey: "tags")
        let legacy = try JSONDecoder().decode(VaultItem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.albumNames, ["Summer"])
        XCTAssertTrue(LibraryOrganization.matches(legacy, query: "summer img"))
    }
    func testMembershipChangesNeverDuplicateOrRewriteMedia() throws {
        let repo = try library(), photo = try item(repo)
        let original = try Data(contentsOf: repo.root.appendingPathComponent(photo.id.uuidString + ".enc"))
        try repo.organize(ids: [photo.id], albums: ["Travel", "Favorites", " Travel "], tags: ["receipt", "été"], mode: .add)
        let credential = try repo.credential(); repo.lock(); try repo.unlock(credential: credential)
        let updated = try XCTUnwrap(repo.items.first)
        XCTAssertEqual(updated.albumNames, ["Travel", "Favorites"]); XCTAssertEqual(updated.album, "Travel")
        XCTAssertEqual(updated.tags, ["receipt", "été"]); XCTAssertEqual(repo.items.count, 1)
        XCTAssertEqual(try Data(contentsOf: repo.root.appendingPathComponent(photo.id.uuidString + ".enc")), original)
        XCTAssertTrue(LibraryOrganization.matches(updated, query: "receipt travel"))
        XCTAssertTrue(LibraryOrganization.matches(updated, query: "ETE receipt"))
        XCTAssertTrue(LibraryOrganization.matches(updated, query: "total 14", recognizedText: "Total $14"))
        XCTAssertFalse(LibraryOrganization.matches(updated, query: "missing"))
    }
    func testRemovingMembershipClearsOnlyItsCoverAndEnforcesLimitsAtomically() throws {
        let repo = try library(), photo = try item(repo)
        try repo.organize(ids: [photo.id], albums: ["A", "B"], tags: ["keep"], mode: .add)
        try repo.setAlbumPreference(.init(pinned: true, coverID: photo.id), name: "A")
        try repo.organize(ids: [photo.id], albums: ["A"], tags: [], mode: .remove)
        XCTAssertEqual(repo.items[0].albumNames, ["B"]); XCTAssertEqual(repo.items[0].album, "B")
        XCTAssertNil(try repo.albumPreferences()["A"]?.coverID)
        XCTAssertEqual(try repo.albumPreferences()["A"]?.pinned, true)
        XCTAssertThrowsError(try repo.organize(ids: [photo.id], albums: (0..<25).map { "Album\($0)" }, tags: [], mode: .add))
        XCTAssertEqual(repo.items[0].albumNames, ["B"]); XCTAssertEqual(repo.items[0].tags, ["keep"])
    }
    func testOrganizationRoundTripAndSearchIndexStaysLocal() throws {
        let repo = try library(), photo = try item(repo)
        try repo.organize(ids: [photo.id], albums: ["Travel", "2026"], tags: ["ticket"], mode: .add)
        try repo.setAlbumPreference(.init(pinned: true, coverID: photo.id), name: "Travel")
        var index = PrivateSearchIndex(); index.enabled = true; index.entries[photo.id] = "CONFIDENTIAL OCR SENTENCE"
        try repo.saveSearchIndex(index)
        XCTAssertEqual(try repo.searchIndex(), index)
        let ciphertext = try Data(contentsOf: repo.root.appendingPathComponent("search.enc"))
        XCTAssertNil(ciphertext.range(of: Data("CONFIDENTIAL OCR SENTENCE".utf8)))
        let copy = try restored(repo)
        XCTAssertEqual(copy.items[0].albumNames, ["Travel", "2026"])
        XCTAssertEqual(copy.items[0].tags, ["ticket"])
        XCTAssertEqual(try copy.albumPreferences()["Travel"], .init(pinned: true, coverID: photo.id))
        XCTAssertFalse(try copy.searchIndex().enabled)
    }
    func testImportRemapsCoversAndMergesDuplicateOrganization() throws {
        let source = try library(), destination = try library()
        let original = try item(source), existing = try item(destination)
        try source.organize(ids: [original.id], albums: ["Trip", "Receipts"], tags: ["source"], mode: .add)
        try source.setAlbumPreference(.init(pinned: true, coverID: original.id), name: "Trip")
        try destination.organize(ids: [existing.id], albums: ["Local"], tags: ["destination"], mode: .add)
        let result = try destination.importBackup(source, selected: [original.id])
        XCTAssertEqual(result.skipped, 1); XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.items[0].albumNames, ["Local", "Trip", "Receipts"])
        XCTAssertEqual(result.items[0].tags, ["destination", "source"])
        XCTAssertEqual(try destination.albumPreferences()["Trip"]?.coverID, existing.id)
        XCTAssertEqual(try restored(destination).items.count, 1)
    }
    func testNewImportedItemKeepsMembershipsAndCoverUsesNewID() throws {
        let source = try library(), destination = try library(), original = try item(source)
        try source.organize(ids: [original.id], albums: ["A", "B"], tags: ["tag"], mode: .add)
        try source.setAlbumPreference(.init(pinned: true, coverID: original.id), name: "B")
        let result = try destination.importBackup(source, selected: [original.id])
        XCTAssertNotEqual(result.items[0].id, original.id)
        XCTAssertEqual(result.items[0].albumNames, ["A", "B"])
        XCTAssertEqual(try destination.albumPreferences()["B"]?.coverID, result.items[0].id)
    }
    func testCloudProjectionDoesNotLeakExcludedAlbumOrCoverOrSearch() throws {
        let repo = try library(), allowed = try item(repo, data: "allowed"), denied = try item(repo, data: "denied")
        try repo.organize(ids: [allowed.id, denied.id], albums: ["Shared"], tags: [], mode: .add)
        try repo.organize(ids: [denied.id], albums: ["Secret"], tags: ["secret tag"], mode: .add)
        try repo.setAlbumPreference(.init(pinned: true, coverID: denied.id), name: "Shared")
        try repo.setAlbumPreference(.init(pinned: true, coverID: denied.id), name: "Secret")
        try repo.setCloudPolicy(.init(selected: [allowed.id], blocked: [denied.id]), provider: .mega)
        let plan = try repo.cloudPlan(provider: .mega)
        let file = directory.appendingPathComponent("subset.c84backup")
        try CloudBackup.assemble(plan.snapshot, objects: plan.sources, to: file)
        let copy = VaultRepository(root: directory.appendingPathComponent("subset"))
        try copy.restore(from: file, password: secret)
        XCTAssertEqual(copy.items.map(\.id), [allowed.id])
        XCTAssertEqual(Set(try copy.albumPreferences().keys), ["Shared"])
        XCTAssertNil(try copy.albumPreferences()["Shared"]?.coverID)
        XCTAssertTrue(try copy.searchIndex().entries.isEmpty)
    }
    func testSearchIndexAuthenticationBoundsPruningAndDisable() throws {
        let repo = try library(), photo = try item(repo)
        var index = PrivateSearchIndex(); index.enabled = true; index.entries[photo.id] = "hello"
        index.entries[UUID()] = "not a library item"
        try repo.saveSearchIndex(index)
        XCTAssertEqual(try repo.searchIndex().entries.count, 1)
        try repo.update(id: photo.id, deleted: true)
        XCTAssertTrue(try repo.searchIndex().entries.isEmpty)
        try repo.update(id: photo.id, deleted: false)
        index.entries[photo.id] = String(repeating: "x", count: 4097)
        XCTAssertThrowsError(try repo.saveSearchIndex(index))
        let url = repo.root.appendingPathComponent("search.enc")
        var data = try Data(contentsOf: url); data[data.count - 1] ^= 1; try data.write(to: url)
        XCTAssertThrowsError(try repo.searchIndex())
        try repo.saveSearchIndex(.init())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertFalse(try repo.searchIndex().enabled)
        XCTAssertLessThanOrEqual(PrivateSearchIndex.bounded(String(repeating: "📷", count: 4000)).utf8.count, 4096)
    }
    func testExactDuplicatesIncludeLiveMotionAndExcludeDeletedItems() throws {
        let repo = try library()
        let a = try item(repo), b = try item(repo), deleted = try item(repo)
        try repo.update(id: deleted.id, deleted: true)
        let liveA = try item(repo), liveB = try item(repo)
        let motionA = try repo.add(data: Data("motion one".utf8), name: "one.mov", contentType: "com.apple.quicktime-movie")
        let motionB = try repo.add(data: Data("motion two".utf8), name: "two.mov", contentType: "com.apple.quicktime-movie")
        try repo.associate(primary: liveA.id, companion: motionA.id, thumbnail: nil)
        try repo.associate(primary: liveB.id, companion: motionB.id, thumbnail: nil)
        let result = try repo.duplicates()
        XCTAssertEqual(result.count, 1); XCTAssertEqual(Set(result[0].ids), [a.id, b.id])
        XCTAssertEqual(repo.items.count, 7)
    }
    func testSearchCiphertextCannotBeOpenedByAnotherLibrary() throws {
        let source = try library(), destination = try library(), photo = try item(source)
        var index = PrivateSearchIndex(); index.enabled = true; index.entries[photo.id] = "private words"
        try source.saveSearchIndex(index)
        try FileManager.default.copyItem(at: source.root.appendingPathComponent("search.enc"), to: destination.root.appendingPathComponent("search.enc"))
        XCTAssertThrowsError(try destination.searchIndex())
        source.lock(); XCTAssertThrowsError(try source.searchIndex())
    }
    func testCoverMustBelongToAlbumAndDeletingItKeepsAlbumPinned() throws {
        let repo = try library(), photo = try item(repo)
        XCTAssertThrowsError(try repo.setAlbumPreference(.init(pinned: true, coverID: photo.id), name: "Other"))
        XCTAssertTrue(try repo.albumPreferences().isEmpty)
        try repo.organize(ids: [photo.id], albums: ["A"], tags: [], mode: .add)
        try repo.setAlbumPreference(.init(pinned: true, coverID: photo.id), name: "A")
        try repo.remove(id: photo.id)
        XCTAssertEqual(try repo.albumPreferences()["A"], .init(pinned: true, coverID: nil))
        XCTAssertEqual(try restored(repo).albumPreferences()["A"]?.pinned, true)
    }
    func testStorageCountsResourcesOnceAndDetectsIndexSize() throws {
        let repo = try library(), photo = try item(repo)
        let motion = try repo.add(data: Data(repeating: 4, count: 250), name: "motion", contentType: "public.movie")
        try repo.associate(primary: photo.id, companion: motion.id, thumbnail: nil)
        let primary = try XCTUnwrap(repo.items.first { $0.id == photo.id })
        let report = try repo.storageReport()
        XCTAssertEqual(report.bytes(for: primary), (report.resourceBytes[photo.id] ?? 0) + (report.resourceBytes[motion.id] ?? 0))
        XCTAssertGreaterThan(report.encryptedBytes, report.bytes(for: primary))
        XCTAssertEqual(report.searchBytes, 0)
        XCTAssertEqual(StorageBudget.required(sourceBytes: Int64.max, copies: 3), Int64.max)
        XCTAssertEqual(StorageBudget.required(sourceBytes: -1, copies: 3), StorageBudget.reserve)
    }
    func testRecoveryEvidenceOnlyMatchesTheExactSourceAndSnapshot() {
        let record = RecoveryCheck(source: "Files", snapshotID: "digest-a", items: 42)
        XCTAssertTrue(record.matches(source: "Files", snapshotID: "digest-a"))
        XCTAssertFalse(record.matches(source: "Files", snapshotID: "digest-b"))
        XCTAssertFalse(record.matches(source: "MEGA", snapshotID: "digest-a"))
        XCTAssertFalse(record.matches(source: "Files", snapshotID: nil))
        let a = UUID(), b = UUID()
        XCTAssertEqual(BackupCoverage.pending(eligible: [a, b], saved: [a], changed: false, sameLibrary: true), 1)
        XCTAssertEqual(BackupCoverage.pending(eligible: [a, b], saved: [a, b], changed: true, sameLibrary: true), 2)
        XCTAssertEqual(BackupCoverage.pending(eligible: [a, b], saved: [a, b], changed: false, sameLibrary: false), 2)
    }
    func testWallpaperEditClampsInvalidValuesAndSourceBoundaries() throws {
        var edit = WallpaperEdit(); edit.start = 100; edit.duration = 100; edit.still = 60
        let bounded = try XCTUnwrap(edit.normalized(sourceDuration: 12))
        XCTAssertEqual(bounded.start, 11.5); XCTAssertEqual(bounded.duration, 0.5); XCTAssertLessThan(bounded.still, bounded.duration)
        edit.start = .nan; edit.duration = .infinity; edit.still = -.infinity; edit.horizontal = 4; edit.vertical = -2
        let clean = try XCTUnwrap(edit.normalized(sourceDuration: 60))
        XCTAssertEqual(clean.start, 0); XCTAssertEqual(clean.duration, 30); XCTAssertEqual(clean.still, 0)
        XCTAssertEqual(clean.horizontal, 1); XCTAssertEqual(clean.vertical, 0)
        XCTAssertNil(edit.normalized(sourceDuration: .nan)); XCTAssertNil(edit.normalized(sourceDuration: 0))
    }
    func testWallpaperCropAnchorsNeverRevealBlankEdges() {
        var edit = WallpaperEdit()
        for x in [0.0, 0.5, 1.0] {
            for y in [0.0, 0.5, 1.0] {
                edit.horizontal = x; edit.vertical = y
                for dimensions in [(1920.0, 1080.0), (1080.0, 1920.0)] {
                    let crop = WallpaperCrop.layout(sourceWidth: dimensions.0, sourceHeight: dimensions.1, width: 390, height: 844, edit: edit)
                    XCTAssertLessThanOrEqual(crop.x, 0); XCTAssertLessThanOrEqual(crop.y, 0)
                    XCTAssertGreaterThanOrEqual(crop.width + crop.x, 390 - 0.001)
                    XCTAssertGreaterThanOrEqual(crop.height + crop.y, 844 - 0.001)
                }
            }
        }
    }
}
