import AVKit
import SwiftUI

/// Square artwork for a saved song, with a tasteful placeholder.
struct ArtworkView: View {
    let id: String?
    var cornerRadius: CGFloat = 8

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let id, let image = ArtworkStore.image(for: id) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ArtworkPlaceholder()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }
}

/// Square artwork loaded from YouTube (used for search results).
struct RemoteArtwork: View {
    let url: URL?
    var cornerRadius: CGFloat = 8

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().transition(.opacity)
                    } else {
                        ArtworkPlaceholder()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }
}

struct ArtworkPlaceholder: View {
    var body: some View {
        LinearGradient(colors: [Color(white: 0.2), Color(white: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                Image(systemName: "music.note")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
    }
}

/// The + button that turns into a progress ring and then a checkmark.
struct AddButton: View {
    enum Status: Equatable { case idle, downloading(Double), saved, failed }

    let state: Status
    let action: () -> Void
    @State private var spin = false

    var body: some View {
        Button(action: action) {
            ZStack {
                switch state {
                case .idle:
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.echoAccent)
                        .frame(width: 32, height: 32)
                        .background(Color.echoAccent.opacity(0.15), in: Circle())
                        .transition(.scale.combined(with: .opacity))
                case .downloading(let value):
                    ZStack {
                        Circle().stroke(.white.opacity(0.15), lineWidth: 2.5)
                        if value <= 0.001 {
                            Circle()
                                .trim(from: 0, to: 0.25)
                                .stroke(Color.echoAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(spin ? 360 : 0))
                                .onAppear {
                                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { spin = true }
                                }
                        } else {
                            Circle()
                                .trim(from: 0, to: value)
                                .stroke(Color.echoAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.smooth, value: value)
                        }
                        RoundedRectangle(cornerRadius: 2).fill(Color.echoAccent).frame(width: 8, height: 8)
                    }
                    .frame(width: 26, height: 26)
                    .frame(width: 32, height: 32)
                    .transition(.scale.combined(with: .opacity))
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.echoAccent)
                        .frame(width: 32, height: 32)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                case .failed:
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.orange)
                        .frame(width: 32, height: 32)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: state)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.8))
        .disabled(state == .saved || {
            if case .downloading = state { return true }
            return false
        }())
    }
}

/// Animated "now playing" bars.
struct NowPlayingIndicator: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: "waveform")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.echoAccent)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPlaying)
    }
}

struct SongRow: View {
    @Environment(Player.self) private var player
    @Environment(Library.self) private var library
    let song: Song
    let onPlay: () -> Void

    private var isCurrent: Bool { player.current?.id == song.id }

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(id: song.id, cornerRadius: 6)
                .frame(width: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.body)
                    .foregroundStyle(isCurrent ? Color.echoAccent : .primary)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if isCurrent {
                NowPlayingIndicator(isPlaying: player.isPlaying)
            } else {
                Text(formatTime(song.duration))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 40)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.tap()
            onPlay()
        }
        .contextMenu { menuItems }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button { onPlay() } label: { Label("Play", systemImage: "play") }
        Button { player.playNext(song) } label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") }
        Divider()
        Button(role: .destructive) {
            player.remove(song)
            library.delete(song)
        } label: {
            Label("Remove from Library", systemImage: "trash")
        }
    }
}

struct MiniPlayer: View {
    @Environment(Player.self) private var player

    var body: some View {
        if let song = player.current {
            HStack(spacing: 12) {
                ArtworkView(id: song.id, cornerRadius: 7)
                    .frame(width: 44)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(song.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(song.artist).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button {
                    Haptics.soft()
                    player.togglePlay()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(PressableStyle(scale: 0.8))
                Button {
                    Haptics.soft()
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(PressableStyle(scale: 0.8))
            }
            .foregroundStyle(.white)
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(alignment: .bottom) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(.white.opacity(0.85))
                                .frame(width: geo.size.width * player.progress, height: 2)
                                .animation(.linear(duration: 0.25), value: player.progress)
                        }
                        .frame(height: 2)
                        .padding(.horizontal, 18)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
            }
            .contentShape(Rectangle())
            .onTapGesture { player.showsNowPlaying = true }
            .gesture(DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.height < -30 { player.showsNowPlaying = true }
            })
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor.white.withAlphaComponent(0.65)
        view.activeTintColor = UIColor(Color.echoAccent)
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
