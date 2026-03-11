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
    let fullName: String
    let phone: String
    let role: UserRole
    let avatarUrl: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case role
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

@Observable
final class AuthManager {
    var isAuthenticated = false
    var isLoading = true
    var currentUser: User?
    var userProfile: UserProfile?
    var userRole: UserRole = .owner
    var errorMessage: String?

    init() {
        Task {
            await checkSession()
        }
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
        } catch {
            print("Error fetching profile: \(error)")
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
