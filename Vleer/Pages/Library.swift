import SwiftUI

struct LibraryView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Library")
                    .font(.custom("DMMono-Medium", size: 32))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
    }
}
