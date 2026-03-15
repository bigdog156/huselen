import SwiftUI
import Auth

// MARK: - Environment Key for accent color per role

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}

// MARK: - Profile Toolbar Modifier

struct ProfileToolbarModifier: ViewModifier {
    @Environment(\.appAccentColor) private var accentColor
    @Environment(AuthManager.self) private var authManager
    @State private var showingProfile = false

    private var displayName: String {
        if let name = authManager.userProfile?.fullName, !name.isEmpty {
            return name
        }
        if let metadata = authManager.currentUser?.userMetadata["full_name"],
           case let .string(name) = metadata {
            return name
        }
        return ""
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts.first!.prefix(1) + parts.last!.prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    private var avatarURL: URL? {
        guard let urlStr = authManager.userProfile?.avatarUrl, !urlStr.isEmpty else { return nil }
        return URL(string: urlStr)
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingProfile = true } label: {
                        if let url = avatarURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 34, height: 34)
                                        .clipShape(Circle())
                                        .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                default:
                                    initialsView
                                }
                            }
                        } else if !initials.isEmpty {
                            initialsView
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.title3)
                                .foregroundStyle(accentColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingProfile) {
                ProfileView()
            }
    }

    private var initialsView: some View {
        Text(initials)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(accentColor.gradient)
                    .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
            )
    }
}

extension View {
    func profileToolbar() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
