import Foundation

public enum VaultError: Error, LocalizedError {
    case invalidPassword, wrongPasswordOrDamaged, invalidBackup, limit, exists, locked, missing, changed, invalidCode
    public var errorDescription: String? {
        switch self {
        case .invalidPassword: return "Use at least 14 characters. A few unrelated words work well."
        case .wrongPasswordOrDamaged: return "The password is incorrect, or the encrypted data is damaged."
        case .invalidBackup: return "This backup is incomplete or unsupported. Your current files have not changed."
        case .limit: return "This version supports files up to 4 GB and libraries up to 64 GB. Check available storage too."
        case .exists: return "A library already exists. Restore is available only in an empty installation."
        case .locked: return "Unlock your library again."
        case .missing: return "The encrypted file could not be found."
        case .changed: return "The library changed. Create a fresh backup."
        case .invalidCode: return "Choose 6–12 digits, different from the starter code 160160."
        }
    }
}

public struct VaultItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public let contentType: String
    public let byteCount: Int
    public let added: Date
    public var captured: Date? = nil
    public var duration: Double? = nil
    public var latitude: Double? = nil
    public var longitude: Double? = nil
    public var favorite: Bool? = nil
    public var album: String? = nil
    public var deletedAt: Date? = nil
    public var storageVersion: Int? = nil
    public var companionID: UUID? = nil
    public var companionType: String? = nil
    public var isCompanion: Bool? = nil
    public var thumbnailID: UUID? = nil
    public var isThumbnail: Bool? = nil
    public var pendingImport: Bool? = nil
    public var chronologicalDate: Date { captured ?? added }
    public var visible: Bool { isCompanion != true && isThumbnail != true && pendingImport != true }
}

public struct MediaDetails: Sendable {
    public var captured: Date?
    public var duration: Double?
    public var latitude: Double?
    public var longitude: Double?
    public init(captured: Date? = nil, duration: Double? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.captured = captured; self.duration = duration; self.latitude = latitude; self.longitude = longitude
    }
}

public struct VaultCredential: Codable, Sendable {
    public let id: UUID
    public let key: Data
}

public enum VaultCode {
    public static let starter = "160160"
    public static func valid(_ code: String) -> Bool {
        (6...12).contains(code.count) && code.utf8.allSatisfy { (48...57).contains($0) } && code != starter
    }
    public static func isDirectEntry(_ expression: String, evaluated: Bool) -> Bool {
        !evaluated && (6...12).contains(expression.count) && expression.utf8.allSatisfy { (48...57).contains($0) }
    }
    public static func generateRecovery() -> String {
        VaultCrypto.random(32).map { String(format: "%02X", $0) }.enumerated().map {
            ($0.offset > 0 && $0.offset % 4 == 0 ? "-" : "") + $0.element
        }.joined()
    }
    public static func normalizeRecovery(_ text: String) -> String {
        let compact = text.filter { !$0.isWhitespace && $0 != "-" }
        if compact.count == 64 && compact.allSatisfy(\.isHexDigit) { return compact.uppercased() }
        return text // Existing 0.1 passwords must remain byte-for-byte compatible.
    }
    public static func verifier(_ code: String, salt: Data) throws -> Data {
        try VaultCrypto.derive(password: code, salt: salt, rounds: VaultCrypto.rounds).withUnsafeBytes { Data($0) }
    }
    public static func equal(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
    public static func salt() -> Data { VaultCrypto.random(32) }
}

struct VaultManifest: Codable {
    var version = 2
    var items: [VaultItem] = []
}

struct VaultHeader: Codable {
    var version = 1
    var id: UUID
    var salt: Data
    var rounds: Int
    var wrappedKey: Data? = nil

    func validate() throws {
        guard (version == 1 || version == 2), salt.count == 32, rounds == VaultCrypto.rounds,
              (version == 1 || wrappedKey?.count == 60) else {
            throw VaultError.invalidBackup
        }
    }
}

public enum VaultLimits {
    public static let fileBytes = 4 * 1024 * 1024 * 1024
    public static let backupBytes = 64 * 1024 * 1024 * 1024
    public static let memoryBytes = 128 * 1024 * 1024
    public static let chunkBytes = 1024 * 1024
    public static let manifestBytes = 4 * 1024 * 1024
    public static let itemCount = 5_000
}
