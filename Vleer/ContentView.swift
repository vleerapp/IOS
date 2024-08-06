import SwiftUI
import ModernAVPlayer
import MediaPlayer

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0.0
    
    var body: some View {
        VStack {
            Text("Vleer Music Player")
                .font(.largeTitle)
                .padding()
            
            Button(action: {
                audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
            }) {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle" : "play.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }
            
            HStack {
                Text(formatTime(audioPlayer.currentTime))
                Slider(value: $audioPlayer.currentTime, in: 0...audioPlayer.duration) { editing in
                    if !editing {
                        audioPlayer.seek(to: audioPlayer.currentTime)
                    }
                }
                Text(formatTime(audioPlayer.duration))
            }
            .padding()
            
            Button(action: {
                downloadFile()
            }) {
                if isDownloading {
                    ProgressView(value: isDownloading ? downloadProgress : 0, total: 1.0)
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Download FLAC")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .disabled(isDownloading)
        }
        .onAppear {
            audioPlayer.setupRemoteTransportControls()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func downloadFile() {
        isDownloading = true
        downloadProgress = 0.0
        
        guard let url = URL(string: "https://api.vleer.app/download?id=ZbwEuFb2Zec&quality=lossless") else {
            print("Invalid URL")
            isDownloading = false
            return
        }
        
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access documents directory")
            isDownloading = false
            return
        }
        
        let destinationURL = documentsURL.appendingPathComponent("downloaded_song.flac")
        
        print("Attempting to download file to: \(destinationURL.path)")
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
                return
            }
            
            guard let localURL = localURL else {
                print("Local URL is nil")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
                return
            }
            
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: localURL, to: destinationURL)
                
                // Set file attributes to make it visible
                try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destinationURL.path)
                
                print("File downloaded successfully to: \(destinationURL.path)")
                print("File exists at destination: \(fileManager.fileExists(atPath: destinationURL.path))")
                print("File size: \(try fileManager.attributesOfItem(atPath: destinationURL.path)[.size] ?? 0) bytes")
                
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.downloadProgress = 1.0
                }
            } catch {
                print("Error saving file: \(error)")
                DispatchQueue.main.async {
                    self.isDownloading = false
                }
            }
        }
        
        downloadTask.resume()
        
        // Update download progress
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard self.isDownloading else {
                timer.invalidate()
                return
            }
            
            let progress = Double(downloadTask.countOfBytesReceived) / Double(downloadTask.countOfBytesExpectedToReceive)
            DispatchQueue.main.async {
                self.downloadProgress = min(max(progress, 0.0), 1.0) // Ensure progress is between 0 and 1
            }
        }
    }
}

class AudioPlayerManager: ObservableObject {
    private var player: ModernAVPlayer
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    init() {
        let config = ModernAVPlayerConfiguration()
        player = ModernAVPlayer(config: config)
        setupPlayer()
        setupObservers()
    }
    
    private func setupPlayer() {
        guard let url = URL(string: "https://api.vleer.app/stream?id=ZbwEuFb2Zec&quality=lossless") else { return }
        let media = ModernAVPlayerMedia(url: url, type: .stream(isLive: false))
        player.load(media: media, autostart: false)
    }
    
    private func setupObservers() {
        player.delegate = self
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func seek(to time: TimeInterval) {
        player.seek(position: time)
    }
    
    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [unowned self] _ in
            self.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            self.pause()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [unowned self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self.seek(to: event.positionTime)
            }
            return .success
        }
    }
}

extension AudioPlayerManager: ModernAVPlayerDelegate {
    func modernAVPlayer(_ player: ModernAVPlayer, didStateChange state: ModernAVPlayer.State) {
        DispatchQueue.main.async {
            self.isPlaying = state == .playing
        }
    }
    
    func modernAVPlayer(_ player: ModernAVPlayer, didCurrentTimeChange currentTime: Double) {
        DispatchQueue.main.async {
            self.currentTime = currentTime
        }
    }
    
    func modernAVPlayer(_ player: ModernAVPlayer, didItemDurationChange itemDuration: Double?) {
        DispatchQueue.main.async {
            self.duration = itemDuration ?? 0
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}