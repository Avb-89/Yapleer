//
//  TrackFileStore.swift
//  Yapleer
//
//  Created by SITIS on 7/8/26.
//

import Foundation
import AppKit

final class TrackFileStore {
    static let shared = TrackFileStore()

    private let cacheFilePrefix = "yapleer-"
    private let mp3Extension = "mp3"

    private init() {}

    func cleanOldCachedTracks() {
        do {
            let cacheFiles = try FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { fileURL in
                fileURL.lastPathComponent.hasPrefix(cacheFilePrefix)
                    && fileURL.pathExtension.lowercased() == mp3Extension
            }

            cacheFiles.forEach(deleteCachedTrack)
        } catch {
            return
        }
    }

    func makeCachedTrackURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(cacheFilePrefix)\(UUID().uuidString)")
            .appendingPathExtension(mp3Extension)
    }

    func deleteCachedTrack(_ fileURL: URL?) {
        guard let fileURL else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            return
        }
    }

    func saveTrackToUserFolder(fileURL: URL, artist: String, title: String) async throws {
        let destinationFolderURL = try await chooseDestinationFolder()
        let destinationFileURL = uniqueDestinationURL(
            in: destinationFolderURL,
            artist: artist,
            title: title
        )

        try FileManager.default.copyItem(at: fileURL, to: destinationFileURL)
    }

    private func chooseDestinationFolder() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)

                let panel = NSOpenPanel()
                panel.title = "Куда сохранить трек"
                panel.prompt = "Сохранить"
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.canCreateDirectories = true

                let response = panel.runModal()

                guard response == .OK, let folderURL = panel.url else {
                    continuation.resume(throwing: CocoaError(.userCancelled))
                    return
                }

                continuation.resume(returning: folderURL)
            }
        }
    }

    private func uniqueDestinationURL(in folderURL: URL, artist: String, title: String) -> URL {
        let baseFileName = makeFileName(artist: artist, title: title)
        var candidateURL = folderURL
            .appendingPathComponent(baseFileName)
            .appendingPathExtension(mp3Extension)

        var duplicateIndex = 2
        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = folderURL
                .appendingPathComponent("\(baseFileName)-\(duplicateIndex)")
                .appendingPathExtension(mp3Extension)
            duplicateIndex += 1
        }

        return candidateURL
    }

    private func makeFileName(artist: String, title: String) -> String {
        let sanitizedArtist = sanitizeFileNamePart(artist)
        let sanitizedTitle = sanitizeFileNamePart(title)

        if sanitizedArtist.isEmpty && sanitizedTitle.isEmpty {
            return "YapleerTrack"
        }

        if sanitizedArtist.isEmpty {
            return sanitizedTitle
        }

        if sanitizedTitle.isEmpty {
            return sanitizedArtist
        }

        return "\(sanitizedArtist)-\(sanitizedTitle)"
    }

    private func sanitizeFileNamePart(_ value: String) -> String {
        let forbiddenCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = value
            .components(separatedBy: forbiddenCharacters)
            .joined(separator: "-")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
    }
}
