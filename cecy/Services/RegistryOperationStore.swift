import Foundation
import Security

nonisolated struct RegistryOperation: Codable, Equatable, Sendable {
    enum Kind: String, Codable { case activate, deleting, deactivate }
    let revision: UUID
    let id: String
    let kind: Kind
    let displayName: String?
    var attempts = 0
    var nextAttempt = Date.distantPast
    var blocked = false

    init(id: String, kind: Kind, displayName: String? = nil) {
        revision = UUID()
        self.id = id
        self.kind = kind
        self.displayName = kind == .activate ? RegistryIdentity.displayName(displayName) : nil
    }
}

@MainActor protocol RegistryOperationStoring {
    func load() throws -> [RegistryOperation]
    func save(_ operations: [RegistryOperation]) throws
}

@MainActor final class MemoryRegistryOperationStore: RegistryOperationStoring {
    var operations: [RegistryOperation] = []
    func load() -> [RegistryOperation] { operations }
    func save(_ operations: [RegistryOperation]) { self.operations = operations }
}

@MainActor final class KeychainRegistryOperationStore: RegistryOperationStoring {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "xyz.thabo.cecy") + ".registry-outbox",
         kSecAttrAccount as String: "pending-operations-v1",
         kSecAttrSynchronizable as String: false]
    }

    func load() throws -> [RegistryOperation] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data else { throw AccountError.storage }
        let operations = try JSONDecoder().decode([RegistryOperation].self, from: data)
        guard Set(operations.map(\.id)).count == operations.count,
              operations.allSatisfy({ RegistryIdentity.isValid($0.id) && $0.attempts >= 0 &&
                  ($0.kind == .activate ? $0.displayName != nil : $0.displayName == nil) }) else {
            throw AccountError.storage
        }
        return operations
    }

    func save(_ operations: [RegistryOperation]) throws {
        if operations.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw AccountError.storage }
            return
        }
        let attributes: [String: Any] = [kSecValueData as String: try JSONEncoder().encode(operations),
                                       kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let insert = query.merging(attributes) { _, new in new }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw AccountError.storage }
        } else if status != errSecSuccess { throw AccountError.storage }
    }
}