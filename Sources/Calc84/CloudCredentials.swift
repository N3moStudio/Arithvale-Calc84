#if os(iOS)
import Foundation
import Security
import CalcCore

enum CloudProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case blomp, mega
    var id: String { rawValue }
    var title: String { self == .blomp ? "Blomp" : "MEGA" }
}

struct CloudLogin: Codable, Sendable {
    let email: String
    // Blomp needs the password to refresh its token. MEGA stores only its session.
    let secret: String
    var appKey: String? = nil
}

enum CloudCredentials {
    private static func query(_ provider: CloudProvider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "studio.n3mo.calc84") + ".cloud.v1",
         kSecAttrAccount as String: provider.rawValue, kSecAttrSynchronizable as String: false]
    }
    static func load(_ provider: CloudProvider) throws -> CloudLogin? {
        var request = query(provider)
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CloudError.authentication }
        return try JSONDecoder().decode(CloudLogin.self, from: data)
    }
    static func save(_ login: CloudLogin, for provider: CloudProvider) throws {
        let update: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(login),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status = SecItemUpdate(query(provider) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var request = query(provider); update.forEach { request[$0.key] = $0.value }
            status = SecItemAdd(request as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CloudError.authentication }
    }
    static func remove(_ provider: CloudProvider) throws {
        let status = SecItemDelete(query(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CloudError.authentication }
    }
}
#endif
