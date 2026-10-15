import SwiftUI

struct NowPlayingView: View {
    @Environment(Player.self) private var player
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var scrubValue: Double?

    var body: some View {
        let song = player.current
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 38, height: 5)
                .padding(.top, 10)

            Spacer(minLength: 16)

            ArtworkView(id: song?.id, cornerRadius: 16)
                .scaleEffect(player.isPlaying ? 1 : 0.8)
                .shadow(color: .black.opacity(player.isPlaying ? 0.5 : 0.25), radius: player.isPlaying ? 34 : 14, y: player.isPlaying ? 22 : 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.68), value: player.isPlaying)
                .id(song?.id)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))

            Spacer(minLength: 24)

            titleRow
            scrubber.padding(.top, 26)
            controls.padding(.top, 22)

            Spacer(minLength: 20)

            bottomRow
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
        .background { background(for: song) }
        .animation(.smooth(duration: 0.45), value: song?.id)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(38)
        .onChange(of: song == nil) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    // MARK: Pieces

    private func background(for song: Song?) -> some View {
        let tint = song.flatMap { ArtworkStore.tint(for: $0.id) } ?? Color(white: 0.25)
        return ZStack {
            Color.black
            if let id = song?.id, let image = ArtworkStore.image(for: id) {
                Color.clear.overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 70)
                        .scaleEffect(1.4)
                        .opacity(0.55)
                }
                .clipped()
            }
            LinearGradient(colors: [tint.opacity(0.75), tint.opacity(0.35), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.current?.title ?? "Not Playing")
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                Text(player.current?.artist ?? "")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            if let song = player.current {
                Menu {
                    Button(role: .destructive) {
                        player.remove(song)
                        library.delete(song)
                    } label: {
                        Label("Remove from Library", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.14), in: Circle())
                }
            }
        }
    }

    private var scrubber: some View {
        let duration = max(player.duration, 1)
        let time = scrubValue ?? player.currentTime
        let isDragging = scrubValue != nil
        return VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(.white.opacity(isDragging ? 1 : 0.8))
                        .frame(width: geo.size.width * min(max(time / duration, 0), 1))
                }
                .frame(height: isDragging ? 12 : 7)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if scrubValue == nil { Haptics.soft() }
                            scrubValue = min(max(value.location.x / geo.size.width, 0), 1) * duration
                        }
                        .onEnded { _ in
                            if let scrubValue { player.seek(to: scrubValue) }
                            scrubValue = nil
                        }
                )
            }
            .frame(height: 24)
            .scaleEffect(x: isDragging ? 1.03 : 1, y: 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)

            HStack {
                Text(formatTime(time))
                Spacer()
                Text("-" + formatTime(max(player.duration - time, 0)))
            }
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(.white.opacity(isDragging ? 0.9 : 0.5))
        }
    }

    private var controls: some View {
        HStack {
            Spacer()
            TransportButton(symbol: "backward.fill", size: 32) { player.previous() }
            Spacer()
            TransportButton(symbol: player.isPlaying ? "pause.fill" : "play.fill", size: 50) { player.togglePlay() }
            Spacer()
            TransportButton(symbol: "forward.fill", size: 32) { player.next() }
            Spacer()
        }
    }

    private var bottomRow: some View {
        HStack {
            ToggleIcon(symbol: "shuffle", isOn: player.shuffle) { player.toggleShuffle() }
            Spacer()
            AirPlayButton().frame(width: 44, height: 44)
            Spacer()
            ToggleIcon(symbol: player.repeatMode == .one ? "repeat.1" : "repeat", isOn: player.repeatMode != .off) {
                player.cycleRepeat()
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct TransportButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void
    @State private var bounce = 0

    var body: some View {
        Button {
            Haptics.soft()
            bounce += 1
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: size))
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.bounce.down, value: bounce)
                .frame(width: size * 1.8, height: size * 1.8)
                .contentShape(Circle())
        }
        .buttonStyle(TransportStyle())
    }
}

private struct TransportStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(.white.opacity(configuration.isPressed ? 0.12 : 0)))
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

private struct ToggleIcon: View {
    let symbol: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isOn ? Color.black : .white.opacity(0.65))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white.opacity(isOn ? 0.9 : 0)))
                .animation(.smooth(duration: 0.2), value: isOn)
        }
        .buttonStyle(PressableStyle(scale: 0.85))
    }
}
