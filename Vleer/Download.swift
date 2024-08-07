import Foundation
import SwiftUI

class Download: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var currentDownloadId: String?
    @Published var downloadedFiles: [URL] = []
    
    private var downloadQueue: [(id: String, quality: String)] = []
    
    init() {
        loadDownloadedFiles()
    }
    
    func downloadFile(id: String, quality: String) {
        currentDownloadId = id
        downloadQueue.append((id: id, quality: quality))
        processQueue()
    }
    
    private func processQueue() {
        guard !isDownloading, let (id, quality) = downloadQueue.first else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to access documents directory")
            isDownloading = false
            return
        }
        
        let destinationURL = documentsURL.appendingPathComponent("\(id).flac")
        let downloadURL = URL(string: "https://api.vleer.app/download?id=\(id)&quality=\(quality)")!
        
        let downloadTask = URLSession.shared.downloadTask(with: downloadURL) { localURL, response, error in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
                self.finishDownload(success: false)
                return
            }
            
            guard let localURL = localURL else {
                print("Local URL is nil")
                self.finishDownload(success: false)
                return
            }
            
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: localURL, to: destinationURL)
                try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destinationURL.path)
                
                DispatchQueue.main.async {
                    self.downloadedFiles.append(destinationURL)
                    self.finishDownload(success: true)
                }
            } catch {
                print("Error saving file: \(error)")
                self.finishDownload(success: false)
            }
        }
        
        downloadTask.resume()
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard self.isDownloading else {
                timer.invalidate()
                return
            }
            
            let progress = Double(downloadTask.countOfBytesReceived) / Double(downloadTask.countOfBytesExpectedToReceive)
            DispatchQueue.main.async {
                self.downloadProgress = min(max(progress, 0.0), 1.0)
            }
        }
    }
    
    private func finishDownload(success: Bool) {
        DispatchQueue.main.async {
            self.isDownloading = false
            self.downloadProgress = success ? 1.0 : 0.0
            self.downloadQueue.removeFirst()
            self.processQueue()
        }
    }
    
    private func loadDownloadedFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            downloadedFiles = fileURLs.filter { $0.pathExtension == "flac" }
        } catch {
            print("Error loading downloaded files: \(error)")
        }
    }
}

struct DownloadButton: View {
    @ObservedObject var download: Download
    
    var body: some View {
        Button(action: {
            download.downloadFile(id: "ZbwEuFb2Zec", quality: "lossless")
        }) {
            if download.isDownloading {
                ProgressView(value: download.downloadProgress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Text("Download FLAC")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .disabled(download.isDownloading)
    }
}

struct DownloadedFilesList: View {
    @ObservedObject var download: Download
    
    var body: some View {
        List(download.downloadedFiles, id: \.self) { file in
            Text(file.deletingPathExtension().lastPathComponent)
        }
        .navigationTitle("Downloaded Files")
    }
}