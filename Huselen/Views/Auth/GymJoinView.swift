import SwiftUI
import Supabase

struct GymJoinView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var inviteCode = ""
    @State private var searchText = ""
    @State private var searchResults: [GymDTO] = []
    @State private var isSearching = false
    @State private var isJoining = false
    @State private var selectedTab = 0

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
                        Text("Chọn phòng tập")
                            .font(Theme.Fonts.title())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Tham gia phòng tập để bắt đầu 💪")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Tab selector
                    Picker("Phương thức", selection: $selectedTab) {
                        Text("Mã mời").tag(0)
                        Text("Tìm kiếm").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if selectedTab == 0 {
                        inviteCodeSection
                    } else {
                        searchSection
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

    // MARK: - Invite Code Section

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
            }

            Button(action: joinWithCode) {
                if isJoining {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Tham gia 🎉")
                }
            }
            .buttonStyle(CuteButtonStyle(
                color: !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.mintGreen : .gray.opacity(0.4)
            ))
            .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
        }
        .cuteCard()
        .padding(.horizontal)
    }

    // MARK: - Search Section

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
                gymRow(gym)
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

    private func gymRow(_ gym: GymDTO) -> some View {
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

    // MARK: - Actions

    private func joinWithCode() {
        isJoining = true
        Task {
            _ = await authManager.joinGym(inviteCode: inviteCode)
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
