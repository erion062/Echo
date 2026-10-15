import SwiftUI

struct SearchView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @AppStorage("recentSearches") private var recentStorage = "[]"
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var recents: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(recentStorage.utf8))) ?? []
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.black)
                .navigationTitle("Search")
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs, artists, anything")
                .onChange(of: query) { scheduleSearch(debounce: true) }
                .onSubmit(of: .search) {
                    remember(query)
                    scheduleSearch(debounce: false)
                }
                .safeAreaInset(edge: .bottom) { MiniPlayer() }
                .animation(.smooth, value: player.current?.id)
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            if recents.isEmpty { hint } else { recentList }
        } else if let errorMessage, results.isEmpty {
            message(symbol: "wifi.exclamationmark", title: "Can't search right now", detail: errorMessage) {
                scheduleSearch(debounce: false)
            }
        } else if results.isEmpty {
            if isLoading {
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                message(symbol: "magnifyingglass", title: "No results", detail: "Try a different spelling or another song.", retry: nil)
            }
        } else {
            resultList
        }
    }

    private var resultList: some View {
        List {
            ForEach(results) { result in
                ResultRow(result: result, status: status(for: result)) {
                    remember(query)
                    library.add(result)
                } onPlay: {
                    if let song = library.song(result.id) {
                        Haptics.tap()
                        player.play([song])
                    }
                }
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 16))
                .alignmentGuide(.listRowSeparatorLeading) { _ in 70 }
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.immediately)
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView().padding(.top, 8)
            }
        }
    }

    private var recentList: some View {
        List {
            Section {
                ForEach(recents, id: \.self) { term in
                    Button {
                        query = term
                        scheduleSearch(debounce: false)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text(term).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .listRowBackground(Color.black)
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .textCase(nil)
                    Spacer()
                    Button("Clear") {
                        withAnimation(.smooth) { recentStorage = "[]" }
                    }
                    .font(.subheadline)
                    .textCase(nil)
                }
                .padding(.bottom, 4)
            }
        }
        .listStyle(.plain)
    }

    private var hint: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.magnifyingglass")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.echoAccent)
                .symbolEffect(.pulse, options: .repeating.speed(0.4))
            Text("Find any song")
                .font(.title3.weight(.semibold))
            Text("Search all of YouTube, then tap +\nto keep it forever, even offline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }

    private func message(symbol: String, title: String, detail: String, retry: (() -> Void)?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func status(for result: SearchResult) -> AddButton.Status {
        if library.contains(result.id) { return .saved }
        if let value = library.progress[result.id] { return .downloading(value) }
        if library.failures.contains(result.id) { return .failed }
        return .idle
    }

    private func scheduleSearch(debounce: Bool) {
        searchTask?.cancel()
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else {
            results = []
            errorMessage = nil
            isLoading = false
            return
        }
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(350))
                if Task.isCancelled { return }
            }
            isLoading = true
            do {
                let found = try await YouTubeSearch.search(term)
                if Task.isCancelled { return }
                withAnimation(.smooth(duration: 0.3)) { results = found }
                errorMessage = nil
            } catch {
                if Task.isCancelled { return }
                errorMessage = "Check your internet connection and try again."
            }
            isLoading = false
        }
    }

    private func remember(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let updated = [trimmed] + recents.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        if let data = try? JSONEncoder().encode(Array(updated.prefix(8))) {
            recentStorage = String(decoding: data, as: UTF8.self)
        }
    }
}

private struct ResultRow: View {
    let result: SearchResult
    let status: AddButton.Status
    let onAdd: () -> Void
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RemoteArtwork(url: result.thumbnailURL, cornerRadius: 6)
                .frame(width: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.body)
                    .lineLimit(1)
                Text("\(result.artist) · \(formatTime(result.duration))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            AddButton(state: status, action: onAdd)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if status == .saved { onPlay() } else if status == .idle || status == .failed { onAdd() }
        }
    }
}
