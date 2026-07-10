import Foundation
import Security

nonisolated enum Sub2APICredentialStoreError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case keychain(OSStatus)
}

nonisolated protocol Sub2APICredentialStoring: Sendable {
    func loadBearerKey(credentialID: String) throws -> String?
    func saveBearerKey(_ bearerKey: String, credentialID: String) throws
    func deleteBearerKey(credentialID: String) throws
}

nonisolated struct KeychainSub2APICredentialStore: Sub2APICredentialStoring {
    static let defaultService = "com.iBobby.UlanziDeckSwift.sub2api.bearer"

    private let service: String

    init(service: String = Self.defaultService) {
        self.service = service
    }

    func loadBearerKey(credentialID: String) throws -> String? {
        var query = baseQuery(credentialID: credentialID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw Sub2APICredentialStoreError.keychain(status)
        }
        guard let data = result as? Data,
              let bearerKey = String(data: data, encoding: .utf8)
        else {
            throw Sub2APICredentialStoreError.decodingFailed
        }

        return bearerKey
    }

    func saveBearerKey(_ bearerKey: String, credentialID: String) throws {
        guard let data = bearerKey.data(using: .utf8) else {
            throw Sub2APICredentialStoreError.encodingFailed
        }

        let query = baseQuery(credentialID: credentialID)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw Sub2APICredentialStoreError.keychain(updateStatus)
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw Sub2APICredentialStoreError.keychain(addStatus)
        }
    }

    func deleteBearerKey(credentialID: String) throws {
        let status = SecItemDelete(baseQuery(credentialID: credentialID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Sub2APICredentialStoreError.keychain(status)
        }
    }

    private func baseQuery(credentialID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentialID,
        ]
    }
}
