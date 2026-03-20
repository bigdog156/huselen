import SwiftUI
import Supabase

struct GymJoinView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var inviteCode = ""
    @State private var ptInviteCode = ""
    @State private var searchText = ""
    @State private var searchResults: [GymDTO] = []
    @State private var isSearching = false
    @State private var isJoining = false
    @State private var selectedTab = 0

    // Preview state
    @State private var previewGym: GymDTO?
    @State private var previewTrainer: GymTrainer?
    @State private var isLookingUp = false

    private var isClient: Bool { authManager.userRole == .client }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.mintGreen.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Theme.Colors.mintGreen)
                        }
                        Text(isClient ? "Bắt đầu tập luyện" : "Chọn phòng tập")
                            .font(Theme.Fonts.title())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(isClient ? "Tham gia phòng tập hoặc PT tự do" : "Tham gia phòng tập để bắt đầu")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Tab selector
                    Picker("Phương thức", selection: $selectedTab) {
                        Text("Mã mời").tag(0)
                        Text("Tìm kiếm").tag(1)
                        if isClient {
                            Text("PT tự do").tag(2)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selectedTab == 0 {
                        inviteCodeSection
                    } else if selectedTab == 1 {
                        searchSection
                    } else {
                        freelancePTSection
                    }

                    if let error = authManager.errorMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.softPink)
                        .padding(.horizontal)
                    }

                    // Skip button (only for clients)
                    if isClient {
                        VStack(spacing: 8) {
                            Divider()
                                .padding(.horizontal, 40)

                            Button {
                                Task {
                                    isJoining = true
                                    _ = await authManager.skipGymSetup()
                                    isJoining = false
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Text("Bỏ qua, tôi sẽ chọn sau")
                                        .font(Theme.Fonts.subheadline())
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                            .disabled(isJoining)
                        }
                        .padding(.top, 4)
                    }

                    // Sign out option
                    Button {
                        Task { await authManager.signOut() }
                    } label: {
                        Text("Đăng xuất")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Tham gia")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Invite Code Section (Gym)

    private var inviteCodeSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nhập mã mời từ phòng tập")
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.textSecondary)
                TextField("VD: a1b2c3d4", text: $inviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .cuteTextField()
                    .onChange(of: inviteCode) { _, _ in
                        previewGym = nil
                        authManager.errorMessage = nil
                    }
            }

            // Preview gym info
            if let gym = previewGym {
                gymPreviewCard(gym)
            }

            if previewGym != nil {
                // Confirm join
                Button(action: confirmJoinGym) {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Xác nhận tham gia")
                        }
                    }
                }
                .buttonStyle(CuteButtonStyle(color: Theme.Colors.mintGreen))
                .disabled(isJoining)
            } else {
                // Lookup button
                Button(action: lookupGym) {
                    if isLookingUp {
                        ProgressView().tint(.white)
                    } else {
                        Text("Kiểm tra mã mời")
                    }
                }
                .buttonStyle(CuteButtonStyle(
                    color: !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.mintGreen : .gray.opacity(0.4)
                ))
                .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
            }
        }
        .cuteCard()
        .padding(.horizontal)
    }

    // MARK: - Gym Preview Card

    private func gymPreviewCard(_ gym: GymDTO) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Colors.warmYellow.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.Colors.warmYellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(gym.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if !gym.address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                        Text(gym.address)
                            .lineLimit(2)
                    }
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
                if !gym.phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                        Text(gym.phone)
                    }
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.warmYellow.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.Colors.warmYellow.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.3), value: previewGym?.id)
    }

    // MARK: - Search Section (Gym)

    private var searchSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Colors.textSecondary)
                TextField("Tìm phòng tập...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { searchGyms() }
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .cuteTextField()

            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                Text("Không tìm thấy phòng tập")
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.vertical, 20)
            }

            ForEach(searchResults, id: \.id) { gym in
                gymSearchRow(gym)
            }
        }
        .cuteCard()
        .padding(.horizontal)
        .onChange(of: searchText) { _, newValue in
            if newValue.count >= 2 {
                searchGyms()
            } else {
                searchResults = []
            }
        }
    }

    private func gymSearchRow(_ gym: GymDTO) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.warmYellow.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "building.2.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.Colors.warmYellow)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(gym.name)
                    .font(Theme.Fonts.body())
                    .foregroundStyle(Theme.Colors.textPrimary)
                if !gym.address.isEmpty {
                    Text(gym.address)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                if !gym.phone.isEmpty {
                    Text(gym.phone)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            Button {
                joinGymById(gym)
            } label: {
                Text("Tham gia")
                    .font(Theme.Fonts.caption())
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.mintGreen, in: Capsule())
            }
            .disabled(isJoining)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Freelance PT Section (Client only)

    private var freelancePTSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Colors.softOrange)

                Text("Nhập mã mời từ PT tự do")
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Mã PT (VD: ab12cd34)", text: $ptInviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .cuteTextField()
                    .onChange(of: ptInviteCode) { _, _ in
                        previewTrainer = nil
                        authManager.errorMessage = nil
                    }
            }

            // Preview trainer info
            if let trainer = previewTrainer {
                trainerPreviewCard(trainer)
            }

            if previewTrainer != nil {
                // Confirm join
                Button(action: confirmJoinFreelancePT) {
                    if isJoining {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Xác nhận tham gia PT")
                        }
                    }
                }
                .buttonStyle(CuteButtonStyle(color: Theme.Colors.softOrange))
                .disabled(isJoining)
            } else {
                // Lookup button
                Button(action: lookupTrainer) {
                    if isLookingUp {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Kiểm tra mã PT")
                        }
                    }
                }
                .buttonStyle(CuteButtonStyle(
                    color: !ptInviteCode.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.softOrange : .gray.opacity(0.4)
                ))
                .disabled(ptInviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
            }

            Text("PT tự do sẽ cung cấp mã mời để bạn tham gia")
                .font(Theme.Fonts.caption())
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .cuteCard()
        .padding(.horizontal)
    }

    // MARK: - Trainer Preview Card

    private func trainerPreviewCard(_ trainer: GymTrainer) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Colors.softOrange.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.Colors.softOrange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(trainer.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if !trainer.specialization.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                        Text(trainer.specialization)
                    }
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.softOrange)
                }
                if trainer.experienceYears > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text("\(trainer.experienceYears) năm kinh nghiệm")
                    }
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
                if !trainer.phone.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                        Text(trainer.phone)
                    }
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.softOrange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.Colors.softOrange.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.3), value: previewTrainer?.id)
    }

    // MARK: - Actions

    private func lookupGym() {
        let code = inviteCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isLookingUp = true
        authManager.errorMessage = nil
        Task {
            do {
                let result: GymLookupResult = try await supabase
                    .rpc("lookup_gym_by_invite_code", params: ["p_invite_code": code])
                    .execute()
                    .value
                let gym = GymDTO(
                    id: result.id, name: result.name,
                    address: result.address ?? "", phone: result.phone ?? "",
                    logoUrl: result.logoUrl, ownerId: UUID(),
                    inviteCode: nil
                )
                withAnimation { previewGym = gym }
            } catch {
                authManager.errorMessage = "Mã mời không hợp lệ hoặc không tìm thấy phòng tập"
            }
            isLookingUp = false
        }
    }

    private func confirmJoinGym() {
        isJoining = true
        Task {
            _ = await authManager.joinGym(inviteCode: inviteCode)
            isJoining = false
        }
    }

    private func lookupTrainer() {
        let code = ptInviteCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isLookingUp = true
        authManager.errorMessage = nil
        Task {
            do {
                let result: TrainerLookupResult = try await supabase
                    .rpc("lookup_trainer_by_invite_code", params: ["p_invite_code": code])
                    .execute()
                    .value
                let trainer = GymTrainer(
                    id: result.id, ownerId: UUID(), profileId: nil,
                    name: result.name, phone: result.phone ?? "",
                    specialization: result.specialization ?? "",
                    experienceYears: result.experienceYears ?? 0,
                    bio: result.bio ?? "", isActive: true,
                    revenueMode: "per_session", sessionRateType: "fixed",
                    sessionRate: 0, sessionRatePercent: 0,
                    branchId: nil, inviteCode: nil
                )
                withAnimation { previewTrainer = trainer }
            } catch {
                authManager.errorMessage = "Mã PT không hợp lệ hoặc không tìm thấy PT"
            }
            isLookingUp = false
        }
    }

    private func confirmJoinFreelancePT() {
        isJoining = true
        Task {
            _ = await authManager.joinFreelancePT(inviteCode: ptInviteCode)
            isJoining = false
        }
    }

    private func joinGymById(_ gym: GymDTO) {
        guard let gymId = gym.id else { return }
        isJoining = true
        Task {
            _ = await authManager.joinGymById(gymId)
            isJoining = false
        }
    }

    private func searchGyms() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results: [GymDTO] = try await supabase
                    .from("gyms")
                    .select()
                    .ilike("name", pattern: "%\(query)%")
                    .limit(20)
                    .execute()
                    .value
                searchResults = results
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }
}

// MARK: - RPC Response Models

private struct GymLookupResult: Codable {
    let id: UUID
    let name: String
    let address: String?
    let phone: String?
    let logoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, address, phone
        case logoUrl = "logo_url"
    }
}

private struct TrainerLookupResult: Codable {
    let id: UUID
    let name: String
    let phone: String?
    let specialization: String?
    let experienceYears: Int?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case id, name, phone, specialization, bio
        case experienceYears = "experience_years"
    }
}
