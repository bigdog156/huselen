import Foundation
import Supabase
import Auth

enum UserRole: String, Codable {
    case owner
    case trainer
    case client
}

struct UserProfile: Codable {
    let id: UUID
    let fullName: String?
    let phone: String?
    let role: UserRole
    let avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    let gymId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case role
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case gymId = "gym_id"
    }
}

@MainActor @Observable
final class AuthManager {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: User?
    var userProfile: UserProfile?
    var userRole: UserRole = .owner
    var errorMessage: String?
    var currentGym: Gym?

    var needsGymSetup: Bool {
        isAuthenticated && !isLoading && userProfile?.gymId == nil
    }

    private nonisolated(unsafe) var authListenerTask: Task<Void, Never>?

    init() {
        authListenerTask = Task { [weak self] in
            for await (event, session) in supabase.auth.authStateChanges {
                guard let self else { return }
                switch event {
                case .initialSession:
                    if let session {
                        self.currentUser = session.user
                        self.isAuthenticated = true
                        await self.fetchProfile()
                    } else {
                        self.isAuthenticated = false
                        self.currentUser = nil
                        self.userProfile = nil
                    }
                    self.isLoading = false
                case .signedIn:
                    if let session {
                        self.currentUser = session.user
                        self.isAuthenticated = true
                        await self.fetchProfile()
                    }
                    self.isLoading = false
                case .signedOut:
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.userProfile = nil
                    self.userRole = .owner
                    self.currentGym = nil
                    self.isLoading = false
                case .tokenRefreshed:
                    if let session {
                        self.currentUser = session.user
                    }
                default:
                    break
                }
            }
        }
    }

    deinit {
        authListenerTask?.cancel()
    }

    func checkSession() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
            await fetchProfile()
        } catch {
            isAuthenticated = false
            currentUser = nil
            userProfile = nil
        }
        isLoading = false
    }

    func fetchProfile() async {
        guard let userId = currentUser?.id else { return }
        do {
            let profile: UserProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            userProfile = profile
            userRole = profile.role
            // Fetch gym info if user has a gym
            if let gymId = profile.gymId {
                await fetchGym(gymId: gymId)
            } else {
                currentGym = nil
            }
        } catch {
            print("Error fetching profile: \(error)")
            errorMessage = "Lỗi tải thông tin: \(error.localizedDescription)"
        }
    }

    func fetchGym(gymId: UUID) async {
        do {
            let dto: GymDTO = try await supabase
                .from("gyms")
                .select()
                .eq("id", value: gymId.uuidString)
                .single()
                .execute()
                .value
            let gym = Gym(name: dto.name, address: dto.address, phone: dto.phone, ownerId: dto.ownerId, inviteCode: dto.inviteCode ?? "")
            gym.id = dto.id ?? gymId
            gym.logoUrl = dto.logoUrl
            gym.createdAt = dto.createdAt
            currentGym = gym
        } catch {
            print("Error fetching gym: \(error)")
        }
    }

    /// Admin creates a new gym
    func createGym(name: String, address: String, phone: String) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        errorMessage = nil
        do {
            let dto = GymDTO(
                name: name,
                address: address,
                phone: phone,
                ownerId: userId
            )
            let result: GymDTO = try await supabase
                .from("gyms")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            guard let gymId = result.id else { return false }
            // Link profile to the new gym
            try await supabase
                .from("profiles")
                .update(["gym_id": gymId.uuidString])
                .eq("id", value: userId.uuidString)
                .execute()
            await fetchProfile()
            return true
        } catch {
            errorMessage = "Lỗi tạo phòng tập: \(error.localizedDescription)"
            return false
        }
    }

    /// PT/Client joins a gym by invite code
    func joinGym(inviteCode: String) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        errorMessage = nil
        do {
            let gym: GymDTO = try await supabase
                .from("gyms")
                .select()
                .eq("invite_code", value: inviteCode.trimmingCharacters(in: .whitespaces).lowercased())
                .single()
                .execute()
                .value
            guard let gymId = gym.id else { return false }
            // Link profile to gym
            try await supabase
                .from("profiles")
                .update(["gym_id": gymId.uuidString])
                .eq("id", value: userId.uuidString)
                .execute()
            await fetchProfile()
            return true
        } catch {
            errorMessage = "Mã mời không hợp lệ hoặc không tìm thấy phòng tập"
            return false
        }
    }

    /// PT/Client joins a gym by gym ID
    func joinGymById(_ gymId: UUID) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        errorMessage = nil
        do {
            try await supabase
                .from("profiles")
                .update(["gym_id": gymId.uuidString])
                .eq("id", value: userId.uuidString)
                .execute()
            await fetchProfile()
            return true
        } catch {
            errorMessage = "Lỗi tham gia phòng tập: \(error.localizedDescription)"
            return false
        }
    }

    func signUp(email: String, password: String, fullName: String, role: UserRole = .owner) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            currentUser = response.user
            isAuthenticated = response.session != nil
            if isAuthenticated {
                // Update profile role and email
                try await supabase
                    .from("profiles")
                    .update(["role": role.rawValue, "email": email])
                    .eq("id", value: response.user.id.uuidString)
                    .execute()
                await fetchProfile()
            }
        } catch {
            errorMessage = mapError(error)
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            currentUser = session.user
            isAuthenticated = true
            await fetchProfile()
        } catch {
            errorMessage = mapError(error)
        }
        isLoading = false
    }

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            errorMessage = mapError(error)
        }
        isAuthenticated = false
        currentUser = nil
        userProfile = nil
        userRole = .owner
        currentGym = nil
    }

    func uploadAvatar(imageData: Data) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        errorMessage = nil
        do {
            let filePath = "\(userId.uuidString)/avatar.jpg"
            // Upload to Supabase storage
            try await supabase.storage
                .from("avatars")
                .upload(
                    filePath,
                    data: imageData,
                    options: .init(contentType: "image/jpeg", upsert: true)
                )
            // Get public URL
            let publicURL = try supabase.storage
                .from("avatars")
                .getPublicURL(path: filePath)
            // Add cache-busting timestamp
            let avatarUrlString = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
            // Update profile
            try await supabase
                .from("profiles")
                .update(["avatar_url": avatarUrlString])
                .eq("id", value: userId.uuidString)
                .execute()
            await fetchProfile()
            return true
        } catch {
            print("Error uploading avatar: \(error)")
            errorMessage = "Lỗi tải ảnh: \(error.localizedDescription)"
            return false
        }
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            errorMessage = "Đã gửi email đặt lại mật khẩu!"
        } catch {
            errorMessage = mapError(error)
        }
        isLoading = false
    }

    private func mapError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid login") || message.contains("invalid credentials") {
            return "Email hoặc mật khẩu không đúng"
        } else if message.contains("already registered") || message.contains("already been registered") {
            return "Email đã được đăng ký"
        } else if message.contains("password") && message.contains("short") {
            return "Mật khẩu phải có ít nhất 6 ký tự"
        } else if message.contains("network") || message.contains("connection") {
            return "Lỗi kết nối mạng. Vui lòng thử lại"
        } else if message.contains("email") && message.contains("valid") {
            return "Email không hợp lệ"
        }
        return "Đã xảy ra lỗi: \(error.localizedDescription)"
    }
}
