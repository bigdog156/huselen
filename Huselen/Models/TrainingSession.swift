import Foundation

@Observable
final class TrainingGymSession: Identifiable, Equatable {
    var id: UUID = UUID()
    var scheduledDate: Date = Date()
    var duration: Int = 60
    var isCompleted: Bool = false
    var isCheckedIn: Bool = false
    var checkInTime: Date? = nil
    var checkOutTime: Date? = nil
    var notes: String = ""
    var purchaseID: UUID? = nil
    var isAbsent: Bool = false
    var absenceReason: String = ""
    var absencePhotoURL: String? = nil
    var clientCheckInPhotoURL: String? = nil
    var createdAt: Date = Date()

    var trainer: Trainer?
    var client: Client?

    init(trainer: Trainer, client: Client, scheduledDate: Date, duration: Int = 60, purchaseID: UUID? = nil) {
        self.trainer = trainer
        self.client = client
        self.scheduledDate = scheduledDate
        self.duration = duration
        self.purchaseID = purchaseID
        self.isCompleted = false
        self.isCheckedIn = false
        self.notes = ""
        self.createdAt = Date()
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: duration, to: scheduledDate) ?? scheduledDate
    }

    func conflicts(with other: TrainingGymSession) -> Bool {
        guard other.id != self.id else { return false }
        return scheduledDate < other.endDate && endDate > other.scheduledDate
    }

    static func == (lhs: TrainingGymSession, rhs: TrainingGymSession) -> Bool {
        lhs.id == rhs.id
    }
}
