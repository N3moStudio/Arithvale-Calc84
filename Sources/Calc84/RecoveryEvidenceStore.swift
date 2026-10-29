#if os(iOS)
import Foundation
import CalcCore

enum RecoveryEvidenceStore {
    static let key = "backupRecoveryEvidence.v1"
    static func load() -> [RecoveryCheck] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([RecoveryCheck].self, from: data) else { return [] }
        return records
    }
    static func save(_ records: [RecoveryCheck]) {
        if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) }
    }
}
#endif
