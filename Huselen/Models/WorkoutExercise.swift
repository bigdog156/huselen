import Foundation

// MARK: - ExerciseEntry (in-memory model)

struct ExerciseEntry: Identifiable {
    var id: String = UUID().uuidString
    var exerciseName: String
    var sets: Int
    var reps: Int
    var weightKg: Double?   // nil = bodyweight
    var notes: String
    var orderIndex: Int

    init(exerciseName: String, sets: Int = 3, reps: Int = 10, weightKg: Double? = nil, notes: String = "", orderIndex: Int = 0) {
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weightKg = weightKg
        self.notes = notes
        self.orderIndex = orderIndex
    }

    /// "3 × 12 × 60kg"  or  "3 × 30" (no weight)
    var summary: String {
        if let w = weightKg, w > 0 {
            let wStr = w.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", w)
                : String(format: "%.1f", w)
            return "\(sets) × \(reps) × \(wStr)kg"
        }
        return "\(sets) × \(reps)"
    }
}

// MARK: - Supabase DTO

struct WorkoutExerciseDTO: Codable {
    var id: String?
    var sessionId: String
    var ownerId: String
    var trainerId: String?
    var clientId: String?
    var exerciseName: String
    var sets: Int
    var reps: Int
    var weightKg: Double?
    var notes: String
    var orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId   = "session_id"
        case ownerId     = "owner_id"
        case trainerId   = "trainer_id"
        case clientId    = "client_id"
        case exerciseName = "exercise_name"
        case sets, reps
        case weightKg    = "weight_kg"
        case notes
        case orderIndex  = "order_index"
    }

    func toEntry() -> ExerciseEntry {
        var e = ExerciseEntry(
            exerciseName: exerciseName,
            sets: sets,
            reps: reps,
            weightKg: weightKg,
            notes: notes,
            orderIndex: orderIndex
        )
        e.id = id ?? UUID().uuidString
        return e
    }
}

// MARK: - Common exercises list (Vietnamese names + English)

struct CommonExercise: Identifiable {
    let id = UUID()
    let name: String
    let icon: String

    static let all: [CommonExercise] = [
        CommonExercise(name: "Squat",           icon: "figure.strengthtraining.functional"),
        CommonExercise(name: "Deadlift",         icon: "figure.strengthtraining.traditional"),
        CommonExercise(name: "Bench Press",      icon: "figure.arms.open"),
        CommonExercise(name: "Pull-up",          icon: "figure.climbing"),
        CommonExercise(name: "Push-up",          icon: "figure.core.training"),
        CommonExercise(name: "Plank",            icon: "figure.mind.and.body"),
        CommonExercise(name: "Lunge",            icon: "figure.walk"),
        CommonExercise(name: "Row",              icon: "figure.rowing"),
        CommonExercise(name: "Shoulder Press",   icon: "figure.boxing"),
        CommonExercise(name: "Bicep Curl",       icon: "dumbbell.fill"),
        CommonExercise(name: "Tricep Dip",       icon: "dumbbell.fill"),
        CommonExercise(name: "Leg Press",        icon: "figure.strengthtraining.functional"),
        CommonExercise(name: "Lat Pulldown",     icon: "figure.climbing"),
        CommonExercise(name: "Cable Fly",        icon: "figure.arms.open"),
        CommonExercise(name: "Hip Thrust",       icon: "figure.core.training"),
        CommonExercise(name: "Romanian Deadlift",icon: "figure.strengthtraining.traditional"),
        CommonExercise(name: "Leg Curl",         icon: "figure.strengthtraining.functional"),
        CommonExercise(name: "Calf Raise",       icon: "figure.walk"),
        CommonExercise(name: "Face Pull",        icon: "figure.boxing"),
        CommonExercise(name: "Burpee",           icon: "figure.run"),
    ]
}
