import AVFoundation
import MediaPlayer
import SwiftUI

@Observable @MainActor
final class Player {
    enum RepeatMode { case off, all, one }

    private(set) var queue: [Song] = []
    private(set) var index = 0
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var shuffle = false
    var repeatMode: RepeatMode = .off
    var showsNowPlaying = false

    @ObservationIgnored private let player = AVPlayer()
    @ObservationIgnored private var originalQueue: [Song] = []
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var isSeeking = false

    var current: Song? { queue.indices.contains(index) ? queue[index] : nil }
    var progress: Double { duration > 0 ? min(currentTime / duration, 1) : 0 }

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, !self.isSeeking, time.seconds.isFinite else { return }
                self.currentTime = time.seconds
            }
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.itemEnded() }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            MainActor.assumeIsolated {
                if type == .began { self?.pause() }
                else if type == .ended, options.contains(.shouldResume) { self?.play() }
            }
        })
        setupRemoteCommands()
    }

    // MARK: Queue

    func play(_ songs: [Song], startingAt song: Song? = nil, shuffled: Bool = false) {
        guard !songs.isEmpty else { return }
        originalQueue = songs
        shuffle = shuffled
        if shuffled {
            var shuffledSongs = songs.shuffled()
            if let song, let i = shuffledSongs.firstIndex(where: { $0.id == song.id }) { shuffledSongs.swapAt(0, i) }
            queue = shuffledSongs
            index = 0
        } else {
            queue = songs
            index = song.flatMap { song in songs.firstIndex { $0.id == song.id } } ?? 0
        }
        loadCurrent(autoplay: true)
    }

    func playNext(_ song: Song) {
        guard current != nil else { return play([song]) }
        if let existing = queue.firstIndex(where: { $0.id == song.id }) {
            if existing == index { return }
            queue.remove(at: existing)
            if existing < index { index -= 1 }
        }
        queue.insert(song, at: index + 1)
        if !originalQueue.contains(where: { $0.id == song.id }) { originalQueue.append(song) }
        Haptics.tap()
    }

    func toggleShuffle() {
        guard let song = current else { shuffle.toggle(); return }
        shuffle.toggle()
        if shuffle {
            queue = [song] + originalQueue.filter { $0.id != song.id }.shuffled()
            index = 0
        } else {
            queue = originalQueue
            index = queue.firstIndex { $0.id == song.id } ?? 0
        }
        Haptics.tap()
    }

    func cycleRepeat() {
        repeatMode = switch repeatMode {
        case .off: .all
        case .all: .one
        case .one: .off
        }
        Haptics.tap()
    }

    /// Call when a song is deleted from the library.
    func remove(_ song: Song) {
        originalQueue.removeAll { $0.id == song.id }
        guard let position = queue.firstIndex(where: { $0.id == song.id }) else { return }
        let wasCurrent = position == index
        queue.remove(at: position)
        if position < index { index -= 1 }
        guard wasCurrent else { return }
        if queue.isEmpty { return stop() }
        index = min(index, queue.count - 1)
        loadCurrent(autoplay: isPlaying)
    }

    // MARK: Transport

    func play() {
        guard current != nil else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func next() { advance(automatic: false) }

    func previous() {
        if currentTime > 3 || index == 0 {
            seek(to: 0)
        } else {
            index -= 1
            loadCurrent(autoplay: true)
        }
    }

    func seek(to time: TimeInterval) {
        let target = max(0, min(time, duration))
        currentTime = target
        isSeeking = true
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in self?.isSeeking = false }
        }
        updateNowPlaying()
    }

    private func advance(automatic: Bool) {
        guard !queue.isEmpty else { return }
        if index + 1 < queue.count {
            index += 1
            loadCurrent(autoplay: true)
        } else {
            index = 0
            loadCurrent(autoplay: !automatic || repeatMode == .all)
        }
    }

    private func itemEnded() {
        if repeatMode == .one {
            seek(to: 0)
            play()
        } else {
            advance(automatic: true)
        }
    }

    private func loadCurrent(autoplay: Bool) {
        guard let song = current else { return stop() }
        player.replaceCurrentItem(with: AVPlayerItem(url: Storage.audioURL(song.id)))
        currentTime = 0
        duration = song.duration
        autoplay ? play() : pause()
    }

    private func stop() {
        player.replaceCurrentItem(with: nil)
        queue = []
        originalQueue = []
        index = 0
        isPlaying = false
        currentTime = 0
        duration = 0
        showsNowPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: Lock screen / Control Center

    private func updateNowPlaying() {
        guard let song = current else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let image = ArtworkStore.image(for: song.id) {
            info[MPMediaItemPropertyArtwork] = Self.artwork(for: image)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private nonisolated static func artwork(for image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        func handle(_ command: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
            command.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
        }
        handle(center.playCommand) { [weak self] in self?.play() }
        handle(center.pauseCommand) { [weak self] in self?.pause() }
        handle(center.togglePlayPauseCommand) { [weak self] in self?.togglePlay() }
        handle(center.nextTrackCommand) { [weak self] in self?.next() }
        handle(center.previousTrackCommand) { [weak self] in self?.previous() }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = event.positionTime
            Task { @MainActor in self?.seek(to: time) }
            return .success
        }
    }
}
