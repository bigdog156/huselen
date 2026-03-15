import Foundation

@Observable
final class Client: Identifiable, Equatable {
    var id: UUID = UUID()
    var profileId: UUID?
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var height: Double = 0
    var weight: Double = 0
    var bodyFat: Double = 0
    var muscleMass: Double = 0
    var neck: Double = 0
    var shoulder: Double = 0
    var arm: Double = 0
    var chest: Double = 0
    var waist: Double = 0
    var hip: Double = 0
    var thigh: Double = 0
    var calf: Double = 0
    var lowerHip: Double = 0
    var calorieGoal: Int = 2200
    var proteinGoal: Double = 150
    var carbsGoal: Double = 280
    var fatGoal: Double = 70
    var goal: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var branchId: UUID?
    var branch: GymBranch?

    var sessions: [TrainingGymSession] = []
    var purchases: [PackagePurchase] = []

    init(name: String, phone: String = "", email: String = "", height: Double = 0, weight: Double = 0, bodyFat: Double = 0, muscleMass: Double = 0, neck: Double = 0, shoulder: Double = 0, arm: Double = 0, chest: Double = 0, waist: Double = 0, hip: Double = 0, thigh: Double = 0, calf: Double = 0, lowerHip: Double = 0, calorieGoal: Int = 2200, proteinGoal: Double = 150, carbsGoal: Double = 280, fatGoal: Double = 70, goal: String = "", notes: String = "", profileId: UUID? = nil) {
        self.profileId = profileId
        self.name = name
        self.phone = phone
        self.email = email
        self.height = height
        self.weight = weight
        self.bodyFat = bodyFat
        self.muscleMass = muscleMass
        self.neck = neck
        self.shoulder = shoulder
        self.arm = arm
        self.chest = chest
        self.waist = waist
        self.hip = hip
        self.thigh = thigh
        self.calf = calf
        self.lowerHip = lowerHip
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
        self.carbsGoal = carbsGoal
        self.fatGoal = fatGoal
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
