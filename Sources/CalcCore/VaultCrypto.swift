import Foundation
#if canImport(CryptoKit)
import CryptoKit
import CommonCrypto
#else
import Crypto
import CryptoExtras
#endif

enum VaultCrypto {
    static let rounds = 600_000

    static func random(_ count: Int) -> Data {
        var generator = SystemRandomNumberGenerator()
        return Data((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }

    static func derive(password: String, salt: Data, rounds: Int) throws -> SymmetricKey {
        guard password.utf8.count <= 1024 else { throw VaultError.invalidPassword }
        let passwordBytes = Array(password.utf8)
        #if canImport(CommonCrypto)
        var result = [UInt8](repeating: 0, count: 32)
        let status = passwordBytes.withUnsafeBytes { passwordBuffer in
            salt.withUnsafeBytes { saltBuffer in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self), passwordBytes.count,
                    saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(rounds), &result, 32)
            }
        }
        guard status == kCCSuccess else { throw VaultError.wrongPasswordOrDamaged }
        return SymmetricKey(data: result)
        #else
        return try KDF.Insecure.PBKDF2.deriveKey(from: passwordBytes, salt: salt,
            using: .sha256, outputByteCount: 32, rounds: rounds)
        #endif
    }

    static func seal(_ data: Data, key: SymmetricKey, context: String) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key,
            authenticating: Data(context.utf8)).combined else { throw VaultError.wrongPasswordOrDamaged }
        return combined
    }

    static func open(_ data: Data, key: SymmetricKey, context: String) throws -> Data {
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key,
                authenticating: Data(context.utf8))
        } catch { throw VaultError.wrongPasswordOrDamaged }
    }
}
