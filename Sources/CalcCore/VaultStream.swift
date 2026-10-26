import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// Independently authenticated 1 MiB records. AAD binds vault, file, total size, and record position.
enum VaultStream {
    static func encryptedSize(_ size: Int) -> Int {
        16 + size + max(1, (size + VaultLimits.chunkBytes - 1) / VaultLimits.chunkBytes) * 36
    }
    static func newFile(_ url: URL) throws -> FileHandle {
        guard !FileManager.default.fileExists(atPath: url.path) else { throw VaultError.exists }
        #if os(iOS)
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.complete]
        #else
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        #endif
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: attributes) else { throw VaultError.missing }
        return try FileHandle(forWritingTo: url)
    }
    static func encrypt(_ source: URL, to destination: URL, size: Int, key: SymmetricKey, context: String) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try newFile(destination)
        var completed = false
        defer { try? output.close(); if !completed { try? FileManager.default.removeItem(at: destination) } }
        try output.write(contentsOf: Data("C84F0002".utf8)); try number(UInt64(size), to: output)
        let count = max(1, (size + VaultLimits.chunkBytes - 1) / VaultLimits.chunkBytes)
        for index in 0..<count {
            try Task.checkCancellation()
            let data = try exact(min(VaultLimits.chunkBytes, size - index * VaultLimits.chunkBytes), from: input)
            try block(VaultCrypto.seal(data, key: key, context: "\(context)/chunk/\(index)/\(size)"), to: output)
        }
        guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw VaultError.changed }
        try output.synchronize(); completed = true
    }
    static func encrypt(_ data: Data, to destination: URL, key: SymmetricKey, context: String) throws {
        let output = try newFile(destination)
        var completed = false
        defer { try? output.close(); if !completed { try? FileManager.default.removeItem(at: destination) } }
        try output.write(contentsOf: Data("C84F0002".utf8)); try number(UInt64(data.count), to: output)
        for index in 0..<max(1, (data.count + VaultLimits.chunkBytes - 1) / VaultLimits.chunkBytes) {
            let start = index * VaultLimits.chunkBytes
            let end = min(start + VaultLimits.chunkBytes, data.count)
            try block(VaultCrypto.seal(Data(data[start..<end]), key: key, context: "\(context)/chunk/\(index)/\(data.count)"), to: output)
        }
        try output.synchronize(); completed = true
    }
    static func decrypt(_ source: URL, to destination: URL?, size: Int, key: SymmetricKey, context: String) throws {
        let output = try destination.map(newFile)
        var completed = false
        defer {
            try? output?.close()
            if !completed, let destination { try? FileManager.default.removeItem(at: destination) }
        }
        try process(source, size: size, key: key, context: context) { try output?.write(contentsOf: $0) }
        try output?.synchronize(); completed = true
    }
    static func read(_ source: URL, size: Int, key: SymmetricKey, context: String) throws -> Data {
        var data = Data()
        try process(source, size: size, key: key, context: context) { data.append($0) }
        return data
    }
    static func digest(_ source: URL, size: Int, key: SymmetricKey, context: String) throws -> Data {
        var hash = SHA256()
        try process(source, size: size, key: key, context: context) { hash.update(data: $0) }
        return Data(hash.finalize())
    }
    /// Authenticate each source chunk and immediately seal it under the destination
    /// key with fresh nonces. No plaintext file or whole-video allocation is needed.
    static func reencrypt(_ source: URL, to destination: URL, size: Int,
                          sourceKey: SymmetricKey, sourceContext: String,
                          key: SymmetricKey, context: String) throws {
        let output = try newFile(destination)
        var complete = false
        defer { try? output.close(); if !complete { try? FileManager.default.removeItem(at: destination) } }
        try output.write(contentsOf: Data("C84F0002".utf8)); try number(UInt64(size), to: output)
        var index = 0
        try process(source, size: size, key: sourceKey, context: sourceContext) { chunk in
            try block(VaultCrypto.seal(chunk, key: key, context: "\(context)/chunk/\(index)/\(size)"), to: output)
            index += 1
        }
        try output.synchronize(); complete = true
    }
    private static func process(_ source: URL, size: Int, key: SymmetricKey, context: String, consume: (Data) throws -> Void) throws {
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        guard try exact(8, from: input) == Data("C84F0002".utf8), try number(from: input) == UInt64(size) else { throw VaultError.invalidBackup }
        let count = max(1, (size + VaultLimits.chunkBytes - 1) / VaultLimits.chunkBytes)
        for index in 0..<count {
            try Task.checkCancellation()
            let length = min(VaultLimits.chunkBytes, size - index * VaultLimits.chunkBytes)
            let sealed = try block(from: input, limit: length + 28)
            guard sealed.count == length + 28 else { throw VaultError.invalidBackup }
            let plain = try VaultCrypto.open(sealed, key: key, context: "\(context)/chunk/\(index)/\(size)")
            try consume(plain)
        }
        guard (try input.read(upToCount: 1) ?? Data()).isEmpty else { throw VaultError.invalidBackup }
    }
    static func number(_ value: UInt64, to handle: FileHandle) throws {
        var big = value.bigEndian
        try withUnsafeBytes(of: &big) { try handle.write(contentsOf: Data($0)) }
    }
    static func number(from handle: FileHandle) throws -> UInt64 { try exact(8, from: handle).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } }
    static func block(_ data: Data, to handle: FileHandle) throws { try number(UInt64(data.count), to: handle); try handle.write(contentsOf: data) }
    static func block(from handle: FileHandle, limit: Int) throws -> Data {
        let size = try number(from: handle)
        guard size <= UInt64(limit) else { throw VaultError.invalidBackup }
        return try exact(Int(size), from: handle)
    }
    static func exact(_ count: Int, from handle: FileHandle) throws -> Data {
        var result = Data()
        while result.count < count {
            guard let chunk = try handle.read(upToCount: min(1024 * 1024, count - result.count)), !chunk.isEmpty else { throw VaultError.invalidBackup }
            result.append(chunk)
        }
        return result
    }
    static func copy(_ input: FileHandle, to output: FileHandle, count: Int) throws {
        var left = count
        while left > 0 {
            try Task.checkCancellation()
            let data = try exact(min(VaultLimits.chunkBytes, left), from: input)
            try output.write(contentsOf: data); left -= data.count
        }
    }
}
