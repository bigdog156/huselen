import Foundation

@Observable
final class Trainer: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var profileId: UUID?
    var name: String = ""
    var phone: String = ""
    var specialization: String = ""
    var experienceYears: Int = 0
    var bio: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()
    var revenueMode: RevenueMode = .perPackage
    var sessionRateType: SessionRateType = .fixed
    var sessionRate: Double = 0
    var sessionRatePercent: Double = 0
    var branchId: UUID?
    var branch: GymBranch?

    var sessions: [TrainingGymSession] = []
    var purchases: [PackagePurchase] = []

    enum RevenueMode: String, CaseIterable, Codable {
        case perPackage = "per_package"
        case perSession = "per_session"

        var label: String {
            switch self {
            case .perPackage: return "Theo gói"
            case .perSession: return "Theo buổi"
            }
        }
    }

    enum SessionRateType: String, CaseIterable, Codable {
        case fixed = "fixed"
        case percent = "percent"

        var label: String {
            switch self {
            case .fixed: return "Số tiền cố định"
            case .percent: return "% giá gói / số buổi"
            }
        }
    }

    init(name: String, phone: String = "", specialization: String = "", experienceYears: Int = 0, bio: String = "", isActive: Bool = true, profileId: UUID? = nil, revenueMode: RevenueMode = .perPackage, sessionRateType: SessionRateType = .fixed, sessionRate: Double = 0, sessionRatePercent: Double = 0) {
        self.profileId = profileId
        self.name = name
        self.phone = phone
        self.specialization = specialization
        self.experienceYears = experienceYears
        self.bio = bio
        self.isActive = isActive
        self.createdAt = Date()
        self.revenueMode = revenueMode
        self.sessionRateType = sessionRateType
        self.sessionRate = sessionRate
        self.sessionRatePercent = sessionRatePercent
    }

    var completedSessionsCount: Int {
        sessions.filter { $0.isCompleted }.count
    }

    /// Tính tiền 1 buổi dạy cho 1 session cụ thể
    func rateForSession(_ session: TrainingGymSession) -> Double {
        switch sessionRateType {
        case .fixed:
            return sessionRate
        case .percent:
            // Tìm purchase của session này để lấy giá gói và số buổi
            if let purchase = purchases.first(where: { $0.purchaseID == session.purchaseID }) {
                let perSession = purchase.price / Double(max(1, purchase.totalSessions))
                return perSession * sessionRatePercent / 100.0
            }
            return 0
        }
    }

    var totalRevenue: Double {
        switch revenueMode {
        case .perPackage:
            return purchases.reduce(0) { $0 + $1.price }
        case .perSession:
            let completedSessions = sessions.filter { $0.isCompleted }
            return completedSessions.reduce(0) { $0 + rateForSession($1) }
        }
    }

    func revenueInMonth(_ date: Date) -> Double {
        let calendar = Calendar.current
        switch revenueMode {
        case .perPackage:
            return purchases.filter {
                calendar.isDate($0.purchaseDate, equalTo: date, toGranularity: .month)
            }.reduce(0) { $0 + $1.price }
        case .perSession:
            let monthSessions = sessions.filter {
                $0.isCompleted && calendar.isDate($0.scheduledDate, equalTo: date, toGranularity: .month)
            }
            return monthSessions.reduce(0) { $0 + rateForSession($1) }
        }
    }

    static func == (lhs: Trainer, rhs: Trainer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
