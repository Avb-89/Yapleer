//
//  NowPlayingService.swift
//  Yapleer
//
//  Created by SITIS on 6/25/26.
//

import Foundation
import MediaPlayer

final class NowPlayingService {
    static let shared = NowPlayingService()

    private init() {}

    func configure() {
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }

    func update(title: String, artist: String, isPlaying: Bool) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
    }
}
