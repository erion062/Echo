import UIKit
import YouTubeKit

enum DownloadError: LocalizedError {
    case noAudioStream, badResponse

    var errorDescription: String? {
        switch self {
        case .noAudioStream: "This video has no downloadable audio."
        case .badResponse: "YouTube refused the download. Try again."
        }
    }
}

enum Downloader {
    private static let chunkSize = 1_000_000

    /// Finds the best m4a audio stream and saves it to `Storage.audioURL(id)`.
    static func downloadAudio(id: String, progress: @escaping @MainActor (Double) -> Void) async throws {
        let streams = try await YouTube(videoID: id, methods: [.local, .remote]).streams
        guard let stream = streams.filterAudioOnly().filter({ $0.fileExtension == .m4a }).highestAudioBitrateStream()
        else { throw DownloadError.noAudioStream }

        let temp = FileManager.default.temporaryDirectory.appending(path: "\(id)-\(UUID().uuidString).part")
        FileManager.default.createFile(atPath: temp.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: temp) }
        let handle = try FileHandle(forWritingTo: temp)

        // YouTube throttles large single requests, so fetch the file in ranged chunks.
        var offset = 0
        var total: Int?
        repeat {
            try Task.checkCancellation()
            var request = URLRequest(url: stream.url)
            request.setValue("bytes=\(offset)-\(offset + chunkSize - 1)", forHTTPHeaderField: "Range")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
                try? handle.close()
                throw DownloadError.badResponse
            }
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
