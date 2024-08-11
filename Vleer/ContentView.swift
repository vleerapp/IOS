import SwiftUI

enum Page {
    case home
    case songs
    case settings
    case library
    case search
}

struct ContentView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @StateObject private var download = Download()
    @State private var currentPage: Page = .home

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color(red: 0.07, green: 0.07, blue: 0.07).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    switch currentPage {
                    case .home:
                        HomeView()
                    case .songs:
                        SongsView()
                    case .settings:
                        SettingsView()
                    case .library:
                        LibraryView()
                    case .search:
                        SearchView(searchViewModel: searchViewModel, audioPlayer: audioPlayer, download: download)
                    }
                }
                .frame(height: geometry.size.height)
                .offset(y: 0)
                
                VStack(spacing: 0) {
                    PlayerControls(audioPlayer: audioPlayer)
                        .padding(.horizontal, 12)
                    
                    NavBar(currentPage: $currentPage)
                        .padding(.horizontal, 12)
                }
                .background(Color(red: 0.07, green: 0.07, blue: 0.07))
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
