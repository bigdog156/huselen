import Foundation

@Observable
final class TrainerAttendance: Identifiable, Equatable {
    var id: UUID = UUID()
    var checkInTime: Date = Date()
    var checkOutTime: Date? = nil
    var notes: String = ""
    var checkInPhotoURL: String?
    var checkOutPhotoURL: String?

    var trainer: Trainer?

    init(trainer: Trainer, checkInTime: Date = Date(), notes: String = "") {
        self.trainer = trainer
        self.checkInTime = checkInTime
        self.notes = notes
    }

    var isCheckedOut: Bool {
        checkOutTime != nil
    }

    var duration: TimeInterval? {
        guard let out = checkOutTime else { return nil }
        return out.timeIntervalSince(checkInTime)
    }

    var formattedDuration: String {
        guard let duration else { return "Đang làm việc..." }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) phút"
    }

    static func == (lhs: TrainerAttendance, rhs: TrainerAttendance) -> Bool {
        lhs.id == rhs.id
    }
}
