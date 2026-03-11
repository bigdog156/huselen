import Foundation

@Observable
final class PackagePurchase: Identifiable, Equatable {
    var id: UUID = UUID()
    var purchaseID: UUID = UUID()
    var price: Double = 0
    var totalSessions: Int = 0
    var purchaseDate: Date = Date()
    var expiryDate: Date = Date()
    var notes: String = ""
    var scheduleDays: [Int] = []  // 1=CN, 2=T2, 3=T3, 4=T4, 5=T5, 6=T6, 7=T7
    var scheduleHour: Int = 18
    var scheduleMinute: Int = 0

    var trainer: Trainer?
    var client: Client?
    var package: PTPackage?

    init(package: PTPackage, client: Client, trainer: Trainer, price: Double? = nil, scheduleDays: [Int] = [], scheduleHour: Int = 18, scheduleMinute: Int = 0) {
        self.purchaseID = UUID()
        self.package = package
        self.client = client
        self.trainer = trainer
        self.price = price ?? package.price
        self.totalSessions = package.totalSessions
        self.purchaseDate = Date()
        self.expiryDate = Calendar.current.date(byAdding: .day, value: package.durationDays, to: Date()) ?? Date()
        self.notes = ""
        self.scheduleDays = scheduleDays
        self.scheduleHour = scheduleHour
        self.scheduleMinute = scheduleMinute
    }

    var usedSessions: Int {
        client?.sessions.filter { $0.isCompleted && $0.purchaseID == purchaseID }.count ?? 0
    }

    var remainingSessions: Int {
        totalSessions - usedSessions
    }

    var isExpired: Bool {
        Date() > expiryDate
    }

    var isFullyUsed: Bool {
        remainingSessions <= 0
    }

    static func == (lhs: PackagePurchase, rhs: PackagePurchase) -> Bool {
        lhs.id == rhs.id
    }
}
