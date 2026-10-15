import UIKit
import YouTubeKit

enum DownloadError: LocalizedError {
    case noAudioStream, badResponse
    case unavailable(status: String, reason: String?)

    var errorDescription: String? {
        switch self {
        case .noAudioStream:
            return "This video has no downloadable audio. Try another version."
        case .badResponse:
            return "YouTube interrupted the download. Try again."
        case .unavailable(let status, let reason):
            if status == "LOGIN_REQUIRED" { return "YouTube is limiting requests right now. Try again in a minute." }
            if status == "UNPLAYABLE" || status == "ERROR" {
                return "The label blocks downloads of this upload. Try a lyrics or audio version from another channel."
            }
            return reason ?? "YouTube won't share this video."
        }
    }
}

enum Downloader {
    private static let chunkSize = 1_000_000

    /// Finds the best m4a audio stream and saves it to `Storage.audioURL(id)`.
    static func downloadAudio(id: String, progress: @escaping @MainActor (Double) -> Void) async throws {
        do {
            let source = try await YouTubeAudio.source(for: id)
            try await fetch(source, id: id, progress: progress)
        } catch let primary {
            if primary is CancellationError { throw primary }
            // Fall back to YouTubeKit (local extraction, then its remote yt-dlp server).
            do {
                let streams = try await YouTube(videoID: id, methods: [.local, .remote]).streams
                guard let stream = streams.filterAudioOnly().filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream()
                else { throw DownloadError.noAudioStream }
                try await fetch(YouTubeAudio.Source(url: stream.url, length: nil, userAgent: nil), id: id, progress: progress)
            } catch {
                throw primary
            }
        }
    }

    private static func fetch(_ source: YouTubeAudio.Source, id: String, progress: @escaping @MainActor (Double) -> Void) async throws {
        let temp = FileManager.default.temporaryDirectory.appending(path: "\(id)-\(UUID().uuidString).part")
        FileManager.default.createFile(atPath: temp.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: temp) }
        let handle = try FileHandle(forWritingTo: temp)
        defer { try? handle.close() }

        // YouTube throttles large single requests, so fetch the file in ranged chunks.
        var offset = 0
        var total = source.length
        repeat {
            try Task.checkCancellation()
            var request = URLRequest(url: source.url)
            request.setValue("bytes=\(offset)-\(offset + chunkSize - 1)", forHTTPHeaderField: "Range")
            if let userAgent = source.userAgent { request.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty
            else { throw DownloadError.badResponse }
            try handle.write(contentsOf: data)
            offset += data.count
            if http.statusCode == 200 {
                total = offset
            } else if total == nil,
                      let range = http.value(forHTTPHeaderField: "Content-Range"),
                      let size = range.split(separator: "/").last.flatMap({ Int($0) }) {
                total = size
            }
            await progress(min(Double(offset) / Double(max(total ?? offset, 1)), 1))
        } while offset < (total ?? 0)
        try handle.close()

        let destination = Storage.audioURL(id)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    /// Saves a square crop of the video thumbnail as the song's artwork.
    static func downloadArtwork(id: String) async {
        for name in ["maxresdefault", "hqdefault"] {
            guard let url = URL(string: "https://i.ytimg.com/vi/\(id)/\(name).jpg"),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let cgImage = UIImage(data: data)?.cgImage
            else { continue }
            let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
            // hqdefault is 4:3 with black bars around a 16:9 frame.
            let side = abs(width / height - 4.0 / 3.0) < 0.01 ? height * 0.75 : min(width, height)
            let rect = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side).integral
            guard let cropped = cgImage.cropping(to: rect),
                  let jpeg = UIImage(cgImage: cropped).jpegData(compressionQuality: 0.9)
            else { continue }
            try? jpeg.write(to: Storage.artworkURL(id), options: .atomic)
            return
        }
    }
}
