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
    @AppStorage("yandexMusicToken") private var yandexMusicToken = ""
    @State private var yandexStatus = "Яндекс не подключен"
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

            if showYandexSettings || yandexMusicToken.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("OAuth-токен Яндекс Музыки", text: $yandexMusicToken)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button {
                            Task {
                                await checkYandexConnection()
                            }
                        } label: {
                            Text(isCheckingYandex ? "Проверяем..." : "Проверить Яндекс")
                        }
                        .disabled(yandexMusicToken.isEmpty || isCheckingYandex)

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
                        await player.previous(yandexToken: yandexMusicToken)
                    }
                } label: {
                    Image(systemName: "backward.fill")
                }

                Button {
                    Task {
                        await player.togglePlayPause(yandexToken: yandexMusicToken)
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await player.next(yandexToken: yandexMusicToken)
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
    private func checkYandexConnection() async {
        isCheckingYandex = true
        defer { isCheckingYandex = false }

        do {
            let status = try await YandexMusicClient(token: yandexMusicToken).fetchAccountStatus()
            yandexStatus = "OK: \(status.displayName ?? status.login ?? "аккаунт найден")"
        } catch {
            yandexStatus = "Ошибка подключения"
            print("Yandex Music auth check failed:", error)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerService())
}
