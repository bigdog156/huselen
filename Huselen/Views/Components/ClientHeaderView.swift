import SwiftUI

struct ClientHeaderView: View {
    let subtitle: String
    let title: String
    var accentColor: Color = Color.fitGreen

    @Environment(AuthManager.self) private var authManager
    @State private var showingProfile = false

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
            }
            Spacer()
            avatarButton
        }
    }

    private var avatarButton: some View {
        let name = authManager.userProfile?.fullName ?? ""
        let initials = name.split(separator: " ").compactMap { $0.first }.suffix(2).map { String($0) }.joined()
        let display = initials.isEmpty ? "NH" : initials.uppercased()
        return Button { showingProfile = true } label: {
            if let urlStr = authManager.userProfile?.avatarUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        initialsCircle(display)
                    }
                }
            } else {
                initialsCircle(display)
            }
        }
        .sheet(isPresented: $showingProfile) { ProfileView() }
    }

    private func initialsCircle(_ text: String) -> some View {
        ZStack {
            Circle().fill(accentColor).frame(width: 44, height: 44)
            Text(text).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
        }
    }
}
