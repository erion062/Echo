import SwiftUI

@Observable @MainActor
final class Library {
    private(set) var songs: [Song] = []
    /// Songs currently being saved, in the order they were added.
    private(set) var pending: [SearchResult] = []
    private(set) var progress: [String: Double] = [:]
    private(set) var failures: Set<String> = []

    init() {
        Storage.prepare()
        load()
    }

    func contains(_ id: String) -> Bool { songs.contains { $0.id == id } }
    func song(_ id: String) -> Song? { songs.first { $0.id == id } }

    var alphabetical: [Song] {
        songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var recentlyAdded: [Song] {
        Array(songs.sorted { $0.addedAt > $1.addedAt }.prefix(12))
    }

    var totalDuration: TimeInterval { songs.reduce(0) { $0 + $1.duration } }

    func add(_ result: SearchResult) {
        let id = result.id
        guard !contains(id), progress[id] == nil else { return }
        failures.remove(id)
        progress[id] = 0
        pending.append(result)
        Haptics.tap()

        Task {
            do {
                async let artwork: Void = Downloader.downloadArtwork(id: id)
                try await Downloader.downloadAudio(id: id) { [weak self] value in
                    self?.progress[id] = value
                }
                await artwork
                let song = Song(id: id, title: result.title, artist: result.artist, duration: result.duration, addedAt: .now)
                withAnimation(.smooth) { songs.insert(song, at: 0) }
                save()
                Haptics.success()
            } catch {
                failures.insert(id)
                Haptics.error()
            }
            withAnimation(.smooth) {
                progress[id] = nil
                pending.removeAll { $0.id == id }
            }
        }
    }

    func delete(_ song: Song) {
        try? FileManager.default.removeItem(at: Storage.audioURL(song.id))
        try? FileManager.default.removeItem(at: Storage.artworkURL(song.id))
        ArtworkStore.forget(song.id)
        withAnimation(.smooth) { songs.removeAll { $0.id == song.id } }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Storage.libraryFile),
              let decoded = try? JSONDecoder().decode([Song].self, from: data)
        else { return }
        songs = decoded.filter { FileManager.default.fileExists(atPath: Storage.audioURL($0.id).path) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        try? data.write(to: Storage.libraryFile, options: .atomic)
    }
}
