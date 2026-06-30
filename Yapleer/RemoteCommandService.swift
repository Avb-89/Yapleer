//
//  RemoteCommandService.swift
//  Yapleer
//
//  Created by SITIS on 6/25/26.
//

import Foundation
import MediaPlayer

final class RemoteCommandService {
    static let shared = RemoteCommandService()

    private init() {}

    private func yandexToken() -> String {
        UserDefaults.standard.string(forKey: "yandexMusicToken") ?? ""
    }

    func configure(playerService: PlayerService) {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in
                await playerService.togglePlayPause(yandexToken: self.yandexToken())
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in
                playerService.pause()
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                await playerService.togglePlayPause(yandexToken: self.yandexToken())
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            Task { @MainActor in
                await playerService.next(yandexToken: self.yandexToken())
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            Task { @MainActor in
                await playerService.previous(yandexToken: self.yandexToken())
            }
            return .success
        }
    }
}
