//
//  YandexMusicClient.swift
//  Yapleer
//
//  Created by SITIS on 6/25/26.
//

import Foundation
import CryptoKit

struct YandexAccountStatus {
    let login: String?
    let displayName: String?
}

struct YandexTrackInfo {
    let title: String
    let artist: String
    let directURL: URL
    let token: String
}

final class YandexMusicClient {
    private let token: String
    private static var waveQueue: [[String: Any]] = []
    private static var waveQueueIndex = 0

    init(token: String) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func fetchAccountStatus() async throws -> YandexAccountStatus {
        let url = URL(string: "https://api.music.yandex.net/account/status")!
        var request = authorizedRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data, operation: "Yandex account status")

        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = jsonObject?["result"] as? [String: Any]
        let account = result?["account"] as? [String: Any]

        return YandexAccountStatus(
            login: account?["login"] as? String,
            displayName: account?["displayName"] as? String
        )
    }

    func fetchMyWaveTrack() async throws -> YandexTrackInfo {
        if Self.waveQueue.isEmpty || Self.waveQueueIndex >= Self.waveQueue.count {
            Self.waveQueue = try await fetchMyWaveSequence()
            Self.waveQueueIndex = 0
        }

        guard Self.waveQueueIndex < Self.waveQueue.count else {
            throw URLError(.cannotParseResponse)
        }

        let sequenceItem = Self.waveQueue[Self.waveQueueIndex]
        Self.waveQueueIndex += 1

        guard let trackJSON = sequenceItem["track"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        guard let trackId = stringify(trackJSON["id"]), !trackId.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        let title = trackJSON["title"] as? String ?? "Без названия"
        let artistsJSON = trackJSON["artists"] as? [[String: Any]] ?? []
        let artist = artistsJSON.compactMap { $0["name"] as? String }.joined(separator: ", ")

        print("Yandex selected queue index:", Self.waveQueueIndex - 1)
        print("Yandex selected trackId:", trackId)
        print("Yandex selected title:", title)

        let directURL = try await fetchDirectURL(trackId: trackId)

        return YandexTrackInfo(
            title: title,
            artist: artist.isEmpty ? "Yandex Music" : artist,
            directURL: directURL,
            token: token
        )
    }

    private func fetchMyWaveSequence() async throws -> [[String: Any]] {
        let stationURL = URL(string: "https://api.music.yandex.net/rotor/station/user:onyourwave/tracks?settings2=true")!
        var stationRequest = authorizedRequest(url: stationURL)
        stationRequest.httpMethod = "GET"

        let (stationData, stationResponse) = try await URLSession.shared.data(for: stationRequest)
        try validateHTTPResponse(stationResponse, data: stationData, operation: "Yandex Wave tracks")

        let stationJSON = try JSONSerialization.jsonObject(with: stationData) as? [String: Any]
        let result = stationJSON?["result"] as? [String: Any]
        let sequence = result?["sequence"] as? [[String: Any]] ?? []

        print("Yandex Wave sequence count:", sequence.count)
        for (index, item) in sequence.enumerated() {
            let track = item["track"] as? [String: Any]
            let trackId = stringify(track?["id"]) ?? "nil"
            let title = track?["title"] as? String ?? "Без названия"
            print("Yandex Wave queue item #\(index): \(trackId) — \(title)")
        }

        guard !sequence.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        return sequence
    }

    private func fetchDirectURL(trackId: String) async throws -> URL {
        let downloadInfoURL = URL(string: "https://api.music.yandex.net/tracks/\(trackId)/download-info")!
        var downloadInfoRequest = authorizedRequest(url: downloadInfoURL)
        downloadInfoRequest.httpMethod = "GET"

        let (downloadInfoData, downloadInfoResponse) = try await URLSession.shared.data(for: downloadInfoRequest)
        print("Yandex download-info trackId:", trackId)
        try validateHTTPResponse(downloadInfoResponse, data: downloadInfoData, operation: "Yandex download-info")

        let downloadInfoObject = try JSONSerialization.jsonObject(with: downloadInfoData)
        let downloadInfoList: [[String: Any]]

        if let list = downloadInfoObject as? [[String: Any]] {
            downloadInfoList = list
        } else if let object = downloadInfoObject as? [String: Any],
                  let result = object["result"] as? [[String: Any]] {
            downloadInfoList = result
        } else {
            let body = String(data: downloadInfoData, encoding: .utf8) ?? ""
            print("Yandex download-info unexpected JSON:", body)
            throw URLError(.cannotParseResponse)
        }

        print("Yandex download-info variants count:", downloadInfoList.count)
        for item in downloadInfoList {
            let codec = item["codec"] as? String ?? "nil"
            let bitrate = item["bitrateInKbps"] as? Int ?? item["bitrate_in_kbps"] as? Int ?? 0
            let gain = item["gain"] as? Bool ?? false
            let preview = item["preview"] as? Bool ?? false
            let infoURLString = item["downloadInfoUrl"] as? String ?? item["download_info_url"] as? String ?? "nil"
            print("Yandex download-info variant codec=\(codec) bitrate=\(bitrate) gain=\(gain) preview=\(preview) url=\(infoURLString)")
        }

        let best = downloadInfoList
            .filter { ($0["codec"] as? String) == "mp3" }
            .max { left, right in
                let leftBitrate = left["bitrateInKbps"] as? Int ?? left["bitrate_in_kbps"] as? Int ?? 0
                let rightBitrate = right["bitrateInKbps"] as? Int ?? right["bitrate_in_kbps"] as? Int ?? 0
                return leftBitrate < rightBitrate
            } ?? downloadInfoList.first

        guard let best,
              let infoURLString = best["downloadInfoUrl"] as? String ?? best["download_info_url"] as? String,
              let infoURL = URL(string: infoURLString) else {
            throw URLError(.cannotParseResponse)
        }

        var infoRequest = URLRequest(url: infoURL)
        infoRequest.httpMethod = "GET"
        infoRequest.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        infoRequest.setValue("Yapleer/0.1", forHTTPHeaderField: "User-Agent")

        let (xmlData, xmlResponse) = try await URLSession.shared.data(for: infoRequest)
        try validateHTTPResponse(xmlResponse, data: xmlData, operation: "Yandex direct-link xml")

        let xmlRaw = String(data: xmlData, encoding: .utf8) ?? ""
        print("Yandex direct-link xml:", xmlRaw)

        let xml = try YandexDownloadXML.parse(data: xmlData)
        print("Yandex parsed host:", xml.host)
        print("Yandex parsed path:", xml.path)
        print("Yandex parsed ts:", xml.ts)
        print("Yandex parsed s:", xml.s)

        let sign = md5Hex("XGRlBW9FXlekgbPrRHuSiA" + String(xml.path.dropFirst()) + xml.s)
        print("Yandex calculated sign:", sign)

        let normalizedPath = xml.path.hasPrefix("/") ? xml.path : "/\(xml.path)"
        let directURLString = "https://\(xml.host)/get-mp3/\(sign)/\(xml.ts)\(normalizedPath)"
        print("Yandex direct URL:", directURLString)

        guard let directURL = URL(string: directURLString) else {
            throw URLError(.badURL)
        }

        return directURL
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Yapleer/0.1", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data, operation: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("\(operation) status code:", httpResponse.statusCode)
            print("\(operation) response:", body)
            throw URLError(.badServerResponse)
        }
    }

    private func stringify(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string
        case let int as Int:
            return String(int)
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    private func md5Hex(_ value: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

struct YandexDownloadXML {
    let host: String
    let path: String
    let ts: String
    let s: String

    static func parse(data: Data) throws -> YandexDownloadXML {
        guard let xml = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        guard let host = extractTag("host", from: xml),
              let path = extractTag("path", from: xml),
              let ts = extractTag("ts", from: xml),
              let s = extractTag("s", from: xml) else {
            throw URLError(.cannotParseResponse)
        }

        return YandexDownloadXML(host: host, path: path, ts: ts, s: s)
    }

    private static func extractTag(_ tag: String, from xml: String) -> String? {
        guard let startRange = xml.range(of: "<\(tag)>") else {
            return nil
        }

        guard let endRange = xml.range(of: "</\(tag)>", range: startRange.upperBound..<xml.endIndex) else {
            return nil
        }

        let rawValue = String(xml[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return rawValue
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
