import Foundation

enum StreakCalculator {
    /// Calculates the current streak of consecutive days with completed/checked-in sessions.
    /// Checks up to 60 days back from today.
    static func trainingStreak(from sessions: [TrainingGymSession]) -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = Date()
        for _ in 0..<60 {
            let hit = sessions.contains {
                cal.isDate($0.scheduledDate, inSameDayAs: checkDate) &&
                ($0.isCompleted || $0.isCheckedIn || $0.clientCheckInPhotoURL != nil)
            }
            guard hit else { break }
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    /// Number of completed/checked-in sessions in the current month.
    static func sessionsThisMonth(from sessions: [TrainingGymSession]) -> Int {
        let cal = Calendar.current
        return sessions.filter {
            cal.isDate($0.scheduledDate, equalTo: Date(), toGranularity: .month) &&
            ($0.isCompleted || $0.clientCheckInPhotoURL != nil)
        }.count
    }

    /// Number of completed/checked-in sessions in the current week.
    static func sessionsThisWeek(from sessions: [TrainingGymSession]) -> Int {
        let cal = Calendar.current
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return sessions.filter {
            weekInterval.contains($0.scheduledDate) &&
            ($0.clientCheckInPhotoURL != nil || $0.isCompleted)
        }.count
    }
}
