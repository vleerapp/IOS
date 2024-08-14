import SwiftUI

struct NavBar: View {
    @Binding var currentPage: Page
    
    var body: some View {
        HStack {
            NavBarItem(icon: "home", text: "Home", isSelected: currentPage == .home)
                .onTapGesture { currentPage = .home }
            NavBarItem(icon: "songs", text: "Songs", isSelected: currentPage == .songs)
                .onTapGesture { currentPage = .songs }
            NavBarItem(icon: "settings", text: "Settings", isSelected: currentPage == .settings)
                .onTapGesture { currentPage = .settings }
            NavBarItem(icon: "library", text: "Library", isSelected: currentPage == .library)
                .onTapGesture { currentPage = .library }
            NavBarItem(icon: "search", text: "Search", isSelected: currentPage == .search)
                .onTapGesture { currentPage = .search }
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity)
    }
}

struct NavBarItem: View {
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
        .foregroundColor(isSelected ? .white : Color(red: 83/255, green: 83/255, blue: 83/255))
        .frame(maxWidth: .infinity)
    }
}
