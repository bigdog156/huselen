import Foundation

@Observable
class Gym: Identifiable {
    var id: UUID
    var name: String
    var address: String
    var phone: String
    var logoUrl: String?
    var ownerId: UUID
    var inviteCode: String
    var createdAt: Date?

    init(name: String, address: String = "", phone: String = "", ownerId: UUID = UUID(), inviteCode: String = "") {
        self.id = UUID()
        self.name = name
        self.address = address
        self.phone = phone
        self.ownerId = ownerId
        self.inviteCode = inviteCode
    }
}

// DTO for Supabase
struct GymDTO: Codable {
    var id: UUID?
    var name: String
    var address: String
    var phone: String
    var logoUrl: String?
    var ownerId: UUID
    var inviteCode: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, address, phone
        case logoUrl = "logo_url"
        case ownerId = "owner_id"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
}
