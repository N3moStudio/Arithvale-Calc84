import Foundation
import XCTest
@testable import CalcCore

final class CodexCapacityTests: XCTestCase {
    func testStreamedVaultCapacity() throws {
        guard ProcessInfo.processInfo.environment["ARITHEN_CAPACITY_QA"] == "1" else { throw XCTSkip("Opt-in disk benchmark") }
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("synthetic.bin")
        XCTAssertTrue(fm.createFile(atPath: source.path, contents: nil))
        let handle = try FileHandle(forWritingTo: source)
        defer { try? handle.close() }
        let gib = 1024 * 1024 * 1024
        let repo = VaultRepository(root: root.appendingPathComponent("vault"))
        let password = "disposable capacity benchmark"
        try repo.create(password: password)
        try handle.truncate(atOffset: UInt64(VaultLimits.fileBytes) + 1)
        XCTAssertThrowsError(try repo.add(file: source, name: "oversized", contentType: "public.data")) { error in
            guard case VaultError.limit = error else { return XCTFail(String(describing: error)) }
        }
        XCTAssertTrue(repo.items.isEmpty)
        var stored = 0
        for size in [gib / 2, gib, 5 * gib, 16 * gib, 24 * gib, 20 * gib] {
            // Allow room for output/materialization plus six GiB for the runner.
            let available = try XCTUnwrap((fm.attributesOfFileSystem(forPath: root.path)[.systemFreeSize] as? NSNumber)?.int64Value)
            guard available >= Int64(2 * size + 6 * gib) else {
                print("MEDIA_QA storageStop freeBytes=\(available) nextBytes=\(size)")
                break
            }
            try handle.truncate(atOffset: UInt64(size))
            try handle.seek(toOffset: UInt64(size - 8))
            var marker = UInt64(size).bigEndian
            try withUnsafeBytes(of: &marker) { try handle.write(contentsOf: Data($0)) }
            try handle.synchronize()
            let start = ProcessInfo.processInfo.systemUptime
            let item = try repo.add(file: source, name: "stage-\(size)", contentType: "public.data")
            let added = ProcessInfo.processInfo.systemUptime - start
            let exported = root.appendingPathComponent("verified.bin")
            try repo.materialize(id: item.id, to: exported)
            XCTAssertTrue(fm.contentsEqual(atPath: source.path, andPath: exported.path))
            try fm.removeItem(at: exported)
            stored += size
            repo.lock()
            try repo.unlock(password: password)
            XCTAssertEqual(repo.items.reduce(0) { $0 + $1.byteCount }, stored)
            print("MEDIA_QA streamedBytes=\(size) vaultBytes=\(stored) committedSeconds=\(added) freeBefore=\(available) reopened=true comparedAllBytes=true")
        }
        XCTAssertGreaterThanOrEqual(stored, gib / 2)
    }
}
