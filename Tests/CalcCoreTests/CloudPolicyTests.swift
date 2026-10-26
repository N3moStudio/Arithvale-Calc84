import XCTest
@testable import CalcCore

extension VaultRepository {
    func cloudPlanIncludingAllForTest() throws -> CloudPlan {
        try setCloudPolicy(.init(mode: .automatic), provider: .mega)
        return try cloudPlan(provider: .mega)
    }
}

final class CloudPolicyTests: XCTestCase {
    var root: URL!
    var repo: VaultRepository!
    let secret = "a disposable recovery secret"
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        repo = VaultRepository(root: root.appendingPathComponent("vault"))
        try repo.create(password: secret)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func add(_ name: String) throws -> VaultItem { try repo.add(data: Data(name.utf8), name: name, contentType: "public.data") }
    func testDefaultManualAndProvidersAreIndependent() throws {
        let a = try add("a"), b = try add("b")
        XCTAssertTrue(try repo.cloudPlan(provider: .mega).itemIDs.isEmpty)
        try repo.setCloudPolicy(.init(selected: [a.id]), provider: .mega)
        try repo.setCloudPolicy(.init(selected: [b.id]), provider: .blomp)
        _ = try add("new")
        XCTAssertEqual(try repo.cloudPlan(provider: .mega).itemIDs, [a.id])
        XCTAssertEqual(try repo.cloudPlan(provider: .blomp).itemIDs, [b.id])
    }
    func testBlockedOverridesBothModesAndExcludesAllRelatedResources() throws {
        let a = try add("allowed"), b = try add("blocked"), thumb = try add("private thumbnail"), video = try add("private live video")
        try repo.associate(primary: b.id, companion: video.id, thumbnail: thumb.id)
        for mode in [CloudBackupPolicy.Mode.manual, .automatic] {
            try repo.setCloudPolicy(.init(mode: mode, selected: [a.id, b.id], blocked: [b.id]), provider: .mega)
            let plan = try repo.cloudPlan(provider: .mega)
            XCTAssertEqual(plan.itemIDs, [a.id])
            XCTAssertEqual(Set(plan.snapshot.records.map(\.id)), [a.id])
            XCTAssertEqual(Set(plan.sources.keys), [a.id])
            let archive = root.appendingPathComponent(UUID().uuidString + ".c84backup")
            try CloudBackup.assemble(plan.snapshot, objects: plan.sources, to: archive)
            let restored = VaultRepository(root: root.appendingPathComponent(UUID().uuidString))
            try restored.restore(from: archive, password: secret)
            XCTAssertEqual(restored.items.map(\.id), [a.id], "Encrypted index must not contain blocked metadata")
            XCTAssertEqual(try restored.cloudPreferences(), .init(), "Cloud restore must not re-enable upload")
            XCTAssertEqual(try restored.credential().key, try repo.credential().key)
        }
        XCTAssertEqual(repo.items.count, 4, "Projection must not change local files")
    }
    func testAutomaticIncludesNewItemsButSkipsRecentlyDeleted() throws {
        let a = try add("deleted"), b = try add("kept")
        try repo.update(id: a.id, deleted: true)
        try repo.setCloudPolicy(.init(mode: .automatic), provider: .mega)
        let c = try add("new")
        XCTAssertEqual(try repo.cloudPlan(provider: .mega).itemIDs, [b.id, c.id])
    }
    func testSelectionAndBlocksSurviveUnlockAndFullBackup() throws {
        let a = try add("a"), b = try add("b")
        let policy = CloudBackupPolicy(mode: .automatic, selected: [a.id], blocked: [b.id])
        try repo.setCloudPolicy(policy, provider: .mega)
        repo.lock(); try repo.unlock(password: secret)
        XCTAssertEqual(try repo.cloudPreferences()[.mega], policy)
        let archive = root.appendingPathComponent("full.c84backup")
        try repo.exportBackup(to: archive)
        let restored = VaultRepository(root: root.appendingPathComponent("restored"))
        try restored.restore(from: archive, password: secret)
        XCTAssertEqual(restored.items.count, 2)
        XCTAssertEqual(try restored.cloudPreferences()[.mega], policy)
        try repo.remove(id: b.id)
        repo.lock(); try repo.unlock(password: secret)
        XCTAssertTrue(try repo.cloudPreferences()[.mega].blocked.isEmpty)
    }
    func testLegacyManifestAndInvalidPoliciesFailClosed() throws {
        let legacy = try JSONDecoder().decode(VaultManifest.self, from: Data(#"{"version":2,"items":[]}"#.utf8))
        XCTAssertNil(legacy.cloudPreferences)
        XCTAssertThrowsError(try repo.setCloudPolicy(.init(selected: [UUID()]), provider: .mega))
        XCTAssertTrue(try repo.cloudPlan(provider: .mega).itemIDs.isEmpty)
        XCTAssertThrowsError(try JSONDecoder().decode(CloudBackupPolicy.self, from: Data(#"{"mode":"unknown","selected":[],"blocked":[]}"#.utf8)))
    }
    func testSharedExcludedResourcesRejectPlan() throws {
        let a = try add("allowed"), b = try add("denied"), thumb = try add("shared")
        try repo.associate(primary: a.id, companion: nil, thumbnail: thumb.id)
        try repo.associate(primary: b.id, companion: nil, thumbnail: thumb.id)
        try repo.setCloudPolicy(.init(selected: [a.id], blocked: [b.id]), provider: .mega)
        XCTAssertThrowsError(try repo.cloudPlan(provider: .mega))
    }
}
