import SwiftUI

@main
struct EchoApp: App {
    @State private var library = Library()
    @State private var player = Player()
    @AppStorage("userName") private var userName = ""

    var body: some Scene {
        WindowGroup {
            ZStack {
                if userName.isEmpty {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    MainView()
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .animation(.smooth(duration: 0.7), value: userName.isEmpty)
            .environment(library)
            .environment(player)
            .preferredColorScheme(.dark)
            .tint(.echoAccent)
        }
    }
}

struct MainView: View {
    enum Tab { case home, search }

    @Environment(Player.self) private var player
    @State private var tab: Tab = .home

    var body: some View {
        @Bindable var player = player
        TabView(selection: $tab) {
            HomeView(openSearch: { tab = .search })
                .tabItem { Label("Library", systemImage: "music.note.house.fill") }
                .tag(Tab.home)
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(Tab.search)
        }
        .sheet(isPresented: $player.showsNowPlaying) {
            NowPlayingView()
        }
        .overlay(alignment: .top) { Toast() }
    }
}

private struct Toast: View {
    @Environment(Library.self) private var library

    var body: some View {
        if let message = library.toast {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { dismiss() }
            .task(id: message) {
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled { dismiss() }
            }
        }
    }

    private func dismiss() {
        withAnimation(.smooth) { library.toast = nil }
    }
}
