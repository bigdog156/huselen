import Foundation

@Observable
final class Trainer: Identifiable, Equatable {
    var id: UUID = UUID()
    var profileId: UUID?
    var name: String = ""
    var phone: String = ""
    var specialization: String = ""
    var experienceYears: Int = 0
    var bio: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    var sessions: [TrainingGymSession] = []
    var purchases: [PackagePurchase] = []

    init(name: String, phone: String = "", specialization: String = "", experienceYears: Int = 0, bio: String = "", isActive: Bool = true, profileId: UUID? = nil) {
        self.profileId = profileId
        self.name = name
        self.phone = phone
        self.specialization = specialization
        self.experienceYears = experienceYears
        self.bio = bio
        self.isActive = isActive
        self.createdAt = Date()
    }

    var completedSessionsCount: Int {
        sessions.filter { $0.isCompleted }.count
    }

    var totalRevenue: Double {
        purchases.reduce(0) { $0 + $1.price }
    }

    static func == (lhs: Trainer, rhs: Trainer) -> Bool {
        lhs.id == rhs.id
    }
}
