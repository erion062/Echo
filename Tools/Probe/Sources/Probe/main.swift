import Foundation
import YouTubeKit

// Diagnoses the Echo download path: stream extraction + ranged download.
let ids = CommandLine.arguments.dropFirst().isEmpty ? ["4NRXx6U8ABQ", "fHI8X4OXluQ"] : Array(CommandLine.arguments.dropFirst())

for id in ids {
    for methods in [[YouTube.ExtractionMethod.local], [.remote]] {
        print("=== \(id) methods=\(methods)")
        do {
            let streams = try await YouTube(videoID: id, methods: methods).streams
            print("streams: \(streams.count), audioOnly: \(streams.filterAudioOnly().count)")
            for s in streams.filterAudioOnly() {
                print("  mime=\(s.mimeType) ext=\(s.fileExtension) bitrate=\(s.bitrate ?? -1) host=\(s.url.host ?? "")")
            }
            guard let stream = streams.filterAudioOnly().filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream() else {
                print("NO m4a stream")
                continue
            }
            let c = URLComponents(url: stream.url, resolvingAgainstBaseURL: false)
            print("chosen mime=\(stream.mimeType) c=\(c?.queryItems?.first { $0.name == "c" }?.value ?? "-") clen=\(c?.queryItems?.first { $0.name == "clen" }?.value ?? "-")")
            let variants: [(String, [String: String])] = [
                ("range-header", ["Range": "bytes=0-999999"]),
                ("range-header+safariUA", ["Range": "bytes=0-999999", "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"]),
                ("range-query", [:]),
                ("no-range", [:]),
            ]
            for (name, headers) in variants {
                var url = stream.url
                if name == "range-query" {
                    var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                    comps.queryItems = (comps.queryItems ?? []) + [URLQueryItem(name: "range", value: "0-999999")]
                    url = comps.url!
                }
                var request = URLRequest(url: url)
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                if name == "no-range" { request.httpMethod = "HEAD" }
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    let http = response as! HTTPURLResponse
                    print("  [\(name)] status=\(http.statusCode) bytes=\(data.count) content-range=\(http.value(forHTTPHeaderField: "Content-Range") ?? "-") len=\(http.value(forHTTPHeaderField: "Content-Length") ?? "-")")
                } catch {
                    print("  [\(name)] error: \(error)")
                }
            }
        } catch {
            print("EXTRACTION ERROR: \(error)")
        }
    }
}
