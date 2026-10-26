import XCTest
@testable import CalcCore

final class FreshLibraryTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func repo(_ name: String = UUID().uuidString) -> VaultRepository {
        VaultRepository(root: directory.appendingPathComponent(name))
    }
    private func source(_ recovery: String, bytes: Data = Data(repeating: 17, count: 1_100_000)) throws -> VaultRepository {
        let value = repo(); try value.create(password: recovery)
        _ = try value.add(data: bytes, name: "fixture.jpg", contentType: "public.jpeg")
        return value
    }
    private func archive(_ value: VaultRepository) throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString + ".c84backup")
        try value.exportBackup(to: url); return url
    }
    private func header(_ value: VaultRepository) throws -> VaultHeader {
        try JSONDecoder().decode(VaultHeader.self, from: Data(contentsOf: value.root.appendingPathComponent("header.json")))
    }
    private func noStagesRemain() throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix("stage-") })
    }
    func testBackupOnboardingGetsIndependentKeysAndExportsRejectSourceKey() throws {
        let oldRecovery = VaultCode.generateRecovery(), newRecovery = VaultCode.generateRecovery()
        let old = try source(oldRecovery), input = try archive(old)
        let originalArchive = try Data(contentsOf: input), oldCredential = try old.credential()
        let current = repo()
        try current.initializeFromBackups([.init(url: input, recovery: oldRecovery)], recovery: newRecovery)
        XCTAssertTrue(try current.credential().key != oldCredential.key)
        XCTAssertNotEqual(try current.identifier(), oldCredential.id)
        XCTAssertTrue(try header(current).salt != header(old).salt)
        XCTAssertTrue(try header(current).wrappedKey != header(old).wrappedKey)
        let imported = try XCTUnwrap(current.items.first)
        XCTAssertTrue(try current.contents(of: imported.id) == old.contents(of: old.items[0].id))
        let exported = try archive(current), restored = repo()
        XCTAssertThrowsError(try restored.restore(from: exported, password: oldRecovery))
        XCTAssertFalse(restored.exists)
        try restored.restore(from: exported, password: newRecovery)
        XCTAssertTrue(try restored.credential().key == current.credential().key)
        XCTAssertThrowsError(try repo().restore(from: input, password: newRecovery))
        try repo().restore(from: input, password: oldRecovery)
        XCTAssertTrue(try Data(contentsOf: input) == originalArchive)
        try noStagesRemain()
    }
    func testIdenticalPhotosCreateDifferentLibrariesAndCiphertext() throws {
        let originalRecovery = VaultCode.generateRecovery(), original = try source(originalRecovery)
        let input = try archive(original), a = repo(), b = repo()
        let recoveryA = VaultCode.generateRecovery(), recoveryB = VaultCode.generateRecovery()
        XCTAssertTrue(recoveryA != recoveryB && recoveryA != originalRecovery && recoveryB != originalRecovery)
        try a.initializeFromBackups([.init(url: input, recovery: originalRecovery)], recovery: recoveryA)
        try b.initializeFromBackups([.init(url: input, recovery: originalRecovery)], recovery: recoveryB)
        XCTAssertTrue(try a.credential().key != b.credential().key)
        XCTAssertNotEqual(try a.identifier(), try b.identifier())
        let archiveA = try archive(a), archiveB = try archive(b)
        XCTAssertTrue(try Data(contentsOf: archiveA) != Data(contentsOf: archiveB))
        XCTAssertThrowsError(try repo().restore(from: archiveA, password: recoveryB))
        XCTAssertThrowsError(try repo().restore(from: archiveB, password: recoveryA))
    }
    func testMultipleSourcesThenLaterImportsKeepOneDestinationKey() throws {
        let keyA = VaultCode.generateRecovery(), keyB = VaultCode.generateRecovery(), destinationRecovery = VaultCode.generateRecovery()
        let a = try source(keyA, bytes: Data([1])), b = try source(keyB, bytes: Data([2]))
        _ = try b.add(data: Data([1]), name: "duplicate.jpg", contentType: "public.jpeg")
        let inputA = try archive(a), inputB = try archive(b), current = repo()
        try current.initializeFromBackups([.init(url: inputA, recovery: keyA), .init(url: inputB, recovery: keyB)], recovery: destinationRecovery)
        XCTAssertEqual(current.items.count, 2)
        let identity = try current.credential(), originalHeader = try header(current)
        XCTAssertTrue(try identity.key != a.credential().key && identity.key != b.credential().key)
        _ = try current.add(data: Data([3]), name: "new raw import", contentType: "public.data")
        let c = try source(VaultCode.generateRecovery(), bytes: Data([4]))
        _ = try current.importBackup(c, selected: Set(c.items.map(\.id)))
        XCTAssertEqual(current.items.count, 4)
        XCTAssertTrue(try current.credential().key == identity.key)
        XCTAssertTrue(try header(current).wrappedKey == originalHeader.wrappedKey)
        let exported = try archive(current)
        for recovery in [keyA, keyB] { XCTAssertThrowsError(try repo().restore(from: exported, password: recovery)) }
        try repo().restore(from: exported, password: destinationRecovery)
    }
    func testInvalidSecondSourceRollsBackWholeSetupAndPreservesSources() throws {
        let firstKey = VaultCode.generateRecovery(), secondKey = VaultCode.generateRecovery()
        let a = try source(firstKey, bytes: Data([1])), b = try source(secondKey, bytes: Data([2]))
        let good = try archive(a), second = try archive(b)
        let goodBytes = try Data(contentsOf: good), secondBytes = try Data(contentsOf: second)
        let damaged = directory.appendingPathComponent("damaged.c84backup")
        var corrupt = secondBytes; corrupt[corrupt.count - 1] ^= 1; try corrupt.write(to: damaged)
        for bad in [SetupBackupSource(url: second, recovery: VaultCode.generateRecovery()), .init(url: damaged, recovery: secondKey)] {
            let destination = repo()
            XCTAssertThrowsError(try destination.initializeFromBackups([.init(url: good, recovery: firstKey), bad], recovery: VaultCode.generateRecovery()))
            XCTAssertFalse(destination.exists); XCTAssertFalse(destination.isUnlocked)
            try noStagesRemain()
        }
        XCTAssertTrue(try Data(contentsOf: good) == goodBytes)
        XCTAssertTrue(try Data(contentsOf: second) == secondBytes)
    }
    func testExistingLibraryAndRecoveryAccessAreNeverRotated() throws {
        let existingRecovery = VaultCode.generateRecovery(), current = try source(existingRecovery)
        let identity = try current.credential(), index = try Data(contentsOf: current.root.appendingPathComponent("index.enc"))
        let input = try archive(current)
        XCTAssertThrowsError(try current.initializeFromBackups([.init(url: input, recovery: existingRecovery)], recovery: VaultCode.generateRecovery()))
        XCTAssertTrue(try Data(contentsOf: current.root.appendingPathComponent("index.enc")) == index)
        current.lock(); try current.unlock(password: existingRecovery)
        XCTAssertTrue(try current.credential().key == identity.key)
    }
    func testSourceKeyReuseInvalidConfirmationAndCancellationCannotCreateLibrary() async throws {
        var session = SetupSession()
        XCTAssertFalse(session.canCreate)
        session.saved = true; session.confirmation = "incorrect"
        XCTAssertFalse(session.canCreate)
        session.confirmation = String(VaultCode.normalizeRecovery(session.recovery).suffix(8))
        XCTAssertTrue(session.canCreate)
        let old = try source(session.recovery, bytes: Data([1])), input = try archive(old), destination = repo()
        XCTAssertThrowsError(try destination.initializeFromBackups([.init(url: input, recovery: session.recovery)], recovery: session.recovery))
        XCTAssertFalse(destination.exists)
        let sourceKey = session.recovery, newKey = VaultCode.generateRecovery()
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try destination.initializeFromBackups([.init(url: input, recovery: sourceKey)], recovery: newKey)
        }
        do { try await cancelled.value; XCTFail("Cancelled setup must fail") } catch is CancellationError {} catch { XCTFail("Unexpected failure") }
        XCTAssertFalse(destination.exists); try noStagesRemain()
        let cancelledAfterCopy = Task {
            try destination.initializeFromBackups([.init(url: input, recovery: sourceKey)], recovery: newKey) { _, _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { try await cancelledAfterCopy.value; XCTFail("Cancellation before commit must fail") } catch is CancellationError {} catch { XCTFail("Unexpected failure") }
        XCTAssertFalse(destination.exists); XCTAssertFalse(destination.isUnlocked); try noStagesRemain()
        session.clear(); XCTAssertFalse(session.canCreate)
    }
    func testLivePhotosTrashDatesAndCloudBlocksSurviveFreshSetup() throws {
        let recovery = VaultCode.generateRecovery(), old = repo(); try old.create(password: recovery)
        let date = Date(timeIntervalSince1970: 1_650_000_000)
        let still = try old.add(data: Data([1]), name: "live.jpg", contentType: "public.jpeg", details: .init(captured: date), pending: true)
        let motion = try old.add(data: Data([2]), name: "motion.mov", contentType: "public.movie", pending: true)
        let thumbnail = try old.add(data: Data([3]), name: "thumbnail.jpg", contentType: "public.jpeg", pending: true)
        try old.associate(primary: still.id, companion: motion.id, thumbnail: thumbnail.id)
        try old.update(id: still.id, favorite: true, album: "Fixture")
        let trash = try old.add(data: Data([4]), name: "trash.jpg", contentType: "public.jpeg")
        try old.update(id: trash.id, deleted: true)
        try old.setCloudPolicy(.init(mode: .automatic, blocked: [still.id]), provider: .mega)
        let current = repo()
        try current.initializeFromBackups([.init(url: archive(old), recovery: recovery)], recovery: VaultCode.generateRecovery())
        let copied = try XCTUnwrap(current.items.first { $0.companionID != nil })
        XCTAssertEqual(copied.captured, date); XCTAssertEqual(copied.album, "Fixture"); XCTAssertEqual(copied.favorite, true)
        XCTAssertTrue(try current.contents(of: XCTUnwrap(copied.companionID)) == Data([2]))
        XCTAssertTrue(try current.contents(of: XCTUnwrap(copied.thumbnailID)) == Data([3]))
        XCTAssertNotNil(current.items.first { $0.name == "trash.jpg" }?.deletedAt)
        XCTAssertEqual(try current.cloudPreferences().mega.mode, .manual)
        XCTAssertTrue(try current.cloudPreferences().mega.blocked.contains(copied.id))
        XCTAssertTrue(try current.cloudPreferences().mega.selected.isEmpty)
    }
    func testLegacyArchiveCanInitializeFreshLibraryWithoutChangingOriginal() throws {
        let oldRecovery = "disposable legacy fixture password"
        let oldHeader = VaultHeader(id: UUID(), salt: VaultCrypto.random(32), rounds: VaultCrypto.rounds)
        let oldKey = try VaultCrypto.derive(password: oldRecovery, salt: oldHeader.salt, rounds: oldHeader.rounds)
        let item = VaultItem(id: UUID(), name: "legacy.txt", contentType: "public.data", byteCount: 3, added: Date(timeIntervalSince1970: 1_650_000_000))
        let manifest = VaultManifest(version: 1, items: [item]), base = "Calc84/v1/\(oldHeader.id.uuidString)"
        let input = directory.appendingPathComponent("legacy.c84backup"), output = try VaultStream.newFile(input)
        try output.write(contentsOf: Data("C84B0001".utf8))
        try VaultStream.block(JSONEncoder().encode(oldHeader), to: output)
        try VaultStream.block(VaultCrypto.seal(JSONEncoder().encode(manifest), key: oldKey, context: base + "/manifest"), to: output)
        try VaultStream.number(1, to: output); try output.write(contentsOf: Data(item.id.uuidString.utf8))
        try VaultStream.block(VaultCrypto.seal(Data([1, 2, 3]), key: oldKey, context: base + "/" + item.id.uuidString), to: output)
        try output.close()
        let newRecovery = VaultCode.generateRecovery(), current = repo()
        try current.initializeFromBackups([.init(url: input, recovery: oldRecovery)], recovery: newRecovery)
        XCTAssertEqual(try header(current).version, 2)
        XCTAssertEqual(current.items.first?.storageVersion, 2)
        XCTAssertTrue(try current.contents(of: XCTUnwrap(current.items.first).id) == Data([1, 2, 3]))
        XCTAssertThrowsError(try repo().restore(from: archive(current), password: oldRecovery))
        try repo().restore(from: input, password: oldRecovery)
    }
    func testEmptyBackupAlsoCreatesIndependentKeys() throws {
        let sourceRecovery = VaultCode.generateRecovery(), original = repo(); try original.create(password: sourceRecovery)
        let destination = repo()
        try destination.initializeFromBackups([.init(url: archive(original), recovery: sourceRecovery)], recovery: VaultCode.generateRecovery())
        XCTAssertTrue(destination.exists); XCTAssertTrue(destination.items.isEmpty)
        XCTAssertTrue(try destination.credential().key != original.credential().key)
    }
}
