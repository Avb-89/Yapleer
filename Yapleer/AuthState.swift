//
//  AuthState.swift
//  Yapleer
//
//  Created by SITIS on 6/30/26.
//

import Foundation
import Combine

@MainActor
final class AuthState: ObservableObject {
    enum Status: Equatable {
        case checking
        case unauthenticated
        case authenticated
        case failed(String)
    }

    @Published private(set) var status: Status = .checking
    @Published private(set) var yandexToken = ""
    @Published private(set) var accountTitle = ""

    private let keychain = KeychainService.shared

    init() {
        Task {
            await loadSavedToken()
        }
    }

    func loadSavedToken() async {
        status = .checking

        do {
            guard let token = try keychain.readYandexToken(), !token.isEmpty else {
                yandexToken = ""
                accountTitle = ""
                status = .unauthenticated
                return
            }

            try await validateAndSetToken(token)
        } catch {
            yandexToken = ""
            accountTitle = ""
            status = .unauthenticated
            print("AuthState load saved token failed:", error)
        }
    }

    func saveTokenAndLogin(_ token: String) async {
        do {
            try keychain.saveYandexToken(token)
            try await validateAndSetToken(token)
        } catch {
            yandexToken = ""
            accountTitle = ""
            status = .failed(error.localizedDescription)
            print("AuthState save token failed:", error)
        }
    }

    func logout() {
        do {
            try keychain.deleteYandexToken()
        } catch {
            print("AuthState delete token failed:", error)
        }

        yandexToken = ""
        accountTitle = ""
        status = .unauthenticated
    }

    private func validateAndSetToken(_ token: String) async throws {
        status = .checking

        let account = try await YandexMusicClient(token: token).fetchAccountStatus()
        yandexToken = token
        accountTitle = account.displayName ?? account.login ?? "Яндекс Музыка"
        status = .authenticated
    }
}
