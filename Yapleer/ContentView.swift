//
//  ContentView.swift
//  Yapleer
//
//  Created by SITIS on 6/25/26.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var player: PlayerService
    @EnvironmentObject private var authState: AuthState
    @State private var manualToken = ""
    @State private var yandexStatus = "Яндекс подключен"
    @State private var isCheckingYandex = false
    @State private var showYandexSettings = false

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: player.isPlaying ? "flame.fill" : "flame")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.trackArtist)
                        .font(.headline)
                        .lineLimit(1)

                    Text(player.trackTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(.snappy) {
                        showYandexSettings.toggle()
                    }
                } label: {
                    Image(systemName: "door.left.hand.open")
                        .foregroundStyle(showYandexSettings ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .help("Настройки Яндекса")

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

            if showYandexSettings {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("OAuth-токен Яндекс Музыки", text: $manualToken)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button {
                            Task {
                                await saveManualToken()
                            }
                        } label: {
                            Text(isCheckingYandex ? "Проверяем..." : "Сохранить токен")
                        }
                        .disabled(manualToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCheckingYandex)

                        Spacer()

                        Text(yandexStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 24) {
                Button {
                    Task {
                        await player.previous(yandexToken: authState.yandexToken)
                    }
                } label: {
                    Image(systemName: "backward.fill")
                }

                Button {
                    Task {
                        await player.togglePlayPause(yandexToken: authState.yandexToken)
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await player.next(yandexToken: authState.yandexToken)
                    }
                } label: {
                    Image(systemName: "forward.fill")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 320)
    }

    @MainActor
    private func saveManualToken() async {
        isCheckingYandex = true
        defer { isCheckingYandex = false }

        await authState.saveTokenAndLogin(manualToken)

        switch authState.status {
        case .authenticated:
            yandexStatus = "OK: \(authState.accountTitle)"
            manualToken = ""
            withAnimation(.snappy) {
                showYandexSettings = false
            }
        case .failed(let message):
            yandexStatus = message
        default:
            yandexStatus = "Ошибка подключения"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerService())
        .environmentObject(AuthState())
}
