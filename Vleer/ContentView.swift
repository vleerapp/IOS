import SwiftUI
import AVFoundation
import MediaPlayer

struct Song: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnailUrl: String
    let duration: Int
    var isDownloaded: Bool = false
}

class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [Song] = []
    
    func search() {
        // Search local files first
        let localSongs = searchLocalFiles()
        
        // Then search online
        guard let url = URL(string: "https://api.vleer.app/search?query=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: Any]] {
                    DispatchQueue.main.async {
                        let onlineSongs = json.compactMap { (key, value) -> Song? in
                            guard let title = value["title"] as? String,
                                  let artist = value["artist"] as? String,
                                  let thumbnailUrl = value["thumbnailUrl"] as? String,
                                  let duration = value["duration"] as? Int else { return nil }
                            return Song(id: key, title: title, artist: artist, thumbnailUrl: thumbnailUrl, duration: duration)
                        }
                        self.searchResults = localSongs + onlineSongs
                    }
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }.resume()
    }
    
    private func searchLocalFiles() -> [Song] {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            return fileURLs.compactMap { url in
                guard url.pathExtension == "flac" else { return nil }
                let fileName = url.deletingPathExtension().lastPathComponent
                // Assuming the file name format is "id - artist - title"
                let components = fileName.split(separator: " - ", maxSplits: 2)
                guard components.count == 3 else { return nil }
                let id = String(components[0])
                let artist = String(components[1])
                let title = String(components[2])
                return Song(id: id, title: title, artist: artist, thumbnailUrl: "", duration: 0, isDownloaded: true)
            }.filter { song in
                song.title.lowercased().contains(searchQuery.lowercased()) || song.artist.lowercased().contains(searchQuery.lowercased())
            }
        } catch {
            print("Error searching local files: \(error)")
            return []
        }
    }
}

struct ContentView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @StateObject private var download = Download()
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.07).edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                HStack {
                    Text("Search")
                        .font(.custom("DMMono-Medium", size: 32))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                .padding(.leading, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                Spacer()
                
                List {
                    ForEach(searchViewModel.searchResults) { song in
                        SongRow(song: song, audioPlayer: audioPlayer, download: download)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(red: 0.07, green: 0.07, blue: 0.07))
                
                PlayerControls(audioPlayer: audioPlayer)
                    .padding(.horizontal, 12)
                
                TabBar()
                    .padding(.horizontal, 12)
            }
        }
        .onChange(of: searchText) { _, newValue in
            searchViewModel.searchQuery = newValue
            searchViewModel.search()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(Color(red: 171/255, green: 171/255, blue: 171/255))
            
            TextField("Songs", text: $text)
                .font(.custom("DMMono-Medium", size: 18))
                .foregroundColor(Color(red: 171/255, green: 171/255, blue: 171/255))
        }
        .padding(.leading, 9)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .padding(.trailing, 9)
        .background(Color(red: 26/255, green: 26/255, blue: 26/255))
    }
}

