#if os(iOS)
import Foundation
import Security
import CalcCore

/// The short calculator code gates access on this installation. It is never a portable backup key.
actor DeviceAccess {
    struct RetryDelay: LocalizedError {
        let seconds: Int
        var errorDescription: String? { "Too many attempts. Try again in \(seconds) seconds." }
    }
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
    func forget(for id: UUID) throws {
        guard try load()?.credential.id == id else { return }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
    }
    func enroll(code: String, credential: VaultCredential) throws {
        guard VaultCode.valid(code) else { throw VaultError.invalidCode }
        let salt = VaultCode.salt()
        let record = Record(credential: credential, salt: salt, verifier: try VaultCode.verifier(code, salt: salt))
        try save(record)
    }
    func unlock(code: String, id: UUID, reportThrottle: Bool = false) throws -> VaultCredential? {
        guard var record = try load(), record.credential.id == id else { return nil }
        let now = Date()
        guard now >= record.nextAttempt else {
            // Ordinary calculator holds never advertise a private access attempt.
            // The explicit Change Code form can explain why retry is unavailable.
            if reportThrottle { throw RetryDelay(seconds: max(1, Int(ceil(record.nextAttempt.timeIntervalSince(now))))) }
            return nil
        }
        let verified = VaultCode.equal(try VaultCode.verifier(code, salt: record.salt), record.verifier)
        if verified {
            record.failures = 0; record.nextAttempt = .distantPast
            try save(record); return record.credential
        }
        record.failures = min(record.failures + 1, 20)
        if let delay = DeviceAccessBackoff.delay(failures: record.failures) { record.nextAttempt = Date().addingTimeInterval(delay) }
        try save(record); return nil
    }
    func change(old: String, new: String, id: UUID) throws {
        guard VaultCode.valid(new) else { throw VaultError.invalidCode }
        guard let credential = try unlock(code: old, id: id, reportThrottle: true) else { throw VaultError.wrongPasswordOrDamaged }
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
