//
//  RootView.swift
//  Yapleer
//
//  Created by SITIS on 6/30/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authState: AuthState

    var body: some View {
        Group {
            switch authState.status {
            case .checking:
                checkingView

            case .unauthenticated:
                YandexAuthView()

            case .authenticated:
                ContentView()

            case .failed(let message):
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    Text("Не удалось войти")
                        .font(.headline)

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Попробовать снова") {
                        Task {
                            await authState.loadSavedToken()
                        }
                    }

                    Button("Войти заново") {
                        authState.logout()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(width: 320)
            }
        }
    }

    private var checkingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text("Проверяем вход в Яндекс Музыку...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthState())
        .environmentObject(PlayerService())
}
