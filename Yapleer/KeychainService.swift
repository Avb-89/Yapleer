//
//  KeychainService.swift
//  Yapleer
//
//  Created by SITIS on 6/30/26.
//

import Foundation
import Security

enum KeychainServiceError: Error {
    case invalidData
    case unexpectedStatus(OSStatus)
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.sitis.Yapleer"
    private let tokenAccount = "yandexMusicAccessToken"

    private init() {}

    func saveYandexToken(_ token: String) throws {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmedToken.data(using: .utf8), !trimmedToken.isEmpty else {
            throw KeychainServiceError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainServiceError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            throw KeychainServiceError.unexpectedStatus(addStatus)
        }
    }

    func readYandexToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainServiceError.unexpectedStatus(status)
        }

        guard let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainServiceError.invalidData
        }

        return token
    }

    func deleteYandexToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }

        throw KeychainServiceError.unexpectedStatus(status)
    }
}
