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
    @State private var isSavingTrack = false

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
                    authState.logout()
                } label: {
                    Image(systemName: "door.left.hand.open")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Войти заново")

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

                Button {
                    Task {
                        await saveCurrentTrack()
                    }
                } label: {
                    Image(systemName: isSavingTrack ? "checkmark" : "square.and.arrow.down")
                        .foregroundStyle(.secondary)
                }
                .help("Сохранить текущий трек")
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 320)
    }

    @MainActor
    private func saveCurrentTrack() async {
        isSavingTrack = true
        defer {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 800_000_000)
                isSavingTrack = false
            }
        }

        await player.saveCurrentTrack()
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerService())
        .environmentObject(AuthState())
}
