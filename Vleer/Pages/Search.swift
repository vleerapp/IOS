import SwiftUI
import Foundation

// MARK: - SearchView

struct SearchView: View {
    @ObservedObject var searchViewModel: SearchViewModel
    @ObservedObject var audioPlayer: AudioPlayerManager
    @ObservedObject var download: Download
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Search")
                    .font(.custom("DMMono-Medium", size: 32))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.leading, 20)
                
                SearchBar(text: $searchText)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.07))
            .zIndex(1)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchViewModel.searchResults) { song in
                        SongRow(song: song, audioPlayer: audioPlayer, download: download, query: searchText)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 120)
                .background(Color(red: 0.07, green: 0.07, blue: 0.07))
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
        .onChange(of: searchText) { _, newValue in
            searchViewModel.searchQuery = newValue
            searchViewModel.search()
        }
    }
}

// MARK: - SearchViewModel

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

// MARK: - SearchBar

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
                .font(.custom("DMMono-Regular", size: 18))
                .foregroundColor(Color(red: 171/255, green: 171/255, blue: 171/255))
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .keyboardType(.default)
                .textContentType(.none)
        }
        .padding(.leading, 9)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .padding(.trailing, 9)
        .background(Color(red: 26/255, green: 26/255, blue: 26/255))
    }
}

// MARK: - SongRow

struct SongRow: View {
    let song: Song
    @ObservedObject var audioPlayer: AudioPlayerManager
    @ObservedObject var download: Download
    @State private var showingDownloadAlert = false
    let query: String
    
    var body: some View {
        HStack() {
            AsyncImage(url: URL(string: song.thumbnailUrl)) { image in
                image.resizable()
            } placeholder: {
                Color(red: 0.16, green: 0.16, blue: 0.16)
            }
            .frame(width: 48, height: 48)
            
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.custom("DMMono-Medium", size: 14))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.custom("DMMono-Regular", size: 14))
                    .foregroundColor(Color(red: 171/255, green: 171/255, blue: 171/255))
                    .lineLimit(1)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if song.isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                } else if download.isDownloading && download.currentDownloadId == song.id {
                    ProgressView(value: download.downloadProgress, total: 1.0)
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(width: 20, height: 20)
                }
            
                Image("dots")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
        .onTapGesture {
            audioPlayer.play(song: song, query: query)
        }
        .onLongPressGesture {
            if !song.isDownloaded {
                showingDownloadAlert = true
            }
        }
        .alert("Download Song", isPresented: $showingDownloadAlert) {
            Button("Download") {
                download.downloadFile(id: song.id, quality: "lossless", query: query)
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