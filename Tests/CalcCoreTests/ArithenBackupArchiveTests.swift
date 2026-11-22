import XCTest
@testable import CalcCore
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

final class ArithenBackupArchiveTests: XCTestCase {
    private var root: URL!
    private let key = SymmetricKey(data: Data(repeating: 42, count: 32))
    private let header = Data("{\"vault\":\"synthetic-header\"}".utf8)
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private struct Fixture {
        let prepared: ArithenBackupArchive.Prepared
        let sources: [UUID: URL]
        let url: URL
        let index: Data
    }
    private func fixture() throws -> Fixture {
        let ids = [UUID(), UUID()]
        var sources: [UUID: URL] = [:]
        for (offset, id) in ids.enumerated() {
            let url = root.appendingPathComponent(id.uuidString + ".enc")
            let sealed = try VaultCrypto.seal(Data(repeating: UInt8(offset + 1), count: 1024 + offset), key: key, context: id.uuidString)
            try sealed.write(to: url); sources[id] = url
        }
        let index = try VaultCrypto.seal(Data("encrypted index fixture".utf8), key: key, context: "index")
        let prepared = try ArithenBackupArchive.prepare(header: header, index: index, resources: sources, orderedIDs: ids, key: key)
        let url = root.appendingPathComponent(UUID().uuidString + ".arithenbackup")
        try ArithenBackupArchive.write(prepared, sources: sources, to: url)
        return Fixture(prepared: prepared, sources: sources, url: url, index: index)
    }
    private func read(_ url: URL, salvage: Bool = false) throws -> ArithenBackupArchive.Opened {
        try ArithenBackupArchive.read(url, allowIncompletePayload: salvage) { supplied in
            guard supplied == self.header else { throw VaultError.wrongPasswordOrDamaged }
            return self.key
        }
    }
    private func changed(_ fixture: Fixture, edit: (inout Data) -> Void) throws -> URL {
        var data = try Data(contentsOf: fixture.url); edit(&data)
        let url = root.appendingPathComponent(UUID().uuidString + ".arithenbackup")
        try data.write(to: url); return url
    }
    func testRoundTripCopiesAuthenticatedCiphertextWithoutPlaintextCatalogNames() throws {
        let fixture = try fixture(), opened = try read(fixture.url)
        XCTAssertFalse(opened.metadataRecovered)
        XCTAssertEqual(opened.header, header); XCTAssertEqual(opened.index, fixture.index)
        XCTAssertEqual(opened.records, fixture.prepared.records)
        XCTAssertTrue(try ArithenBackupArchive.hasSignature(fixture.url))
        for record in opened.records {
            let copy = root.appendingPathComponent(UUID().uuidString)
            try ArithenBackupArchive.copyResource(from: fixture.url, opened: opened, record: record, to: copy)
            XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: XCTUnwrap(fixture.sources[record.id])))
            XCTAssertFalse(try VaultCrypto.open(Data(contentsOf: copy), key: opened.key, context: record.id.uuidString).isEmpty)
        }
        XCTAssertFalse(String(decoding: fixture.prepared.envelope, as: UTF8.self).contains("encrypted index fixture"))
    }
    func testEmptyArchiveAndPreverifiedRecordPreparationRemainReadable() throws {
        let index = try VaultCrypto.seal(Data("empty index".utf8), key: key, context: "index")
        let empty = try ArithenBackupArchive.prepare(header: header, index: index, records: [], key: key)
        let url = root.appendingPathComponent("empty.arithenbackup")
        try ArithenBackupArchive.write(empty, sources: [:], to: url)
        let opened = try read(url)
        XCTAssertTrue(opened.records.isEmpty)
        XCTAssertFalse(opened.metadataRecovered)
        XCTAssertEqual(opened.index, index)
        XCTAssertThrowsError(try ArithenBackupArchive.prepare(header: header,
            index: Data(repeating: 0, count: VaultLimits.manifestBytes + 1), records: [], key: key))
    }
    func testCloudEnvelopeAuthenticatesBeforeAnyResourceDownload() throws {
        let fixture = try fixture()
        let metadata = try ArithenBackupArchive.authenticateEnvelope(fixture.prepared.envelope) { _ in self.key }
        XCTAssertEqual(metadata.header, header)
        XCTAssertEqual(metadata.index, fixture.index)
        XCTAssertEqual(metadata.records, fixture.prepared.records)
        XCTAssertThrowsError(try ArithenBackupArchive.authenticateEnvelope(fixture.prepared.envelope) { _ in
            SymmetricKey(data: Data(repeating: 0, count: 32))
        })
        var damaged = fixture.prepared.envelope; damaged[damaged.count / 2] ^= 1
        XCTAssertThrowsError(try ArithenBackupArchive.authenticateEnvelope(damaged) { _ in self.key })
    }
    func testWrongKeyAndBothDamagedCatalogsReject() throws {
        let fixture = try fixture()
        XCTAssertThrowsError(try ArithenBackupArchive.read(fixture.url) { _ in SymmetricKey(data: Data(repeating: 9, count: 32)) })
        let corrupt = try changed(fixture) { data in
            data[16] ^= 0xff
            data[data.count - 16 - fixture.prepared.envelope.count] ^= 0xff
        }
        XCTAssertThrowsError(try read(corrupt))
    }
    func testDamagedPrimaryMagicLengthOrCatalogRecoversFromFooter() throws {
        let fixture = try fixture()
        for position in [0, 8, 16] {
            let corrupt = try changed(fixture) { $0[position] ^= 0xff }
            let opened = try read(corrupt)
            XCTAssertTrue(opened.metadataRecovered); XCTAssertEqual(opened.records, fixture.prepared.records)
            XCTAssertTrue(try ArithenBackupArchive.hasSignature(corrupt))
        }
    }
    func testDamagedOrMissingRedundantFooterRecoversOnlyWhenBodyIsComplete() throws {
        let fixture = try fixture()
        let bodyEnd = 16 + fixture.prepared.envelope.count + fixture.prepared.records.reduce(0) { $0 + $1.bytes }
        for position in [bodyEnd, bodyEnd + fixture.prepared.envelope.count, bodyEnd + fixture.prepared.envelope.count + 8] {
            let corrupt = try changed(fixture) { $0[position] ^= 0xff }
            XCTAssertTrue(try read(corrupt).metadataRecovered)
        }
        let truncated = try changed(fixture) { $0 = $0.prefix(bodyEnd) }
        XCTAssertTrue(try read(truncated).metadataRecovered)
        let missingBodyByte = try changed(fixture) { $0 = $0.prefix(bodyEnd - 1) }
        XCTAssertThrowsError(try read(missingBodyByte))
    }
    func testExplicitPartialRecoveryCopiesCompleteResourceAndRejectsTruncatedOne() throws {
        let fixture = try fixture()
        let first = fixture.prepared.records[0]
        let length = 16 + fixture.prepared.envelope.count + first.bytes + 5
        let truncated = try changed(fixture) { $0 = $0.prefix(length) }
        XCTAssertThrowsError(try read(truncated))
        let opened = try read(truncated, salvage: true)
        let destination = root.appendingPathComponent("complete")
        try ArithenBackupArchive.copyResource(from: truncated, opened: opened, record: first, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: XCTUnwrap(fixture.sources[first.id])))
        let missing = root.appendingPathComponent("truncated")
        XCTAssertThrowsError(try ArithenBackupArchive.copyResource(from: truncated, opened: opened, record: opened.records[1], to: missing))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    }
    func testExtraTrailingBytesAndConflictingAuthenticatedCatalogsReject() throws {
        let fixture = try fixture()
        let extra = try changed(fixture) { $0.append(0) }
        XCTAssertThrowsError(try read(extra))
        XCTAssertThrowsError(try read(extra, salvage: true))
        let other = try ArithenBackupArchive.prepare(header: header, index: fixture.index, resources: fixture.sources,
            orderedIDs: fixture.prepared.records.map(\.id), key: key)
        XCTAssertEqual(other.envelope.count, fixture.prepared.envelope.count)
        let mixed = try changed(fixture) { data in
            let start = data.count - 16 - fixture.prepared.envelope.count
            data.replaceSubrange(start..<(start + fixture.prepared.envelope.count), with: other.envelope)
        }
        XCTAssertThrowsError(try read(mixed))
    }
    func testResourceCorruptionIsIsolatedAndFailedCopyIsRemoved() throws {
        let fixture = try fixture()
        let corrupt = try changed(fixture) { $0[16 + fixture.prepared.envelope.count + 9] ^= 1 }
        let opened = try read(corrupt)
        let failed = root.appendingPathComponent("failed-copy")
        XCTAssertThrowsError(try ArithenBackupArchive.copyResource(from: corrupt, opened: opened, record: opened.records[0], to: failed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path))
        let good = root.appendingPathComponent("good-copy")
        try ArithenBackupArchive.copyResource(from: corrupt, opened: opened, record: opened.records[1], to: good)
        XCTAssertEqual(try Data(contentsOf: good), try Data(contentsOf: XCTUnwrap(fixture.sources[opened.records[1].id])))
    }
    func testWritesNeverOverwriteAndChangedSourceDoesNotLeaveArchive() throws {
        let fixture = try fixture(), opened = try read(fixture.url)
        let original = try Data(contentsOf: fixture.url)
        XCTAssertThrowsError(try ArithenBackupArchive.write(fixture.prepared, sources: fixture.sources, to: fixture.url))
        XCTAssertEqual(try Data(contentsOf: fixture.url), original)
        let existing = root.appendingPathComponent("existing")
        try Data("keep".utf8).write(to: existing)
        XCTAssertThrowsError(try ArithenBackupArchive.copyResource(from: fixture.url, opened: opened, record: opened.records[0], to: existing))
        XCTAssertEqual(try Data(contentsOf: existing), Data("keep".utf8))
        let source = try XCTUnwrap(fixture.sources[opened.records[0].id])
        var data = try Data(contentsOf: source); data[0] ^= 1; try data.write(to: source)
        let failed = root.appendingPathComponent("failed-archive")
        XCTAssertThrowsError(try ArithenBackupArchive.write(fixture.prepared, sources: fixture.sources, to: failed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path))
    }
    func testHeaderBytesAreBoundEvenIfUnlockReturnsSameKey() throws {
        let fixture = try fixture()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture.prepared.envelope) as? [String: Any])
        json["vaultHeader"] = Data("different header".utf8).base64EncodedString()
        let altered = try JSONSerialization.data(withJSONObject: json)
        let url = root.appendingPathComponent("changed-header")
        try ArithenBackupArchive.write(.init(envelope: altered, records: fixture.prepared.records), sources: fixture.sources, to: url)
        XCTAssertThrowsError(try ArithenBackupArchive.read(url) { _ in self.key })
    }
    func testMalformedLengthsRecordsAndDuplicateIDsFailBoundedly() throws {
        let fixture = try fixture()
        let corrupt = try changed(fixture) { data in
            data.replaceSubrange(8..<16, with: Data(repeating: 255, count: 8))
            data.replaceSubrange((data.count - 16)..<(data.count - 8), with: Data(repeating: 255, count: 8))
        }
        XCTAssertThrowsError(try read(corrupt))
        let bad = ArithenBackupArchive.Record(id: UUID(), bytes: Int.max, sha256: String(repeating: "a", count: 64))
        XCTAssertThrowsError(try ArithenBackupArchive.write(.init(envelope: fixture.prepared.envelope, records: [bad]), sources: [:], to: root.appendingPathComponent("oversize")))
        let ids = fixture.prepared.records.map(\.id)
        XCTAssertThrowsError(try ArithenBackupArchive.prepare(header: header, index: fixture.index, resources: fixture.sources, orderedIDs: [ids[0], ids[0]], key: key))
    }
    func testCancellationDoesNotCreateAnArchive() async throws {
        let fixture = try fixture(), destination = root.appendingPathComponent("cancelled")
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try ArithenBackupArchive.write(fixture.prepared, sources: fixture.sources, to: destination)
        }
        do { try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }
}
