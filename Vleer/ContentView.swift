import SwiftUI
import AVFoundation
import MediaPlayer

struct Song: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnailUrl: String
    let duration: Int
}

class SearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [Song] = []
    
    func search() {
        guard let url = URL(string: "https://api.vleer.app/search?query=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String: Any]] {
                    DispatchQueue.main.async {
                        self.searchResults = json.compactMap { (key, value) in
                            guard let title = value["title"] as? String,
                                  let artist = value["artist"] as? String,
                                  let thumbnailUrl = value["thumbnailUrl"] as? String,
                                  let duration = value["duration"] as? Int else { return nil }
                            return Song(id: key, title: title, artist: artist, thumbnailUrl: thumbnailUrl, duration: duration)
                        }
                    }
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(searchViewModel.searchResults) { song in
                        SongRow(song: song, audioPlayer: audioPlayer)
                    }
                }
                .listStyle(PlainListStyle())
                
                PlayerControls(audioPlayer: audioPlayer)
                    .frame(height: 100)
            }
            .navigationTitle("Vleer")
            .searchable(text: $searchText, prompt: "Search for songs")
            .onChange(of: searchText) { _, newValue in
                searchViewModel.searchQuery = newValue
                searchViewModel.search()
            }
        }
    }
}

struct SongRow: View {
    let song: Song
    @ObservedObject var audioPlayer: AudioPlayerManager
    
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
                    .font(.headline)
                Text(song.artist)
                    .font(.subheadline)
            }
            
            Spacer()
            
            Text(formatDuration(song.duration))
                .font(.caption)
        }
        .onTapGesture {
            audioPlayer.play(song: song)
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
        VStack {
            HStack {
                Button(action: {
                    audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle" : "play.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                }
                
                Text(formatTime(audioPlayer.currentTime))
                Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                    if !editing {
                        audioPlayer.seek(to: audioPlayer.currentTime)
                    }
                }
                Text(formatTime(audioPlayer.duration))
            }
            .padding()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    private var currentSong: Song?
    
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
}