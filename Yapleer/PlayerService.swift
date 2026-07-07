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

    private struct CachedTrack {
        let title: String
        let artist: String
        let fileURL: URL
    }

    private var player: AVPlayer?
    private var loadedYandexTrack = false
    private var trackCache: [CachedTrack] = []
    private var currentCacheIndex: Int?
    private var endObserver: NSObjectProtocol?

    private let maxCachedTracks = 6
    private let previousRestartThresholdSeconds: Double = 5

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        let cachedFileURLs = trackCache.map(\.fileURL)
        cachedFileURLs.forEach { fileURL in
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch CocoaError.fileNoSuchFile {
                return
            } catch {
                print("Yapleer temp mp3 delete failed:", error)
            }
        }
    }

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
        if shouldRestartCurrentTrackOnPreviousPress() {
            restartCurrentTrack()
            return
        }

        guard playCachedTrack(offset: -1) else {
            restartCurrentTrack()
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
        let token: String

        do {
            token = try KeychainService.shared.readYandexToken() ?? ""
        } catch {
            print("PlayerService read token failed:", error)
            restartCurrentTrack()
            return
        }

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
            let cachedTrack = CachedTrack(
                title: track.title,
                artist: track.artist,
                fileURL: localURL
            )

            appendCachedTrack(cachedTrack)
            playCachedTrack(at: trackCache.count - 1)
            return true
        } catch {
            print("Yandex Wave track load failed:", error)
            return false
        }
    }

    private func appendCachedTrack(_ cachedTrack: CachedTrack) {
        if let currentCacheIndex, currentCacheIndex < trackCache.count - 1 {
            let removedForwardTracks = trackCache[(currentCacheIndex + 1)...]
            removedForwardTracks.forEach { deleteTempAudioFile($0.fileURL) }
            trackCache.removeSubrange((currentCacheIndex + 1)..<trackCache.count)
        }

        trackCache.append(cachedTrack)

        while trackCache.count > maxCachedTracks {
            let removedTrack = trackCache.removeFirst()
            deleteTempAudioFile(removedTrack.fileURL)

            if let currentCacheIndex {
                self.currentCacheIndex = max(currentCacheIndex - 1, 0)
            }
        }
    }

    @discardableResult
    private func playCachedTrack(offset: Int) -> Bool {
        guard let currentCacheIndex else {
            return false
        }

        return playCachedTrack(at: currentCacheIndex + offset)
    }

    @discardableResult
    private func playCachedTrack(at index: Int) -> Bool {
        guard trackCache.indices.contains(index) else {
            return false
        }

        let cachedTrack = trackCache[index]
        player?.pause()
        player = AVPlayer(url: cachedTrack.fileURL)
        currentCacheIndex = index
        trackTitle = cachedTrack.title
        trackArtist = cachedTrack.artist
        loadedYandexTrack = true
        observeCurrentTrackEnd()
        updateNowPlaying(isPlaying: false)
        return true
    }

    private func shouldRestartCurrentTrackOnPreviousPress() -> Bool {
        guard let player else {
            return false
        }

        return player.currentTime().seconds > previousRestartThresholdSeconds
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
        return fileURL
    }

    private func deleteTempAudioFile(_ fileURL: URL?) {
        guard let fileURL else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            print("Yapleer temp mp3 delete failed:", error)
        }
    }

    private func deleteAllCachedTracks() {
        trackCache.forEach { deleteTempAudioFile($0.fileURL) }
        trackCache.removeAll()
        currentCacheIndex = nil
    }

    private func updateNowPlaying(isPlaying: Bool) {
        NowPlayingService.shared.update(
            title: trackTitle,
            artist: trackArtist,
            isPlaying: isPlaying
        )
    }
}
