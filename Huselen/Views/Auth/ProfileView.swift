import SwiftUI
import PhotosUI
import Auth

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var showLeaveConfirm = false
    @State private var isLeaving = false

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
                                inviteCodeRow(code: gym.inviteCode, label: "Chia sẻ cho PT/học viên")
                            }

                            Divider()
                        }
                        // Freelance PT — show invite code
                        else if authManager.isFreelancePT {
                            HStack {
                                CuteIconCircle(icon: "person.fill.badge.plus", color: Theme.Colors.softOrange, size: 36)
                                Text("PT tự do")
                                    .font(Theme.Fonts.body())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, 12)

                            if let code = syncManager.trainers.first?.inviteCode, !code.isEmpty {
                                Divider()
                                inviteCodeRow(code: code, label: "Chia sẻ cho học viên để tham gia")
                            }

                            Divider()
                        }
                        // Client with freelance PT (no gym but is_freelance)
                        else if authManager.userRole == .client && (authManager.userProfile?.isFreelance ?? false) {
                            HStack {
                                CuteIconCircle(icon: "person.fill", color: Theme.Colors.softOrange, size: 36)
                                Text("Học viên tự do")
                                    .font(Theme.Fonts.body())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            Divider()
                        }

                        // Change gym/PT button (for clients and gym trainers, not owners)
                        if authManager.userRole != .owner {
                            Button {
                                showLeaveConfirm = true
                            } label: {
                                HStack {
                                    CuteIconCircle(icon: "arrow.triangle.2.circlepath", color: Theme.Colors.lavender, size: 36)
                                    Text(changeButtonLabel)
                                        .font(Theme.Fonts.body())
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .padding(.vertical, 12)
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

                    // Appearance
                    VStack(spacing: 0) {
                        ThemePickerRow()
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
            .confirmationDialog("Thay đổi phòng tập / PT", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
                Button("Xác nhận thay đổi", role: .destructive) {
                    Task {
                        isLeaving = true
                        _ = await authManager.leaveCurrentGymOrPT()
                        isLeaving = false
                        dismiss()
                    }
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Bạn sẽ rời khỏi phòng tập / PT hiện tại và chọn lại. Dữ liệu cũ vẫn được lưu.")
            }
            .overlay {
                if isLeaving {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Đang xử lý...")
                            .padding(24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
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

    private var changeButtonLabel: String {
        if authManager.currentGym != nil {
            return "Đổi phòng tập"
        } else if authManager.isFreelancePT {
            return "Đổi sang phòng gym"
        } else {
            return "Đổi phòng tập / PT"
        }
    }

    private func inviteCodeRow(code: String, label: String) -> some View {
        HStack {
            CuteIconCircle(icon: "key.fill", color: Theme.Colors.mintGreen, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mã mời")
                    .font(Theme.Fonts.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(label)
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = code
            } label: {
                HStack(spacing: 4) {
                    Text(code)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Theme.Colors.mintGreen)
            }
        }
        .padding(.vertical, 12)
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
