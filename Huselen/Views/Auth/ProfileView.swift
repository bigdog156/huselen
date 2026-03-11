import SwiftUI
import Auth

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    private var displayName: String {
        if let name = authManager.userProfile?.fullName, !name.isEmpty {
            return name
        }
        if let metadata = authManager.currentUser?.userMetadata["full_name"],
           case let .string(name) = metadata {
            return name
        }
        return "Người dùng"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts.first!.prefix(1) + parts.last!.prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar card
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.warmYellow.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Text(initials)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.warmYellow)
                        }

                        Text(displayName)
                            .font(Theme.Fonts.title())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if let email = authManager.currentUser?.email {
                            Text(email)
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        if let role = authManager.userProfile?.role {
                            CuteBadge(text: roleName(role), color: roleColor(role))
                        }
                    }
                    .padding(.top, 20)

                    // Account info
                    VStack(spacing: 0) {
                        if let createdAt = authManager.currentUser?.createdAt {
                            HStack {
                                CuteIconCircle(icon: "calendar", color: Theme.Colors.lavender, size: 36)
                                Text("Ngày tạo")
                                    .font(Theme.Fonts.body())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Text(createdAt, format: .dateTime.day().month().year())
                                    .font(Theme.Fonts.subheadline())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .cuteCard()
                    .padding(.horizontal)

                    // Sign out
                    Button {
                        Task {
                            await authManager.signOut()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Đăng xuất")
                        }
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.Colors.softPink))
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(Theme.Colors.warmYellow)
                }
            }
        }
    }

    private func roleName(_ role: UserRole) -> String {
        switch role {
        case .owner: return "👑 Chủ phòng gym"
        case .trainer: return "💪 Huấn luyện viên"
        case .client: return "🏃 Học viên"
        }
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .owner: return Theme.Colors.warmYellow
        case .trainer: return Theme.Colors.softOrange
        case .client: return Theme.Colors.mintGreen
        }
    }
}
