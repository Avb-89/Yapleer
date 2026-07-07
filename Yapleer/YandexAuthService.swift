//
//  YandexAuthService.swift
//  Yapleer
//
//  Created by SITIS on 6/30/26.
//

import Foundation

enum YandexAuthServiceError: LocalizedError {
    case invalidResponse
    case authorizationPending
    case slowDown
    case expiredToken
    case accessDenied
    case oauthError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Яндекс вернул неожиданный ответ."
        case .authorizationPending:
            return "Пользователь ещё не подтвердил вход."
        case .slowDown:
            return "Яндекс попросил опрашивать авторизацию реже."
        case .expiredToken:
            return "Код авторизации истёк."
        case .accessDenied:
            return "Пользователь отменил вход."
        case .oauthError(let message):
            return message
        }
    }
}

struct YandexDeviceCodeResponse {
    let deviceCode: String
    let userCode: String
    let verificationURL: URL
    let expiresIn: Int
    let interval: Int
}

struct YandexTokenResponse {
    let accessToken: String
}

final class YandexAuthService {
    static let shared = YandexAuthService()

    private let clientId = "23cabbbdc6cd418abb4b39c32c41195d"
    private let clientSecret = "53bc75238f0c4d08a118e51fe9203300"
    private let deviceName = "YandexMusicAPI"

    private let deviceCodeURL = URL(string: "https://oauth.yandex.ru/device/code")!
    private let tokenURL = URL(string: "https://oauth.yandex.ru/token")!

    private init() {}

    func requestDeviceCode() async throws -> YandexDeviceCodeResponse {
        let response = try await postForm(
            url: deviceCodeURL,
            parameters: [
                "client_id": clientId,
                "device_id": randomDeviceId(),
                "device_name": deviceName
            ]
        )

        let verificationURLString = response["verification_url"] as? String
            ?? response["verification_uri"] as? String

        guard let deviceCode = response["device_code"] as? String,
              let userCode = response["user_code"] as? String,
              let verificationURLString,
              let verificationURL = URL(string: verificationURLString) else {
            throw parseOAuthError(from: response) ?? YandexAuthServiceError.invalidResponse
        }

        let expiresIn = response["expires_in"] as? Int ?? 600
        let interval = response["interval"] as? Int ?? 5

        return YandexDeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURL: verificationURL,
            expiresIn: expiresIn,
            interval: interval
        )
    }

    func pollToken(deviceCode: String) async throws -> YandexTokenResponse {
        let parameters: [String: String] = [
            "grant_type": "device_code",
            "code": deviceCode,
            "client_id": clientId,
            "client_secret": clientSecret
        ]

        let response = try await postForm(url: tokenURL, parameters: parameters)

        if let accessToken = response["access_token"] as? String {
            return YandexTokenResponse(accessToken: accessToken)
        }

        print("Yandex token poll response:", response)
        throw parseOAuthError(from: response) ?? YandexAuthServiceError.invalidResponse
    }

    func waitForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> YandexTokenResponse {
        let startedAt = Date()
        var pollingInterval = max(interval, 2)

        while Date().timeIntervalSince(startedAt) < TimeInterval(expiresIn) {
            try await Task.sleep(nanoseconds: UInt64(pollingInterval) * 1_000_000_000)

            do {
                return try await pollToken(deviceCode: deviceCode)
            } catch YandexAuthServiceError.authorizationPending {
                continue
            } catch YandexAuthServiceError.slowDown {
                pollingInterval += 5
                continue
            }
        }

        throw YandexAuthServiceError.expiredToken
    }

    private func randomDeviceId() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<10).compactMap { _ in characters.randomElement() })
    }

    private func postForm(url: URL, parameters: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Yapleer/0.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = formBody(parameters)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard response is HTTPURLResponse else {
            throw YandexAuthServiceError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YandexAuthServiceError.invalidResponse
        }

        return json
    }

    private func formBody(_ parameters: [String: String]) -> Data {
        let body = parameters
            .map { key, value in
                "\(urlEncode(key))=\(urlEncode(value))"
            }
            .joined(separator: "&")

        return Data(body.utf8)
    }

    private func urlEncode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func parseOAuthError(from response: [String: Any]) -> YandexAuthServiceError? {
        guard let error = response["error"] as? String else {
            return nil
        }

        switch error {
        case "authorization_pending":
            return .authorizationPending
        case "slow_down":
            return .slowDown
        case "expired_token":
            return .expiredToken
        case "access_denied":
            return .accessDenied
        default:
            let description = response["error_description"] as? String
            return .oauthError(description ?? error)
        }
    }
}
