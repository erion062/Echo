import Foundation

/// Searches YouTube through the public InnerTube endpoint the website itself uses (no API key needed).
enum YouTubeSearch {
    private static let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/search?prettyPrint=false")!
    private static let skippedRenderers: Set<String> = ["shelfRenderer", "reelShelfRenderer", "horizontalCardListRenderer"]

    static func search(_ query: String) async throws -> [SearchResult] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "context": ["client": ["clientName": "WEB", "clientVersion": "2.20250101.00.00", "hl": "en", "gl": "US"]],
            "query": query,
            "params": "EgIQAQ%3D%3D", // videos only
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        var renderers: [[String: Any]] = []
        collect(try JSONSerialization.jsonObject(with: data), into: &renderers)
        var seen = Set<String>()
        return renderers.compactMap(parse).filter { seen.insert($0.id).inserted }
    }

    private static func collect(_ node: Any, into out: inout [[String: Any]]) {
        if let array = node as? [Any] {
            array.forEach { collect($0, into: &out) }
        } else if let dict = node as? [String: Any] {
            if let video = dict["videoRenderer"] as? [String: Any] {
                out.append(video)
                return
            }
            for (key, value) in dict where !skippedRenderers.contains(key) {
                collect(value, into: &out)
            }
        }
    }

    private static func parse(_ renderer: [String: Any]) -> SearchResult? {
        guard let id = renderer["videoId"] as? String,
              let rawTitle = text(renderer["title"]),
              let length = text(renderer["lengthText"]) // live streams have no length
        else { return nil }
        let channel = text(renderer["ownerText"]) ?? text(renderer["longBylineText"]) ?? ""
        let (title, artist) = TitleCleaner.split(title: rawTitle, channel: channel)
        return SearchResult(id: id, title: title, artist: artist, duration: parseDuration(length))
    }

    private static func text(_ value: Any?) -> String? {
        guard let dict = value as? [String: Any] else { return nil }
        if let simple = dict["simpleText"] as? String { return simple }
        let runs = (dict["runs"] as? [[String: Any]])?.compactMap { $0["text"] as? String } ?? []
        return runs.isEmpty ? nil : runs.joined()
    }

    private static func parseDuration(_ text: String) -> TimeInterval {
        text.split(separator: ":").reduce(0) { $0 * 60 + (Double($1) ?? 0) }
    }
}

/// Turns "Artist - Song (Official Music Video)" into a clean title + artist.
enum TitleCleaner {
    private static let noise = ["official", "video", "audio", "lyric", "visuali", "music video", " hd", "hd ", "4k", " mv", "m/v"]
    private static let brackets = try! NSRegularExpression(pattern: #"\s*[\(\[【]([^\)\]】]*)[\)\]】]"#)

    static func split(title raw: String, channel: String) -> (title: String, artist: String) {
        var title = raw
        let source = raw as NSString
        for match in brackets.matches(in: raw, range: NSRange(location: 0, length: source.length)).reversed() {
            let inner = " " + source.substring(with: match.range(at: 1)).lowercased() + " "
            if noise.contains(where: inner.contains) || inner.trimmingCharacters(in: .whitespaces) == "hd" {
                title = (title as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        if let bar = title.range(of: " | ") { title = String(title[..<bar.lowerBound]) }

        var artist = channel
            .replacingOccurrences(of: " - Topic", with: "")
            .replacingOccurrences(of: "VEVO", with: "")
        for separator in [" - ", " – ", " — "] {
            if let range = title.range(of: separator) {
                artist = String(title[..<range.lowerBound])
                title = String(title[range.upperBound...])
                break
            }
        }
        let quotes = CharacterSet(charactersIn: "\"“”'")
        title = title.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: quotes).trimmingCharacters(in: .whitespaces)
        artist = artist.trimmingCharacters(in: .whitespaces)
        return (title.isEmpty ? raw : title, artist.isEmpty ? channel : artist)
    }
}
