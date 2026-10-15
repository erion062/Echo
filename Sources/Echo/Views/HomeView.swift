import SwiftUI

struct HomeView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @AppStorage("userName") private var userName = ""
    @State private var showProfile = false
    let openSearch: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    header
                    if !library.pending.isEmpty { savingSection }
                    if library.songs.isEmpty {
                        if library.pending.isEmpty { emptyState }
                    } else {
                        recentlyAdded
                        songsSection
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(Color.black)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { MiniPlayer() }
            .animation(.smooth, value: player.current?.id)
        }
        .sheet(isPresented: $showProfile) { ProfileSheet() }
    }

    // MARK: Header

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Late night"
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text("\(greeting),\n\(userName)")
                    .font(.system(size: 34, weight: .bold))
                    .lineSpacing(2)
                if !library.songs.isEmpty {
                    Text("\(library.songs.count) \(library.songs.count == 1 ? "song" : "songs") · \(formatLength(library.totalDuration)) · ready offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Button {
                Haptics.tap()
                showProfile = true
            } label: {
                Avatar(name: userName, size: 40)
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 18)
        }
        .padding(.horizontal, 20)
    }

    // MARK: Sections

    private var savingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Saving")
            ForEach(library.pending) { result in
                HStack(spacing: 14) {
                    RemoteArtwork(url: result.thumbnailURL, cornerRadius: 6)
                        .frame(width: 50)
                        .opacity(0.6)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.title).lineLimit(1)
                        Text(result.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    AddButton(state: .downloading(library.progress[result.id] ?? 0)) {}
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var recentlyAdded: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Recently Added")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 16) {
                    ForEach(library.recentlyAdded) { song in
                        Button {
                            Haptics.tap()
                            player.play(library.recentlyAdded, startingAt: song)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ArtworkView(id: song.id, cornerRadius: 12)
                                    .frame(width: 160)
                                    .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                                    Text(song.artist).font(.subheadline).foregroundStyle(.secondary)
                                }
                                .lineLimit(1)
                                .frame(width: 160, alignment: .leading)
                            }
                        }
                        .buttonStyle(PressableStyle(scale: 0.96))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }

    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle("Songs")
            HStack(spacing: 12) {
                PlayModeButton(title: "Play", symbol: "play.fill") {
                    player.play(library.alphabetical)
                }
                PlayModeButton(title: "Shuffle", symbol: "shuffle") {
                    player.play(library.alphabetical, shuffled: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            LazyVStack(spacing: 0) {
                let songs = library.alphabetical
                ForEach(songs) { song in
                    SongRow(song: song) { player.play(songs, startingAt: song) }
                    if song.id != songs.last?.id {
                        Divider().padding(.leading, 84)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.echoAccent.opacity(0.12)).frame(width: 110, height: 110)
                Image(systemName: "music.note.list")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.echoAccent)
            }
            VStack(spacing: 8) {
                Text("Your library is empty")
                    .font(.title3.weight(.semibold))
                Text("Search for any song and tap + to keep it.\nIt'll play even without a connection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Haptics.tap()
                openSearch()
            } label: {
                Label("Find Music", systemImage: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .frame(height: 50)
                    .background(Color.echoAccent, in: Capsule())
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title2.weight(.bold))
            .padding(.horizontal, 20)
    }
}

private struct PlayModeButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(Color.echoAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.echoCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat

    var body: some View {
        Text(name.first.map { String($0).uppercased() } ?? "")
            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [Color(red: 1, green: 0.45, blue: 0.53), .echoAccent],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
}

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Library.self) private var library
    @AppStorage("userName") private var userName = ""
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Avatar(name: draft.isEmpty ? userName : draft, size: 84)
                        Text(draft.isEmpty ? userName : draft)
                            .font(.title2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section("Name") {
                    TextField("Your name", text: $draft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                Section("Library") {
                    LabeledContent("Songs", value: "\(library.songs.count)")
                    LabeledContent("Listening time", value: formatLength(library.totalDuration))
                    LabeledContent("Storage", value: ByteCountFormatter.string(fromByteCount: Storage.bytesUsed, countStyle: .file))
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty { userName = name }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear { draft = userName }
        .presentationDetents([.large])
    }
}
