#if os(iOS)
import Foundation
import Security
import CalcCore

/// The short calculator code gates access on this installation. It is never a portable backup key.
actor DeviceAccess {
    private struct Record: Codable {
        var credential: VaultCredential
        var salt: Data
        var verifier: Data
        var failures = 0
        var nextAttempt = Date.distantPast
    }
    private var service: String { (Bundle.main.bundleIdentifier ?? "studio.n3mo.calc84") + ".device-access.v2" }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "local-library", kSecAttrSynchronizable as String: false]
    }
    func configured(for id: UUID) throws -> Bool { try load()?.credential.id == id }
    func enroll(code: String, credential: VaultCredential) throws {
        guard VaultCode.valid(code) else { throw VaultError.invalidCode }
        let salt = VaultCode.salt()
        let record = Record(credential: credential, salt: salt, verifier: try VaultCode.verifier(code, salt: salt))
        try save(record)
    }
    func unlock(code: String, id: UUID) throws -> VaultCredential? {
        guard var record = try load(), record.credential.id == id else { return nil }
        guard Date() >= record.nextAttempt else { return nil }
        let verified = VaultCode.equal(try VaultCode.verifier(code, salt: record.salt), record.verifier)
        if verified {
            record.failures = 0; record.nextAttempt = .distantPast
            try save(record); return record.credential
        }
        record.failures = min(record.failures + 1, 20)
        if record.failures >= 5 { record.nextAttempt = Date().addingTimeInterval(min(300, 30 * pow(2, Double(record.failures - 5)))) }
        try save(record); return nil
    }
    func change(old: String, new: String, id: UUID) throws {
        guard VaultCode.valid(new) else { throw VaultError.invalidCode }
        guard let credential = try unlock(code: old, id: id) else { throw VaultError.wrongPasswordOrDamaged }
        try enroll(code: new, credential: credential)
    }
    private func load() throws -> Record? {
        var request = query
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw keychainError(status) }
        return try JSONDecoder().decode(Record.self, from: data)
    }
    private func save(_ record: Record) throws {
        let data = try JSONEncoder().encode(record)
        let update = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as [String: Any]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var request = query; update.forEach { request[$0.key] = $0.value }
            status = SecItemAdd(request as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw keychainError(status) }
    }
    private func keychainError(_ status: OSStatus) -> NSError {
        NSError(domain: "Calc84.Access", code: Int(status), userInfo: [NSLocalizedDescriptionKey:
            "This installation could not access its secure storage. Unlock the phone and try again. Keep your recovery key and backup."])
    }
}
#endif
