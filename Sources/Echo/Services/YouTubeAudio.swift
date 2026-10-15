import Foundation

/// Resolves a direct m4a audio URL through YouTube's player API, posing as the visionOS app.
/// That client returns plain (unciphered) URLs that download fully when paired with a visitor ID.
enum YouTubeAudio {
    struct Source {
        let url: URL
        let length: Int?
        let userAgent: String?
    }

    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    private static let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false")!

    static func source(for id: String) async throws -> Source {
        let visitor = await VisitorData.shared.value()
        var client: [String: Any] = [
            "clientName": "VISIONOS", "clientVersion": "1.02",
            "deviceMake": "Apple", "deviceModel": "RealityDevice17,1",
            "osName": "visionOS", "osVersion": "26.5.23O471",
            "hl": "en", "gl": "US",
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let visitor {
            client["visitorData"] = visitor
            request.setValue(visitor, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        let body: [String: Any] = ["context": ["client": client], "videoId": id, "contentCheckOk": true, "racyCheckOk": true]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DownloadError.badResponse }

        let playability = json["playabilityStatus"] as? [String: Any]
        let status = playability?["status"] as? String ?? ""
        guard status == "OK" else {
            if status == "LOGIN_REQUIRED" { await VisitorData.shared.reset() }
            throw DownloadError.unavailable(status: status, reason: playability?["reason"] as? String)
        }

        let formats = (json["streamingData"] as? [String: Any])?["adaptiveFormats"] as? [[String: Any]] ?? []
        let audio = formats
            .filter { ($0["mimeType"] as? String)?.hasPrefix("audio/mp4") == true && $0["url"] != nil }
            .sorted { a, b in
                let drcA = a["isDrc"] as? Bool ?? false, drcB = b["isDrc"] as? Bool ?? false
                if drcA != drcB { return !drcA }
                return (a["bitrate"] as? Int ?? 0) > (b["bitrate"] as? Int ?? 0)
            }
        guard let best = audio.first, let url = (best["url"] as? String).flatMap(URL.init(string:))
        else { throw DownloadError.noAudioStream }
        return Source(url: url, length: (best["contentLength"] as? String).flatMap { Int($0) }, userAgent: userAgent)
    }
}

/// YouTube's anonymous visitor ID. Requests without one are often bot-checked.
actor VisitorData {
    static let shared = VisitorData()
    private var cached: String?

    func set(_ value: String?) {
        if let value, !value.isEmpty { cached = value }
    }

    func reset() { cached = nil }

    func value() async -> String? {
        if let cached { return cached }
        _ = try? await YouTubeSearch.search("music")
        return cached
    }
}
