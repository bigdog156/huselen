import SwiftUI
import PhotosUI
import Auth

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false

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
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                if let urlStr = authManager.userProfile?.avatarUrl,
                                   !urlStr.isEmpty,
                                   let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                                .shadow(color: Theme.Colors.warmYellow.opacity(0.3), radius: 8, y: 4)
                                        default:
                                            avatarPlaceholder
                                        }
                                    }
                                } else {
                                    avatarPlaceholder
                                }

                                // Camera badge
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.warmYellow)
                                        .frame(width: 30, height: 30)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                                if isUploadingAvatar {
                                    Circle()
                                        .fill(.black.opacity(0.4))
                                        .frame(width: 100, height: 100)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                        .disabled(isUploadingAvatar)
                        .onChange(of: selectedPhoto) { _, newValue in
                            guard let newValue else { return }
                            Task {
                                await handlePhotoSelection(newValue)
                            }
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
                        // Gym info
                        if let gym = authManager.currentGym {
                            HStack {
                                CuteIconCircle(icon: "building.2.fill", color: Theme.Colors.warmYellow, size: 36)
                                Text("Phòng tập")
                                    .font(Theme.Fonts.body())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                                Text(gym.name)
                                    .font(Theme.Fonts.subheadline())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, 12)

                            // Show invite code for admin
                            if authManager.userRole == .owner && !gym.inviteCode.isEmpty {
                                Divider()
                                HStack {
                                    CuteIconCircle(icon: "key.fill", color: Theme.Colors.mintGreen, size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Mã mời")
                                            .font(Theme.Fonts.body())
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text("Chia sẻ cho PT/học viên")
                                            .font(Theme.Fonts.caption())
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = gym.inviteCode
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(gym.inviteCode)
                                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                        }
                                        .foregroundStyle(Theme.Colors.mintGreen)
                                    }
                                }
                                .padding(.vertical, 12)
                            }

                            Divider()
                        }

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

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.warmYellow.opacity(0.15))
                .frame(width: 100, height: 100)
            Text(initials)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.warmYellow)
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        // Compress to JPEG
        guard let uiImage = UIImage(data: data),
              let jpegData = uiImage.jpegData(compressionQuality: 0.7) else { return }

        _ = await authManager.uploadAvatar(imageData: jpegData)
        selectedPhoto = nil
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
