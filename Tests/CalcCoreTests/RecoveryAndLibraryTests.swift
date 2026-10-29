import XCTest
@testable import CalcCore

final class RecoveryAndLibraryTests: XCTestCase {
    private var folder: URL!
    private let secret = "C24144AF-B3E94438-97C89127-E373D053-9F19F720-E47CA588-7C38BF10-14C2AF32"
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }
    private func repo(_ name: String) -> VaultRepository { VaultRepository(root: folder.appendingPathComponent(name)) }

    func testCodeEntryDoesNotUnlockCalculatedResultsOrExpressions() throws {
        XCTAssertTrue(VaultCode.isDirectEntry("160160", evaluated: false))
        XCTAssertFalse(VaultCode.isDirectEntry("160160", evaluated: true))
        XCTAssertFalse(VaultCode.isDirectEntry("160000+160", evaluated: false))
        XCTAssertFalse(VaultCode.isDirectEntry("0160160.0", evaluated: false))
        XCTAssertFalse(VaultCode.valid("160160"))
        XCTAssertTrue(VaultCode.valid("736491"))
        XCTAssertFalse(VaultCode.valid("١٢٣٤٥٦"))
        let salt = VaultCode.salt()
        XCTAssertTrue(VaultCode.equal(try VaultCode.verifier("736491", salt: salt), try VaultCode.verifier("736491", salt: salt)))
        XCTAssertFalse(VaultCode.equal(try VaultCode.verifier("736491", salt: salt), try VaultCode.verifier("736492", salt: salt)))
    }
    func testRandomRecoveryKeyEnvelopeAndDeviceCredentialAreIndependent() throws {
        let a = repo("a"); try a.create(password: secret)
        let item = try a.add(data: Data("original bytes".utf8), name: "original.jpg", contentType: "public.jpeg")
        let credential = try a.credential()
        let header = try JSONDecoder().decode(VaultHeader.self, from: Data(contentsOf: a.root.appendingPathComponent("header.json")))
        XCTAssertEqual(header.version, 2); XCTAssertEqual(header.wrappedKey?.count, 60)
        a.lock()
        XCTAssertThrowsError(try a.unlock(password: "160160"))
        try a.unlock(credential: credential)
        XCTAssertEqual(try a.contents(of: item.id), Data("original bytes".utf8))
        a.lock()
        try a.unlock(password: VaultCode.normalizeRecovery(secret).lowercased())
        let b = repo("b"); try b.create(password: secret)
        XCTAssertThrowsError(try b.unlock(credential: credential))
        XCTAssertFalse(b.isUnlocked)
        let fresh = VaultCode.generateRecovery()
        XCTAssertEqual(VaultCode.normalizeRecovery(fresh).count, 64)
        XCTAssertNotEqual(fresh, VaultCode.generateRecovery())
    }
    func testDatesAlbumsFavoriteAndRecentlyDeletedSurviveRecovery() throws {
        let a = repo("a"); try a.create(password: secret)
        let date = Date(timeIntervalSince1970: 1_680_000_000)
        let item = try a.add(data: Data([1, 2]), name: "original.heic", contentType: "public.heic",
            details: MediaDetails(captured: date, duration: 2.5, latitude: 1.25, longitude: 2.5))
        try a.update(id: item.id, favorite: true, album: "Summer", deleted: true)
        let backup = folder.appendingPathComponent("library.c84backup"); try a.exportBackup(to: backup)
        let b = repo("b"); try b.restore(from: backup, password: secret)
        let restored = try XCTUnwrap(b.items.first)
        XCTAssertEqual(restored.captured, date); XCTAssertEqual(restored.album, "Summer"); XCTAssertEqual(restored.favorite, true)
        XCTAssertEqual(restored.duration, 2.5); XCTAssertEqual(restored.latitude, 1.25); XCTAssertNotNil(restored.deletedAt)
        try b.update(id: item.id, deleted: false)
        XCTAssertNil(b.items[0].deletedAt)
        b.lock(); try b.unlock(password: secret); XCTAssertNil(b.items[0].deletedAt)
    }
    func testChunkedVideoLargerThanOldMemoryLimit() throws {
        let a = repo("a"); try a.create(password: secret)
        let source = folder.appendingPathComponent("large.mov")
        let handle = try VaultStream.newFile(source)
        let block = Data(repeating: 0xA7, count: 1024 * 1024)
        for _ in 0..<130 { try handle.write(contentsOf: block) }
        try handle.close()
        let item = try a.add(file: source, name: "large.mov", contentType: "com.apple.quicktime-movie")
        XCTAssertThrowsError(try a.contents(of: item.id)) // The memory path stays bounded.
        let restored = folder.appendingPathComponent("restored.mov")
        try a.materialize(id: item.id, to: restored)
        let input = try FileHandle(forReadingFrom: restored); defer { try? input.close() }
        for _ in 0..<130 { XCTAssertEqual(try VaultStream.exact(block.count, from: input), block) }
        XCTAssertTrue((try input.read(upToCount: 1) ?? Data()).isEmpty)
    }
    func testEmptyFilesAndChunkBoundariesRoundTrip() throws {
        let a = repo("a"); try a.create(password: secret)
        for size in [0, 1, VaultLimits.chunkBytes, VaultLimits.chunkBytes + 1] {
            let bytes = Data(repeating: 0x6F, count: size)
            let item = try a.add(data: bytes, name: "sample", contentType: "public.data")
            XCTAssertEqual(try a.contents(of: item.id), bytes)
        }
    }
    func testReorderedChunksAndDamagedMaterializationLeaveNoPlainOutput() throws {
        let a = repo("a"); try a.create(password: secret)
        let item = try a.add(data: Data(repeating: 7, count: 2 * VaultLimits.chunkBytes), name: "video", contentType: "public.movie")
        let path = a.root.appendingPathComponent(item.id.uuidString + ".enc")
        let data = try Data(contentsOf: path)
        let record = VaultLimits.chunkBytes + 36
        let swapped = data.prefix(16) + data[(16 + record)...] + data[16..<(16 + record)]
        try Data(swapped).write(to: path)
        let output = folder.appendingPathComponent("must-not-remain.mov")
        XCTAssertThrowsError(try a.materialize(id: item.id, to: output))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertThrowsError(try a.exportBackup(to: folder.appendingPathComponent("bad.c84backup")))
    }
    func testIncompleteImportIsNotPublishedAndIsRemovedOnReopen() throws {
        let a = repo("a"); try a.create(password: secret)
        let item = try a.add(data: Data([1]), name: "partial", contentType: "public.jpeg", pending: true)
        XCTAssertFalse(a.items[0].visible)
        a.lock(); try a.unlock(password: secret)
        XCTAssertTrue(a.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.root.appendingPathComponent(item.id.uuidString + ".enc").path))
    }
    func testMonthGroupingUsesCaptureDateAndStableOrder() throws {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        var a = VaultItem(id: UUID(), name: "a", contentType: "public.jpeg", byteCount: 1, added: now)
        a.captured = ISO8601DateFormatter().date(from: "2023-08-01T00:00:00Z")!
        var b = VaultItem(id: UUID(), name: "b", contentType: "public.jpeg", byteCount: 1, added: now)
        b.captured = ISO8601DateFormatter().date(from: "2023-09-01T00:00:00Z")!
        let captured = LibraryPresentation.sections([a, b], source: .captured, newestFirst: true, calendar: calendar)
        XCTAssertEqual(captured.count, 2); XCTAssertEqual(captured[0].items[0].id, b.id)
        XCTAssertEqual(LibraryPresentation.sections([a, b], source: .imported, newestFirst: true, calendar: calendar).count, 1)
        XCTAssertEqual(LibraryPresentation.sections([a, b], source: .captured, newestFirst: false, calendar: calendar)[0].items[0].id, a.id)
    }
    func testOriginalV1BackupAndLocalLibraryRemainReadable() throws {
        let backup = try legacyFixture()
        let target = repo("legacy-restored")
        try target.restore(from: backup, password: "original long password")
        XCTAssertEqual(try target.contents(of: target.items[0].id), Data("legacy original bytes".utf8))
        let credential = try target.credential(); target.lock()
        try target.unlock(credential: credential)
        try target.add(data: Data("new item".utf8), name: "new", contentType: "public.data")
        let updated = folder.appendingPathComponent("updated.c84backup"); try target.exportBackup(to: updated)
        let second = repo("second"); try second.restore(from: updated, password: "original long password")
        XCTAssertEqual(second.items.count, 2)
    }
    func testWriteIndependentRecoveryFixturesWhenRequested() throws {
        guard let path = ProcessInfo.processInfo.environment["C84_FIXTURE_DIR"] else { return }
        let destination = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let a = repo("a"); try a.create(password: secret)
        let photo = try a.add(data: Data("portable original bytes".utf8), name: "../../AUX.jpg", contentType: "public.jpeg",
            details: MediaDetails(captured: Date(timeIntervalSince1970: 1_680_000_000)))
        try a.organize(ids: [photo.id], albums: ["Travel", "Receipts"], tags: ["ticket", "été"], mode: .add)
        try a.setAlbumPreference(.init(pinned: true, coverID: photo.id), name: "Travel")
        try a.add(data: Data(repeating: 0xA7, count: VaultLimits.chunkBytes + 7), name: "video.mov", contentType: "public.movie")
        try a.add(data: Data(), name: "empty.bin", contentType: "public.data")
        try a.exportBackup(to: destination.appendingPathComponent("v2.c84backup"))
        // Public, disposable fixture key only; never a user secret or log value.
        let fresh = repo("fresh")
        try fresh.initializeFromBackups([.init(url: destination.appendingPathComponent("v2.c84backup"), recovery: secret)],
                                        recovery: String(repeating: "F", count: 64))
        try fresh.exportBackup(to: destination.appendingPathComponent("fresh.c84backup"))
        try FileManager.default.copyItem(at: legacyFixture(), to: destination.appendingPathComponent("v1.c84backup"))
    }
    func testPairedMediaBackupVerificationAndDeletion() async throws {
        let engine = VaultEngine(root: folder.appendingPathComponent("paired-library"))
        _ = try await engine.create(password: secret)
        let still = folder.appendingPathComponent("still.heic"), video = folder.appendingPathComponent("motion.mov")
        try Data("still resource".utf8).write(to: still)
        try Data("paired resource".utf8).write(to: video)
        let items = try await engine.add(file: still, name: "live.heic", contentType: "public.heic",
            companion: video, thumbnail: Data([1, 2, 3]))
        XCTAssertEqual(items.count, 3)
        let primary = try XCTUnwrap(items.first(where: \.visible))
        XCTAssertEqual(items.filter(\.visible).count, 1)
        let companion = try XCTUnwrap(primary.companionID)
        let bytes = try await engine.contents(id: companion)
        XCTAssertEqual(bytes, Data("paired resource".utf8))
        let backup = folder.appendingPathComponent("paired.c84backup")
        try await engine.export(to: backup)
        let count = try await engine.verifyBackup(from: backup, password: secret)
        XCTAssertEqual(count, 1)
        let unchanged = try await engine.contents(id: primary.id)
        XCTAssertEqual(unchanged, Data("still resource".utf8))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: folder.path).contains(where: { $0.hasPrefix("verify-") }))
        let empty = try await engine.remove(id: primary.id)
        XCTAssertTrue(empty.isEmpty)
        let restored = repo("paired-restored"); try restored.restore(from: backup, password: secret)
        XCTAssertEqual(restored.items.count, 3)
        XCTAssertEqual(try restored.contents(of: companion), Data("paired resource".utf8))
    }
    func testFailedCompanionImportRollsBackWithoutChangingExistingItems() async throws {
        let engine = VaultEngine(root: folder.appendingPathComponent("rollback-library"))
        _ = try await engine.create(password: secret)
        _ = try await engine.add(data: Data([9]), name: "keep", contentType: "public.data")
        let still = folder.appendingPathComponent("still.heic"); try Data([1, 2]).write(to: still)
        do {
            _ = try await engine.add(file: still, name: "incomplete", contentType: "public.heic",
                companion: folder.appendingPathComponent("missing.mov"))
            XCTFail("Missing companion should fail the entire new import")
        } catch { }
        await engine.lock()
        let result = try await engine.unlock(password: secret)
        XCTAssertEqual(result.count, 1); XCTAssertEqual(result[0].name, "keep")
        let bytes = try await engine.contents(id: result[0].id)
        XCTAssertEqual(bytes, Data([9]))
    }
    private func legacyFixture() throws -> URL {
        let header = VaultHeader(id: UUID(), salt: Data(repeating: 3, count: 32), rounds: VaultCrypto.rounds)
        let key = try VaultCrypto.derive(password: "original long password", salt: header.salt, rounds: header.rounds)
        let bytes = Data("legacy original bytes".utf8)
        let item = VaultItem(id: UUID(), name: "legacy.txt", contentType: "public.plain-text", byteCount: bytes.count, added: Date(timeIntervalSince1970: 1_680_000_000))
        let manifest = VaultManifest(version: 1, items: [item])
        let base = "Calc84/v1/\(header.id.uuidString)"
        let file = folder.appendingPathComponent(UUID().uuidString + ".c84backup")
        let handle = try VaultStream.newFile(file); defer { try? handle.close() }
        try handle.write(contentsOf: Data("C84B0001".utf8))
        try VaultStream.block(JSONEncoder().encode(header), to: handle)
        try VaultStream.block(VaultCrypto.seal(JSONEncoder().encode(manifest), key: key, context: base + "/manifest"), to: handle)
        try VaultStream.number(1, to: handle); try handle.write(contentsOf: Data(item.id.uuidString.utf8))
        try VaultStream.block(VaultCrypto.seal(bytes, key: key, context: base + "/" + item.id.uuidString), to: handle)
        return file
    }
}
