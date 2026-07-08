//
//  YandexAuthView.swift
//  Yapleer
//
//  Created by SITIS on 6/30/26.
//

import SwiftUI
import AppKit

struct YandexAuthView: View {
    @EnvironmentObject private var authState: AuthState

    @State private var authStatus = ""
    @State private var deviceCode: YandexDeviceCodeResponse?
    @State private var isAuthorizing = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Yapleer")
                        .font(.headline)

                    Text(deviceCode == nil ? "Вход" : "Код входа")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Закрыть Yapleer")
            }

            Divider()

            if let deviceCode {
                VStack(spacing: 10) {
                    Text(deviceCode.userCode)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .textSelection(.enabled)

                    Text("Введи код в браузере. Yapleer сам всё сделает.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)

                        Text("Жду подтверждения...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Открыть браузер ещё раз") {
                        NSWorkspace.shared.open(deviceCode.verificationURL)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Button {
                    Task {
                        await startLogin()
                    }
                } label: {
                    HStack {
                        if isAuthorizing {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(isAuthorizing ? "Открываю..." : "Войти")
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isAuthorizing)
                .keyboardShortcut(.defaultAction)
            }

            if !authStatus.isEmpty {
                Text(authStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    @MainActor
    private func startLogin() async {
        isAuthorizing = true
        authStatus = ""
        deviceCode = nil
        defer { isAuthorizing = false }

        do {
            let code = try await YandexAuthService.shared.requestDeviceCode()
            deviceCode = code
            NSWorkspace.shared.open(code.verificationURL)

            let token = try await YandexAuthService.shared.waitForToken(
                deviceCode: code.deviceCode,
                interval: code.interval,
                expiresIn: code.expiresIn
            )

            await authState.saveTokenAndLogin(token.accessToken)

            if case .failed = authState.status {
                authStatus = "Токен получен, но Яндекс Музыка его не приняла"
            }
        } catch YandexAuthServiceError.expiredToken {
            authStatus = "Код истёк. Нажми Войти ещё раз."
            deviceCode = nil
        } catch YandexAuthServiceError.accessDenied {
            authStatus = "Вход отменён"
            deviceCode = nil
        } catch {
            authStatus = "Не удалось войти"
            deviceCode = nil
        }
    }
}

#Preview {
    YandexAuthView()
        .environmentObject(AuthState())
}
