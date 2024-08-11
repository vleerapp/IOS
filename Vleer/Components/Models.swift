import Foundation

struct Song: Identifiable {
    let id: String
    let title: String
    let artist: String
    let thumbnailUrl: String
    let duration: Int
    var isDownloaded: Bool = false
}
