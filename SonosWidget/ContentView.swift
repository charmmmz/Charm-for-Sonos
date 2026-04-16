import SwiftUI

struct ContentView: View {
    @State var manager = SonosManager()

    var body: some View {
        TabView {
            Tab("Home", systemImage: "play.circle.fill") {
                PlayerView(manager: manager)
            }
            Tab("Search", systemImage: "magnifyingglass") {
                SearchView(manager: manager)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(manager.albumArtDominantColor ?? .blue)
        .overlay {
            if manager.isConfigured && manager.showFullPlayer {
                NowPlayingOverlay(manager: manager)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: manager.showFullPlayer)
        .preferredColorScheme(.dark)
    }
}

#Preview { ContentView() }
