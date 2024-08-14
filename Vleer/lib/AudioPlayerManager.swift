import AVFoundation
import MediaPlayer


class AudioPlayerManager: ObservableObject {
    private var player: AVPlayer
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSong: Song?
    @Published var progress: Double = 0
    
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
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.progress = self.duration > 0 ? self.currentTime / self.duration : 0
            self.updateNowPlayingInfo()
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
    
    func play(song: Song, query: String = "") {
        currentSong = song
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let localURL = documentsURL.appendingPathComponent("\(song.id) - \(song.artist) - \(song.title).flac")
        
        if fileManager.fileExists(atPath: localURL.path) {
            playLocal(url: localURL)
        } else {
            playOnline(song: song)
        }
        
        APIService.updateSearchWeight(query: query, selectedId: song.id)
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