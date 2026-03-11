import Foundation

@Observable
final class Client: Identifiable, Equatable {
    var id: UUID = UUID()
    var profileId: UUID?
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var weight: Double = 0
    var bodyFat: Double = 0
    var muscleMass: Double = 0
    var goal: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    var sessions: [TrainingGymSession] = []
    var purchases: [PackagePurchase] = []

    init(name: String, phone: String = "", email: String = "", weight: Double = 0, bodyFat: Double = 0, muscleMass: Double = 0, goal: String = "", notes: String = "", profileId: UUID? = nil) {
        self.profileId = profileId
        self.name = name
        self.phone = phone
        self.email = email
        self.weight = weight
        self.bodyFat = bodyFat
        self.muscleMass = muscleMass
        self.goal = goal
        self.notes = notes
        self.createdAt = Date()
    }

    var remainingSessions: Int {
        purchases.reduce(0) { total, purchase in
            let used = sessions.filter { $0.isCompleted && $0.purchaseID == purchase.purchaseID }.count
            return total + (purchase.totalSessions - used)
        }
    }

    static func == (lhs: Client, rhs: Client) -> Bool {
        lhs.id == rhs.id
    }
}
