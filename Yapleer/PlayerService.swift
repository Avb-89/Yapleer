//
//  PlayerService.swift
//  Yapleer
//
//  Created by SITIS on 6/25/26.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class PlayerService: ObservableObject {
    @Published var isPlaying = false
    @Published var trackTitle = "Тестовый трек"
    @Published var trackArtist = "Yapleer"

    private var player: AVPlayer?
    private var loadedYandexTrack = false
    private var tempAudioURL: URL?
    private var endObserver: NSObjectProtocol?

    init() {
        setupTestTrack()
        NowPlayingService.shared.configure()
        RemoteCommandService.shared.configure(playerService: self)
        updateNowPlaying(isPlaying: false)
    }

    private func setupTestTrack() {
        guard let url = URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3") else {
            return
        }

        player = AVPlayer(url: url)
        observeCurrentTrackEnd()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func togglePlayPause(yandexToken: String) async {
        if isPlaying {
            pause()
            return
        }

        if !yandexToken.isEmpty && !loadedYandexTrack {
            let loaded = await loadNextYandexTrack(token: yandexToken)
            guard loaded else {
                return
            }
        }

        play()
    }

    func play() {
        guard let player else {
            return
        }

        player.play()
        isPlaying = true
        updateNowPlaying(isPlaying: true)
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying(isPlaying: false)
    }

    func next() {
        restartCurrentTrack()
    }

    func next(yandexToken: String) async {
        if yandexToken.isEmpty {
            next()
            return
        }

        let loaded = await loadNextYandexTrack(token: yandexToken)
        guard loaded else {
            return
        }

        play()
    }

    func previous() {
        restartCurrentTrack()
    }

    func previous(yandexToken: String) async {
        if yandexToken.isEmpty {
            previous()
            return
        }

        let loaded = await loadNextYandexTrack(token: yandexToken)
        guard loaded else {
            return
        }

        play()
    }

    private func observeCurrentTrackEnd() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        guard let currentItem = player?.currentItem else {
            return
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.playNextAfterCurrentTrackEnded()
            }
        }
    }

    private func playNextAfterCurrentTrackEnded() async {
        let token = UserDefaults.standard.string(forKey: "yandexMusicToken") ?? ""

        if token.isEmpty {
            restartCurrentTrack()
            return
        }

        await next(yandexToken: token)
    }

    private func restartCurrentTrack() {
        player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
        }
    }

    private func loadNextYandexTrack(token: String) async -> Bool {
        do {
            let track = try await YandexMusicClient(token: token).fetchMyWaveTrack()
            let localURL = try await downloadAudioFile(from: track.directURL)
            player?.pause()
            player = AVPlayer(url: localURL)
            observeCurrentTrackEnd()
            trackTitle = track.title
            trackArtist = track.artist
            loadedYandexTrack = true
            updateNowPlaying(isPlaying: false)
            return true
        } catch {
            print("Yandex Wave track load failed:", error)
            return false
        }
    }

    private func downloadAudioFile(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Yapleer/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            print("Yandex mp3 download URL:", url.absoluteString)
            print("Yandex mp3 download status code:", statusCode)
            print("Yandex mp3 download response:", body)
            throw URLError(.badServerResponse)
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("yapleer-\(UUID().uuidString)")
            .appendingPathExtension("mp3")

        try data.write(to: fileURL, options: .atomic)
        print("Yandex mp3 downloaded bytes:", data.count)
        print("Yandex mp3 local file:", fileURL.path)
        tempAudioURL = fileURL
        return fileURL
    }

    private func updateNowPlaying(isPlaying: Bool) {
        NowPlayingService.shared.update(
            title: trackTitle,
            artist: trackArtist,
            isPlaying: isPlaying
        )
    }
}
