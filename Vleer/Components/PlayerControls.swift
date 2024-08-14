import SwiftUI

struct PlayerControls: View {
    @ObservedObject var audioPlayer: AudioPlayerManager
    
    var body: some View {
        VStack(spacing: 0) {
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
            .padding(.trailing, 20)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.07, green: 0.07, blue: 0.07))
        }
        .frame(height: 52)
        .background(Color(red: 0.07, green: 0.07, blue: 0.07))
        .border(Color(red: 0.325, green: 0.325, blue: 0.325), width: 1)
        .overlay(
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color(red: 160/255, green: 88/255, blue: 255/255))
                    .frame(width: geometry.size.width * CGFloat(audioPlayer.progress), height: 2)
                    .position(x: geometry.size.width * CGFloat(audioPlayer.progress) / 2, y: geometry.size.height - 1)
            }
        )
    }
}