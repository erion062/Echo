import Foundation

/// A song saved in the library. `id` is the YouTube video ID.
struct Song: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var artist: String
    var duration: TimeInterval
    var addedAt: Date
}

/// A song found on YouTube that has not necessarily been saved yet.
struct SearchResult: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval

    var thumbnailURL: URL? { URL(string: "https://i.ytimg.com/vi/\(id)/mqdefault.jpg") }
}

enum Storage {
    static let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let music = documents.appending(path: "Music", directoryHint: .isDirectory)
    static let artwork = documents.appending(path: "Artwork", directoryHint: .isDirectory)
    static let libraryFile = documents.appending(path: "library.json")

    static func audioURL(_ id: String) -> URL { music.appending(path: "\(id).m4a") }
    static func artworkURL(_ id: String) -> URL { artwork.appending(path: "\(id).jpg") }

    static func prepare() {
        for directory in [music, artwork] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    static var bytesUsed: Int64 {
        [music, artwork].reduce(0) { total, directory in
            let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            return total + files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        }
    }
}
