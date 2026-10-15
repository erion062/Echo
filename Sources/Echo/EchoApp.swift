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
    }
}