struct SongRow: View {
    let song: Song
    @ObservedObject var audioPlayer: AudioPlayerManager
    @ObservedObject var download: Download
    @State private var showingDownloadAlert = false
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .frame(width: 50, height: 50)
            .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.custom("DMMono-Regular", size: 16))
                    .foregroundColor(.white)
                Text(song.artist)
                    .font(.custom("DMMono-Regular", size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if song.isDownloaded {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.green)
            } else if download.isDownloading && download.currentDownloadId == song.id {
                ProgressView(value: download.downloadProgress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 20, height: 20)
            }
            
            Text(formatDuration(song.duration))
                .font(.custom("DMMono-Regular", size: 12))
                .foregroundColor(.gray)
        }
        .listRowBackground(Color(red: 0.07, green: 0.07, blue: 0.07))
        .onTapGesture {
            audioPlayer.play(song: song)
        }
        .onLongPressGesture {
            if !song.isDownloaded {
                showingDownloadAlert = true
            }
        }
        .alert("Download Song", isPresented: $showingDownloadAlert) {
            Button("Download") {
                download.downloadFile(id: song.id, quality: "lossless")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to download '\(song.title)' by \(song.artist)?")
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct PlayerControls: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    
    var body: some View {
        HStack {
            if let currentSong = audioPlayer.currentSong {
                AsyncImage(url: URL(string: currentSong.thumbnailUrl)) { image in
                    image.resizable()
                } placeholder: {
                    Color(red: 0.16, green: 0.16, blue: 0.16)
                }
                .frame(width: 36, height: 36)
                
                VStack(alignment: .leading) {
                    Text(currentSong.title)
                        .font(.custom("DMMono-Medium", size: 14))
                        .foregroundColor(.white)
                        .padding(.leading, 4)
                }
            } else {
                Color(red: 0.16, green: 0.16, blue: 0.16)
                    .frame(width: 36, height: 36)
                
                Text("Not Playing")
                    .font(.custom("DMMono-Medium", size: 14))
                    .foregroundColor(.white)
                    .padding(.leading, 4)
            }
            
            Spacer()
            
            Button(action: {
                audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            Button(action: audioPlayer.nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
        }
        .padding(.leading, 8)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .padding(.trailing, 16)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
        .border(Color(red: 0.325, green: 0.325, blue: 0.325), width: 1)
    }
}

struct TabBar: View {
    @State private var selectedTab = "Home"
    
    var body: some View {
        HStack {
            TabBarItem(icon: "home", text: "Home", isSelected: selectedTab == "Home")
                .onTapGesture { selectedTab = "Home" }
            TabBarItem(icon: "songs", text: "Songs", isSelected: selectedTab == "Songs")
                .onTapGesture { selectedTab = "Songs" }
            TabBarItem(icon: "settings", text: "Settings", isSelected: selectedTab == "Settings")
                .onTapGesture { selectedTab = "Settings" }
            TabBarItem(icon: "library", text: "Library", isSelected: selectedTab == "Library")
                .onTapGesture { selectedTab = "Library" }
            TabBarItem(icon: "search", text: "Search", isSelected: selectedTab == "Search")
                .onTapGesture { selectedTab = "Search" }
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
    }
}

struct TabBarItem: View {
    let icon: String
    let text: String
    let isSelected: Bool
    
    var body: some View {
        VStack {
            Image(isSelected ? "\(icon)_fill" : "\(icon)_outline")
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
            Text(text)
                .font(.custom("DMMono-Medium", size: 10))
        }
        .foregroundColor(isSelected ? .white : .gray)
        .frame(maxWidth: .infinity)
    }
}

class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSong: Song?
    
    init() {
        player = AVPlayer()
        setupAudioSession()
        setupObservers()
        setupRemoteTransportControls()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupObservers() {
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            self?.updateNowPlayingInfo()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        player.seek(to: .zero)
        player.pause()
        isPlaying = false
    }
    
    func play(song: Song) {
        currentSong = song
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let localURL = documentsURL.appendingPathComponent("\(song.id) - \(song.artist) - \(song.title).flac")
        
        if fileManager.fileExists(atPath: localURL.path) {
            playLocal(url: localURL)
        } else {
            playOnline(song: song)
        }
    }
    
    private func playLocal(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true
        
        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration) {
                await MainActor.run {
                    self.duration = duration.seconds
                }
            }
        }
        
        updateNowPlayingInfo()
    }
    
    private func playOnline(song: Song) {
        let urlString = "https://api.vleer.app/stream?id=\(song.id)&quality=lossless"
        guard let url = URL(string: urlString) else { return }
        
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        isPlaying = true
        
        Task {
            if let duration = try? await player.currentItem?.asset.load(.duration) {
                await MainActor.run {
                    self.duration = duration.seconds
                }
            }
        }
        
        updateNowPlayingInfo()
    }
    
    func play() {
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func seek(to time: TimeInterval) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 1))
    }
    
    private func updateNowPlayingInfo() {
        guard let song = currentSong else { return }
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = song.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = song.artist
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let thumbnailUrl = URL(string: song.thumbnailUrl) {
            URLSession.shared.dataTask(with: thumbnailUrl) { data, _, error in
                if let data = data, let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }.resume()
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }
    
    func previousTrack() {
        // Implement previous track logic
        print("Previous track")
    }
    
    func nextTrack() {
        // Implement next track logic
        print("Next track")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
