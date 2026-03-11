import Foundation
import Supabase

struct SupabaseConfig {
    // TODO: Replace with your Supabase project credentials
    static let url = URL(string: "https://sklfbonwesqibcsybkxn.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNrbGZib253ZXNxaWJjc3lia3huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwMDI0MDgsImV4cCI6MjA4ODU3ODQwOH0.Z-TFCZdOCVTXHsZRZ4ZZ94rK1Pk2tBvqpLaybUwcCjE"
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions()
)

// MARK: - Profile Search Result

struct ProfileSearchResult: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let phone: String?
    let avatarUrl: String?
    let email: String?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case phone
        case avatarUrl = "avatar_url"
        case email
        case username
    }
}

@Observable
final class ProfileSearchManager {
    var results: [ProfileSearchResult] = []
    var isLoading = false
    var errorMessage: String?

    private let role: String

    init(role: String) {
        self.role = role
    }

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let q = query.trimmingCharacters(in: .whitespaces)
            let profiles: [ProfileSearchResult] = try await supabase
                .from("profiles")
                .select("id, full_name, phone, avatar_url, email, username")
                .eq("role", value: role)
                .or("full_name.ilike.%25\(q)%25,email.ilike.%25\(q)%25,username.ilike.%25\(q)%25")
                .limit(20)
                .execute()
                .value

            results = profiles
        } catch {
            errorMessage = "Không thể tìm kiếm: \(error.localizedDescription)"
            results = []
        }

        isLoading = false
    }

    func fetchAll() async {
        isLoading = true
        errorMessage = nil

        do {
            let profiles: [ProfileSearchResult] = try await supabase
                .from("profiles")
                .select("id, full_name, phone, avatar_url, email, username")
                .eq("role", value: role)
                .order("full_name")
                .limit(50)
                .execute()
                .value

            results = profiles
        } catch {
            errorMessage = "Không thể tải danh sách: \(error.localizedDescription)"
            results = []
        }

        isLoading = false
    }
}

// MARK: - PT Package Sync

struct GymPTPackage: Codable, Identifiable {
    var id: UUID?
    let ownerId: UUID
    var name: String
    var totalSessions: Int
    var price: Double
    var durationDays: Int
    var description: String
    var isActive: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case totalSessions = "total_sessions"
        case price
        case durationDays = "duration_days"
        case description
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

@Observable
final class PackageManager {
    var packages: [GymPTPackage] = []
    var isLoading = false
    var errorMessage: String?

    func fetchPackages() async {
        isLoading = true
        errorMessage = nil

        do {
            let result: [GymPTPackage] = try await supabase
                .from("pt_packages")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            packages = result
        } catch {
            errorMessage = "Không thể tải gói PT: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func createPackage(name: String, totalSessions: Int, price: Double, durationDays: Int, description: String, isActive: Bool) async -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            errorMessage = "Chưa đăng nhập"
            return false
        }

        let pkg = GymPTPackage(
            ownerId: userId,
            name: name,
            totalSessions: totalSessions,
            price: price,
            durationDays: durationDays,
            description: description,
            isActive: isActive
        )

        do {
            try await supabase
                .from("pt_packages")
                .insert(pkg)
                .execute()
            await fetchPackages()
            return true
        } catch {
            errorMessage = "Không thể tạo gói: \(error.localizedDescription)"
            return false
        }
    }

    func updatePackage(id: UUID, name: String, totalSessions: Int, price: Double, durationDays: Int, description: String, isActive: Bool) async -> Bool {
        do {
            try await supabase
                .from("pt_packages")
                .update([
                    "name": AnyJSON.string(name),
                    "total_sessions": AnyJSON.integer(totalSessions),
                    "price": AnyJSON.double(price),
                    "duration_days": AnyJSON.integer(durationDays),
                    "description": AnyJSON.string(description),
                    "is_active": AnyJSON.bool(isActive),
                ])
                .eq("id", value: id.uuidString)
                .execute()
            await fetchPackages()
            return true
        } catch {
            errorMessage = "Không thể cập nhật: \(error.localizedDescription)"
            return false
        }
    }

    func deletePackage(id: UUID) async -> Bool {
        do {
            try await supabase
                .from("pt_packages")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            packages.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = "Không thể xóa: \(error.localizedDescription)"
            return false
        }
    }
}
