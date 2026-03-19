import Foundation
import Supabase

// MARK: - Supabase DTOs

private struct OwnerIdRow: Codable {
    let ownerId: UUID
    enum CodingKeys: String, CodingKey { case ownerId = "owner_id" }
}

struct GymTrainer: Codable {
    var id: UUID?
    let ownerId: UUID
    var profileId: UUID?
    var name: String
    var phone: String
    var specialization: String
    var experienceYears: Int
    var bio: String
    var isActive: Bool
    var revenueMode: String
    var sessionRateType: String
    var sessionRate: Double
    var sessionRatePercent: Double
    var branchId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case profileId = "profile_id"
        case name, phone, specialization
        case experienceYears = "experience_years"
        case bio
        case isActive = "is_active"
        case revenueMode = "revenue_mode"
        case sessionRateType = "session_rate_type"
        case sessionRate = "session_rate"
        case sessionRatePercent = "session_rate_percent"
        case branchId = "branch_id"
    }
}

struct GymClient: Codable {
    var id: UUID?
    let ownerId: UUID
    var profileId: UUID?
    var name: String
    var phone: String
    var email: String
    var height: Double
    var weight: Double
    var bodyFat: Double
    var muscleMass: Double
    var neck: Double
    var shoulder: Double
    var arm: Double
    var chest: Double
    var waist: Double
    var hip: Double
    var thigh: Double
    var calf: Double
    var lowerHip: Double
    var calorieGoal: Int
    var proteinGoal: Double
    var carbsGoal: Double
    var fatGoal: Double
    var goal: String
    var notes: String
    var branchId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case profileId = "profile_id"
        case name, phone, email, height, weight
        case bodyFat = "body_fat"
        case muscleMass = "muscle_mass"
        case neck, shoulder, arm, chest, waist, hip, thigh, calf
        case lowerHip = "lower_hip"
        case calorieGoal = "calorie_goal"
        case proteinGoal = "protein_goal"
        case carbsGoal = "carbs_goal"
        case fatGoal = "fat_goal"
        case goal, notes
        case branchId = "branch_id"
    }
}

struct GymSession: Codable {
    var id: UUID?
    let ownerId: UUID
    var trainerId: UUID?
    var clientId: UUID?
    var purchaseId: UUID?
    var scheduledDate: Date
    var duration: Int
    var isCompleted: Bool
    var isCheckedIn: Bool
    var checkInTime: Date?
    var checkOutTime: Date?
    var notes: String
    var isAbsent: Bool
    var absenceReason: String
    var absencePhotoUrl: String?
    var clientCheckInPhotoUrl: String?
    var clientCheckInTime: Date?
    var isMakeup: Bool
    var originalSessionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case trainerId = "trainer_id"
        case clientId = "client_id"
        case purchaseId = "purchase_id"
        case scheduledDate = "scheduled_date"
        case duration
        case isCompleted = "is_completed"
        case isCheckedIn = "is_checked_in"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case notes
        case isAbsent = "is_absent"
        case absenceReason = "absence_reason"
        case absencePhotoUrl = "absence_photo_url"
        case clientCheckInPhotoUrl = "client_check_in_photo_url"
        case clientCheckInTime = "client_check_in_time"
        case isMakeup = "is_makeup"
        case originalSessionId = "original_session_id"
    }
}

struct GymPurchase: Codable {
    var id: UUID?
    let ownerId: UUID
    var purchaseId: UUID
    var packageId: UUID?
    var trainerId: UUID?
    var clientId: UUID?
    var price: Double
    var totalSessions: Int
    var purchaseDate: Date
    var expiryDate: Date
    var notes: String
    var scheduleDays: [Int]
    var scheduleHour: Int
    var scheduleMinute: Int

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case purchaseId = "purchase_id"
        case packageId = "package_id"
        case trainerId = "trainer_id"
        case clientId = "client_id"
        case price
        case totalSessions = "total_sessions"
        case purchaseDate = "purchase_date"
        case expiryDate = "expiry_date"
        case notes
        case scheduleDays = "schedule_days"
        case scheduleHour = "schedule_hour"
        case scheduleMinute = "schedule_minute"
    }
}

struct GymAttendance: Codable {
    var id: UUID?
    let ownerId: UUID
    var trainerId: UUID
    var checkInTime: Date
    var checkOutTime: Date?
    var notes: String
    var checkInPhotoUrl: String?
    var checkOutPhotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case trainerId = "trainer_id"
        case checkInTime = "check_in_time"
        case checkOutTime = "check_out_time"
        case notes
        case checkInPhotoUrl = "check_in_photo_url"
        case checkOutPhotoUrl = "check_out_photo_url"
    }
}

struct GymMealEntry: Codable {
    var id: UUID?
    let ownerId: UUID
    var clientId: UUID?
    var name: String
    var description: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var mealType: String
    var date: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case clientId = "client_id"
        case name, description, calories, protein, carbs, fat
        case mealType = "meal_type"
        case date
    }
}

struct GymBranchDTO: Codable {
    var id: UUID?
    let ownerId: UUID
    var name: String
    var address: String
    var phone: String
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name, address, phone
        case isActive = "is_active"
    }
}

// MARK: - DataSyncManager

@MainActor
@Observable
final class DataSyncManager {
    var errorMessage: String?
    var isSyncing = false
    private var lastRole: UserRole = .owner

    // In-memory data store (source of truth is Supabase)
    var trainers: [Trainer] = []
    var clients: [Client] = []
    var sessions: [TrainingGymSession] = []
    var purchases: [PackagePurchase] = []
    var attendances: [TrainerAttendance] = []
    var mealEntries: [MealEntry] = []
    var gymWiFiSSIDs: [String] = []
    var branches: [GymBranch] = []
    var selectedBranchId: UUID?
    var bodyStatLogs: [BodyStatLog] = []
    var progressPhotos: [ProgressPhoto] = []

    func refresh() async {
        await fetchAll(role: lastRole)
    }

    private func ownerId() async throws -> UUID {
        try await supabase.auth.session.user.id
    }

    /// Returns the gym owner's ID for data creation.
    /// For PT role, returns the trainer's owner_id so admin can see the data.
    private func dataOwnerId() async throws -> UUID {
        let userId = try await supabase.auth.session.user.id
        if lastRole == .trainer {
            if let trainer = trainers.first(where: { $0.profileId == userId }),
               let ownerRow: OwnerIdRow = try? await supabase
                .from("trainers")
                .select("owner_id")
                .eq("id", value: trainer.id.uuidString)
                .single()
                .execute()
                .value {
                return ownerRow.ownerId
            }
        }
        return userId
    }

    func clearAll() {
        trainers = []
        clients = []
        sessions = []
        purchases = []
        attendances = []
        mealEntries = []
        branches = []
    }

    // MARK: - Trainer CRUD

    @discardableResult
    func createTrainer(_ trainer: Trainer) async -> Bool {
        do {
            let userId = try await ownerId()
            let dto = GymTrainer(
                ownerId: userId,
                profileId: trainer.profileId,
                name: trainer.name,
                phone: trainer.phone,
                specialization: trainer.specialization,
                experienceYears: trainer.experienceYears,
                bio: trainer.bio,
                isActive: trainer.isActive,
                revenueMode: trainer.revenueMode.rawValue,
                sessionRateType: trainer.sessionRateType.rawValue,
                sessionRate: trainer.sessionRate,
                sessionRatePercent: trainer.sessionRatePercent,
                branchId: trainer.branchId
            )
            let result: GymTrainer = try await supabase
                .from("trainers")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            trainer.id = result.id!
            trainers.append(trainer)
            return true
        } catch {
            errorMessage = "Lỗi tạo trainer: \(error.localizedDescription)"
            return false
        }
    }

    func updateTrainer(_ trainer: Trainer) async {
        do {
            try await supabase
                .from("trainers")
                .update([
                    "name": AnyJSON.string(trainer.name),
                    "phone": AnyJSON.string(trainer.phone),
                    "specialization": AnyJSON.string(trainer.specialization),
                    "experience_years": AnyJSON.integer(trainer.experienceYears),
                    "bio": AnyJSON.string(trainer.bio),
                    "is_active": AnyJSON.bool(trainer.isActive),
                    "revenue_mode": AnyJSON.string(trainer.revenueMode.rawValue),
                    "session_rate_type": AnyJSON.string(trainer.sessionRateType.rawValue),
                    "session_rate": AnyJSON.double(trainer.sessionRate),
                    "session_rate_percent": AnyJSON.double(trainer.sessionRatePercent),
                    "branch_id": trainer.branchId.map { AnyJSON.string($0.uuidString) } ?? .null,
                ])
                .eq("id", value: trainer.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật trainer: \(error.localizedDescription)"
        }
    }

    func deleteTrainer(_ trainer: Trainer) async {
        do {
            try await supabase
                .from("trainers")
                .delete()
                .eq("id", value: trainer.id.uuidString)
                .execute()
            trainers.removeAll { $0.id == trainer.id }
            for session in sessions where session.trainer?.id == trainer.id {
                session.trainer = nil
            }
            for purchase in purchases where purchase.trainer?.id == trainer.id {
                purchase.trainer = nil
            }
        } catch {
            errorMessage = "Lỗi xoá trainer: \(error.localizedDescription)"
        }
    }

    // MARK: - Client CRUD

    @discardableResult
    func createClient(_ client: Client) async -> Bool {
        do {
            let userId = try await ownerId()
            let dto = GymClient(
                ownerId: userId,
                profileId: client.profileId,
                name: client.name,
                phone: client.phone,
                email: client.email,
                height: client.height,
                weight: client.weight,
                bodyFat: client.bodyFat,
                muscleMass: client.muscleMass,
                neck: client.neck,
                shoulder: client.shoulder,
                arm: client.arm,
                chest: client.chest,
                waist: client.waist,
                hip: client.hip,
                thigh: client.thigh,
                calf: client.calf,
                lowerHip: client.lowerHip,
                calorieGoal: client.calorieGoal,
                proteinGoal: client.proteinGoal,
                carbsGoal: client.carbsGoal,
                fatGoal: client.fatGoal,
                goal: client.goal,
                notes: client.notes,
                branchId: client.branchId
            )
            let result: GymClient = try await supabase
                .from("clients")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            client.id = result.id!
            clients.append(client)
            return true
        } catch {
            errorMessage = "Lỗi tạo client: \(error.localizedDescription)"
            return false
        }
    }

    func updateClient(_ client: Client) async {
        do {
            try await supabase
                .from("clients")
                .update([
                    "name": AnyJSON.string(client.name),
                    "phone": AnyJSON.string(client.phone),
                    "email": AnyJSON.string(client.email),
                    "height": AnyJSON.double(client.height),
                    "weight": AnyJSON.double(client.weight),
                    "body_fat": AnyJSON.double(client.bodyFat),
                    "muscle_mass": AnyJSON.double(client.muscleMass),
                    "neck": AnyJSON.double(client.neck),
                    "shoulder": AnyJSON.double(client.shoulder),
                    "arm": AnyJSON.double(client.arm),
                    "chest": AnyJSON.double(client.chest),
                    "waist": AnyJSON.double(client.waist),
                    "hip": AnyJSON.double(client.hip),
                    "thigh": AnyJSON.double(client.thigh),
                    "calf": AnyJSON.double(client.calf),
                    "lower_hip": AnyJSON.double(client.lowerHip),
                    "calorie_goal": AnyJSON.integer(client.calorieGoal),
                    "protein_goal": AnyJSON.double(client.proteinGoal),
                    "carbs_goal": AnyJSON.double(client.carbsGoal),
                    "fat_goal": AnyJSON.double(client.fatGoal),
                    "goal": AnyJSON.string(client.goal),
                    "notes": AnyJSON.string(client.notes),
                    "branch_id": client.branchId.map { AnyJSON.string($0.uuidString) } ?? .null,
                ])
                .eq("id", value: client.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật client: \(error.localizedDescription)"
        }
    }

    // MARK: - Body Stat Logs

    func fetchBodyStatLogs() async {
        do {
            let userId = try await ownerId()
            let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let cutoffStr = fmt.string(from: cutoff)

            let logs: [BodyStatLog] = try await supabase
                .from("body_stat_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_at", value: cutoffStr)
                .order("logged_at", ascending: true)
                .execute()
                .value
            bodyStatLogs = logs
        } catch {
            // Non-critical — leave empty
        }
    }

    func saveBodyStatLog(from client: Client) async {
        do {
            let userId = try await ownerId()
            let log = BodyStatLog(userId: userId.uuidString, loggedAt: Date(), client: client)
            try await supabase
                .from("body_stat_logs")
                .upsert(log, onConflict: "user_id,logged_at")
                .execute()
            let today = Calendar.current.startOfDay(for: Date())
            bodyStatLogs.removeAll { Calendar.current.isDate($0.loggedAt, inSameDayAs: today) }
            bodyStatLogs.append(log)
            bodyStatLogs.sort { $0.loggedAt < $1.loggedAt }
        } catch {
            // Non-critical
        }
    }

    // MARK: - Weekly Meal Logs (from user_meal_logs)

    func fetchWeeklyMealLogs(for dates: [Date]) async -> [UserMealLog] {
        guard let first = dates.first, let last = dates.last else { return [] }
        do {
            let userId = try await ownerId()
            let fmt = DateFormatters.localDateOnly
            let startStr = fmt.string(from: first)
            let endStr = fmt.string(from: last)

            let logs: [UserMealLog] = try await supabase
                .from("user_meal_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("logged_date", value: startStr)
                .lte("logged_date", value: endStr)
                .execute()
                .value
            return logs
        } catch {
            return []
        }
    }

    // MARK: - Progress Photos

    func fetchProgressPhotos() async {
        do {
            let userId = try await ownerId()
            let photos: [ProgressPhoto] = try await supabase
                .from("progress_photos")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("taken_at", ascending: false)
                .execute()
                .value
            progressPhotos = photos
        } catch {
            // Non-critical — leave empty
        }
    }

    @discardableResult
    func saveProgressPhoto(photoData: Data, note: String = "", category: ProgressPhoto.PhotoCategory = .front) async -> Bool {
        do {
            let userId = try await ownerId()
            let path = "progress/\(userId.uuidString)/\(UUID().uuidString).jpg"
            let photoURL = try await uploadAttendancePhoto(photoData, path: path)

            let photo = ProgressPhoto(
                userId: userId.uuidString,
                photoUrl: photoURL,
                note: note,
                category: category
            )
            try await supabase
                .from("progress_photos")
                .insert(photo)
                .execute()

            progressPhotos.insert(photo, at: 0)
            return true
        } catch {
            errorMessage = "Lỗi lưu ảnh tiến trình: \(error.localizedDescription)"
            return false
        }
    }

    func deleteProgressPhoto(_ photo: ProgressPhoto) async {
        do {
            try await supabase
                .from("progress_photos")
                .delete()
                .eq("id", value: photo.id)
                .execute()
            progressPhotos.removeAll { $0.id == photo.id }
        } catch {
            errorMessage = "Lỗi xoá ảnh: \(error.localizedDescription)"
        }
    }

    func deleteClient(_ client: Client) async {
        do {
            try await supabase
                .from("clients")
                .delete()
                .eq("id", value: client.id.uuidString)
                .execute()
            clients.removeAll { $0.id == client.id }
            for session in sessions where session.client?.id == client.id {
                session.client = nil
            }
            for purchase in purchases where purchase.client?.id == client.id {
                purchase.client = nil
            }
        } catch {
            errorMessage = "Lỗi xoá client: \(error.localizedDescription)"
        }
    }

    // MARK: - Session CRUD

    @discardableResult
    func createSession(_ session: TrainingGymSession) async -> Bool {
        do {
            let userId = try await dataOwnerId()
            let dto = GymSession(
                ownerId: userId,
                trainerId: session.trainer?.id,
                clientId: session.client?.id,
                purchaseId: session.purchaseID,
                scheduledDate: session.scheduledDate,
                duration: session.duration,
                isCompleted: session.isCompleted,
                isCheckedIn: session.isCheckedIn,
                checkInTime: session.checkInTime,
                checkOutTime: session.checkOutTime,
                notes: session.notes,
                isAbsent: session.isAbsent,
                absenceReason: session.absenceReason,
                absencePhotoUrl: session.absencePhotoURL,
                clientCheckInPhotoUrl: session.clientCheckInPhotoURL,
                clientCheckInTime: session.clientCheckInTime,
                isMakeup: session.isMakeup,
                originalSessionId: session.originalSessionId
            )
            let result: GymSession = try await supabase
                .from("training_sessions")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            session.id = result.id!
            sessions.append(session)
            session.trainer?.sessions.append(session)
            session.client?.sessions.append(session)
            return true
        } catch {
            errorMessage = "Lỗi tạo session: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func createSessions(_ newSessions: [TrainingGymSession]) async -> Bool {
        do {
            let userId = try await ownerId()
            let dtos = newSessions.map { session in
                GymSession(
                    ownerId: userId,
                    trainerId: session.trainer?.id,
                    clientId: session.client?.id,
                    purchaseId: session.purchaseID,
                    scheduledDate: session.scheduledDate,
                    duration: session.duration,
                    isCompleted: session.isCompleted,
                    isCheckedIn: session.isCheckedIn,
                    checkInTime: session.checkInTime,
                    notes: session.notes,
                    isAbsent: session.isAbsent,
                    absenceReason: session.absenceReason,
                    absencePhotoUrl: session.absencePhotoURL,
                    clientCheckInPhotoUrl: session.clientCheckInPhotoURL,
                    clientCheckInTime: session.clientCheckInTime,
                    isMakeup: session.isMakeup,
                    originalSessionId: session.originalSessionId
                )
            }
            let results: [GymSession] = try await supabase
                .from("training_sessions")
                .insert(dtos)
                .select()
                .execute()
                .value
            for (i, result) in results.enumerated() where i < newSessions.count {
                newSessions[i].id = result.id!
                sessions.append(newSessions[i])
                newSessions[i].trainer?.sessions.append(newSessions[i])
                newSessions[i].client?.sessions.append(newSessions[i])
            }
            return true
        } catch {
            errorMessage = "Lỗi tạo sessions: \(error.localizedDescription)"
            return false
        }
    }

    func updateSession(_ session: TrainingGymSession) async {
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            var updates: [String: AnyJSON] = [
                "scheduled_date": .string(formatter.string(from: session.scheduledDate)),
                "duration": .integer(session.duration),
                "is_completed": .bool(session.isCompleted),
                "is_checked_in": .bool(session.isCheckedIn),
                "notes": .string(session.notes),
                "is_absent": .bool(session.isAbsent),
                "absence_reason": .string(session.absenceReason),
                "is_makeup": .bool(session.isMakeup),
            ]
            if let originalSessionId = session.originalSessionId {
                updates["original_session_id"] = .string(originalSessionId.uuidString)
            }
            if let trainerId = session.trainer?.id {
                updates["trainer_id"] = .string(trainerId.uuidString)
            }
            if let clientId = session.client?.id {
                updates["client_id"] = .string(clientId.uuidString)
            }
            if let purchaseID = session.purchaseID {
                updates["purchase_id"] = .string(purchaseID.uuidString)
            } else {
                updates["purchase_id"] = .null
            }
            if let checkInTime = session.checkInTime {
                updates["check_in_time"] = .string(formatter.string(from: checkInTime))
            }
            if let checkOutTime = session.checkOutTime {
                updates["check_out_time"] = .string(formatter.string(from: checkOutTime))
            }
            if let photoURL = session.absencePhotoURL {
                updates["absence_photo_url"] = .string(photoURL)
            }
            if let clientPhotoURL = session.clientCheckInPhotoURL {
                updates["client_check_in_photo_url"] = .string(clientPhotoURL)
            }
            if let clientCheckInTime = session.clientCheckInTime {
                updates["client_check_in_time"] = .string(formatter.string(from: clientCheckInTime))
            }
            try await supabase
                .from("training_sessions")
                .update(updates)
                .eq("id", value: session.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật session: \(error.localizedDescription)"
        }
    }

    /// Client check-in with photo (Locket-style)
    /// Only updates client_check_in_photo_url and client_check_in_time — does NOT touch PT fields
    func clientCheckIn(session: TrainingGymSession, photoData: Data) async -> Bool {
        do {
            let clientId = session.client?.id.uuidString ?? "unknown"
            let path = "client-checkin/\(clientId)/\(UUID().uuidString).jpg"
            let url = try await uploadAttendancePhoto(photoData, path: path)

            let now = Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            try await supabase
                .from("training_sessions")
                .update([
                    "client_check_in_photo_url": AnyJSON.string(url),
                    "client_check_in_time": AnyJSON.string(formatter.string(from: now)),
                ])
                .eq("id", value: session.id.uuidString)
                .execute()

            session.clientCheckInPhotoURL = url
            session.clientCheckInTime = now
            return true
        } catch {
            errorMessage = "Lỗi check-in: \(error.localizedDescription)"
            return false
        }
    }

    func markAbsent(_ session: TrainingGymSession, reason: String, photoData: Data?) async {
        session.isAbsent = true
        session.absenceReason = reason

        if let data = photoData {
            do {
                let path = "absence/\(session.id.uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
                let url = try await uploadAttendancePhoto(data, path: path)
                session.absencePhotoURL = url
            } catch {
                errorMessage = "Lỗi tải ảnh: \(error.localizedDescription)"
            }
        }

        await updateSession(session)
    }

    func deleteSession(_ session: TrainingGymSession) async {
        do {
            try await supabase
                .from("training_sessions")
                .delete()
                .eq("id", value: session.id.uuidString)
                .execute()
            sessions.removeAll { $0.id == session.id }
            session.trainer?.sessions.removeAll { $0.id == session.id }
            session.client?.sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = "Lỗi xoá session: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase CRUD

    @discardableResult
    func createPurchase(_ purchase: PackagePurchase) async -> Bool {
        do {
            let userId = try await ownerId()
            let dto = GymPurchase(
                ownerId: userId,
                purchaseId: purchase.purchaseID,
                packageId: purchase.package?.id,
                trainerId: purchase.trainer?.id,
                clientId: purchase.client?.id,
                price: purchase.price,
                totalSessions: purchase.totalSessions,
                purchaseDate: purchase.purchaseDate,
                expiryDate: purchase.expiryDate,
                notes: purchase.notes,
                scheduleDays: purchase.scheduleDays,
                scheduleHour: purchase.scheduleHour,
                scheduleMinute: purchase.scheduleMinute
            )
            let result: GymPurchase = try await supabase
                .from("package_purchases")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            purchase.id = result.id!
            purchases.append(purchase)
            purchase.trainer?.purchases.append(purchase)
            purchase.client?.purchases.append(purchase)
            return true
        } catch {
            errorMessage = "Lỗi tạo purchase: \(error.localizedDescription)"
            return false
        }
    }

    func updatePurchase(_ purchase: PackagePurchase) async {
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try await supabase
                .from("package_purchases")
                .update([
                    "price": AnyJSON.double(purchase.price),
                    "total_sessions": AnyJSON.integer(purchase.totalSessions),
                    "expiry_date": AnyJSON.string(formatter.string(from: purchase.expiryDate)),
                    "notes": AnyJSON.string(purchase.notes),
                    "schedule_days": AnyJSON.array(purchase.scheduleDays.map { AnyJSON.integer($0) }),
                    "schedule_hour": AnyJSON.integer(purchase.scheduleHour),
                    "schedule_minute": AnyJSON.integer(purchase.scheduleMinute),
                    "trainer_id": purchase.trainer.map { AnyJSON.string($0.id.uuidString) } ?? .null,
                ])
                .eq("id", value: purchase.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật purchase: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch All from Supabase

    func fetchAll(role: UserRole = .owner) async {
        isSyncing = true
        lastRole = role
        defer { isSyncing = false }

        do {
            let userId = try await ownerId()

            // Fetch trainers
            let remoteTrainers: [GymTrainer]
            if role == .trainer {
                // PT: fetch own trainer record via profile_id
                remoteTrainers = (try? await supabase.from("trainers").select()
                    .eq("profile_id", value: userId.uuidString).execute().value) ?? []
            } else {
                remoteTrainers = try await supabase.from("trainers").select().execute().value
            }
            // Fetch branches
            let remoteBranches: [GymBranchDTO] = (try? await supabase.from("gym_branches").select().execute().value) ?? []
            var newBranches: [GymBranch] = []
            for remote in remoteBranches {
                guard let remoteId = remote.id else { continue }
                if let existing = branches.first(where: { $0.id == remoteId }) {
                    existing.name = remote.name
                    existing.address = remote.address
                    existing.phone = remote.phone
                    existing.isActive = remote.isActive
                    newBranches.append(existing)
                } else {
                    let b = GymBranch(name: remote.name, address: remote.address, phone: remote.phone, isActive: remote.isActive)
                    b.id = remoteId
                    newBranches.append(b)
                }
            }
            let branchById = Dictionary(uniqueKeysWithValues: newBranches.map { ($0.id, $0) })

            var newTrainers: [Trainer] = []
            for remote in remoteTrainers {
                guard let remoteId = remote.id else { continue }
                if let existing = trainers.first(where: { $0.id == remoteId }) {
                    existing.name = remote.name
                    existing.phone = remote.phone
                    existing.specialization = remote.specialization
                    existing.experienceYears = remote.experienceYears
                    existing.bio = remote.bio
                    existing.isActive = remote.isActive
                    existing.profileId = remote.profileId
                    existing.revenueMode = Trainer.RevenueMode(rawValue: remote.revenueMode) ?? .perPackage
                    existing.sessionRateType = Trainer.SessionRateType(rawValue: remote.sessionRateType) ?? .fixed
                    existing.sessionRate = remote.sessionRate
                    existing.sessionRatePercent = remote.sessionRatePercent
                    existing.branchId = remote.branchId
                    existing.branch = remote.branchId.flatMap { branchById[$0] }
                    newTrainers.append(existing)
                } else {
                    let t = Trainer(name: remote.name, phone: remote.phone, specialization: remote.specialization, experienceYears: remote.experienceYears, bio: remote.bio, isActive: remote.isActive, profileId: remote.profileId, revenueMode: Trainer.RevenueMode(rawValue: remote.revenueMode) ?? .perPackage, sessionRateType: Trainer.SessionRateType(rawValue: remote.sessionRateType) ?? .fixed, sessionRate: remote.sessionRate, sessionRatePercent: remote.sessionRatePercent)
                    t.id = remoteId
                    t.branchId = remote.branchId
                    t.branch = remote.branchId.flatMap { branchById[$0] }
                    newTrainers.append(t)
                }
            }

            // For PT: also fetch clients linked to their sessions
            let remoteClients: [GymClient]
            if role == .trainer, let trainerId = newTrainers.first?.id {
                // Get client IDs from trainer's sessions first
                let trainerSessions: [GymSession] = (try? await supabase.from("training_sessions").select()
                    .eq("trainer_id", value: trainerId.uuidString).execute().value) ?? []
                let clientIds = Set(trainerSessions.compactMap { $0.clientId })
                if clientIds.isEmpty {
                    remoteClients = []
                } else {
                    remoteClients = (try? await supabase.from("clients").select()
                        .in("id", values: clientIds.map { $0.uuidString }).execute().value) ?? []
                }
            } else {
                remoteClients = try await supabase.from("clients").select().execute().value
            }
            var newClients: [Client] = []
            for remote in remoteClients {
                guard let remoteId = remote.id else { continue }
                if let existing = clients.first(where: { $0.id == remoteId }) {
                    existing.name = remote.name
                    existing.phone = remote.phone
                    existing.email = remote.email
                    existing.height = remote.height
                    existing.weight = remote.weight
                    existing.bodyFat = remote.bodyFat
                    existing.muscleMass = remote.muscleMass
                    existing.neck = remote.neck
                    existing.shoulder = remote.shoulder
                    existing.arm = remote.arm
                    existing.chest = remote.chest
                    existing.waist = remote.waist
                    existing.hip = remote.hip
                    existing.thigh = remote.thigh
                    existing.calf = remote.calf
                    existing.lowerHip = remote.lowerHip
                    existing.calorieGoal = remote.calorieGoal
                    existing.proteinGoal = remote.proteinGoal
                    existing.carbsGoal = remote.carbsGoal
                    existing.fatGoal = remote.fatGoal
                    existing.goal = remote.goal
                    existing.notes = remote.notes
                    existing.profileId = remote.profileId
                    existing.branchId = remote.branchId
                    existing.branch = remote.branchId.flatMap { branchById[$0] }
                    newClients.append(existing)
                } else {
                    let c = Client(name: remote.name, phone: remote.phone, email: remote.email, height: remote.height, weight: remote.weight, bodyFat: remote.bodyFat, muscleMass: remote.muscleMass, neck: remote.neck, shoulder: remote.shoulder, arm: remote.arm, chest: remote.chest, waist: remote.waist, hip: remote.hip, thigh: remote.thigh, calf: remote.calf, lowerHip: remote.lowerHip, calorieGoal: remote.calorieGoal, proteinGoal: remote.proteinGoal, carbsGoal: remote.carbsGoal, fatGoal: remote.fatGoal, goal: remote.goal, notes: remote.notes, profileId: remote.profileId)
                    c.id = remoteId
                    c.branchId = remote.branchId
                    c.branch = remote.branchId.flatMap { branchById[$0] }
                    newClients.append(c)
                }
            }

            // Build lookup dictionaries
            let trainerById = Dictionary(uniqueKeysWithValues: newTrainers.map { ($0.id, $0) })
            let clientById = Dictionary(uniqueKeysWithValues: newClients.map { ($0.id, $0) })

            // Fetch packages for name lookup (use try? for non-owner roles)
            let remotePackages: [GymPTPackage] = (try? await supabase.from("pt_packages").select().execute().value) ?? []
            let packageById = Dictionary(uniqueKeysWithValues: remotePackages.compactMap { pkg -> (UUID, GymPTPackage)? in
                guard let id = pkg.id else { return nil }
                return (id, pkg)
            })

            // Fetch purchases
            let remotePurchases: [GymPurchase]
            if role == .trainer, let trainerId = newTrainers.first?.id {
                remotePurchases = (try? await supabase.from("package_purchases").select()
                    .eq("trainer_id", value: trainerId.uuidString).execute().value) ?? []
            } else {
                remotePurchases = try await supabase.from("package_purchases").select().execute().value
            }
            var newPurchases: [PackagePurchase] = []
            for remote in remotePurchases {
                guard let remoteId = remote.id else { continue }
                if let existing = purchases.first(where: { $0.id == remoteId }) {
                    existing.price = remote.price
                    existing.totalSessions = remote.totalSessions
                    existing.purchaseDate = remote.purchaseDate
                    existing.expiryDate = remote.expiryDate
                    existing.notes = remote.notes
                    existing.scheduleDays = remote.scheduleDays
                    existing.scheduleHour = remote.scheduleHour
                    existing.scheduleMinute = remote.scheduleMinute
                    if let tid = remote.trainerId { existing.trainer = trainerById[tid] }
                    if let cid = remote.clientId { existing.client = clientById[cid] }
                    // Update package from pt_packages
                    if let pkgId = remote.packageId, let remotePkg = packageById[pkgId] {
                        if let existingPkg = existing.package {
                            existingPkg.name = remotePkg.name
                        } else {
                            let pkg = PTPackage(name: remotePkg.name, totalSessions: remote.totalSessions, price: remote.price)
                            pkg.id = pkgId
                            existing.package = pkg
                        }
                    }
                    newPurchases.append(existing)
                } else {
                    let pkgName = remote.packageId.flatMap { packageById[$0]?.name } ?? "Gói tập"
                    let pkg = PTPackage(name: pkgName, totalSessions: remote.totalSessions, price: remote.price)
                    if let pkgId = remote.packageId { pkg.id = pkgId }

                    let trainer = remote.trainerId.flatMap { trainerById[$0] }
                    let client = remote.clientId.flatMap { clientById[$0] }

                    let purchase = PackagePurchase(
                        package: pkg,
                        client: client ?? Client(name: "Unknown"),
                        trainer: trainer ?? Trainer(name: "Unknown"),
                        price: remote.price,
                        scheduleDays: remote.scheduleDays,
                        scheduleHour: remote.scheduleHour,
                        scheduleMinute: remote.scheduleMinute
                    )
                    purchase.id = remoteId
                    purchase.purchaseID = remote.purchaseId
                    purchase.purchaseDate = remote.purchaseDate
                    purchase.expiryDate = remote.expiryDate
                    purchase.notes = remote.notes
                    newPurchases.append(purchase)
                }
            }

            // Fetch sessions
            let remoteSessions: [GymSession] = try await supabase.from("training_sessions").select().execute().value
            var newSessions: [TrainingGymSession] = []
            for remote in remoteSessions {
                guard let remoteId = remote.id else { continue }
                if let existing = sessions.first(where: { $0.id == remoteId }) {
                    existing.scheduledDate = remote.scheduledDate
                    existing.duration = remote.duration
                    existing.isCompleted = remote.isCompleted
                    existing.isCheckedIn = remote.isCheckedIn
                    existing.checkInTime = remote.checkInTime
                    existing.checkOutTime = remote.checkOutTime
                    existing.notes = remote.notes
                    existing.purchaseID = remote.purchaseId
                    existing.isAbsent = remote.isAbsent
                    existing.absenceReason = remote.absenceReason
                    existing.absencePhotoURL = remote.absencePhotoUrl
                    existing.clientCheckInPhotoURL = remote.clientCheckInPhotoUrl
                    existing.clientCheckInTime = remote.clientCheckInTime
                    existing.isMakeup = remote.isMakeup
                    existing.originalSessionId = remote.originalSessionId
                    if let tid = remote.trainerId { existing.trainer = trainerById[tid] }
                    if let cid = remote.clientId { existing.client = clientById[cid] }
                    newSessions.append(existing)
                } else {
                    let trainer = remote.trainerId.flatMap { trainerById[$0] } ?? Trainer(name: "Unknown")
                    let client = remote.clientId.flatMap { clientById[$0] } ?? Client(name: "Unknown")
                    let session = TrainingGymSession(
                        trainer: trainer,
                        client: client,
                        scheduledDate: remote.scheduledDate,
                        duration: remote.duration,
                        purchaseID: remote.purchaseId
                    )
                    session.id = remoteId
                    session.isCompleted = remote.isCompleted
                    session.isCheckedIn = remote.isCheckedIn
                    session.checkInTime = remote.checkInTime
                    session.checkOutTime = remote.checkOutTime
                    session.notes = remote.notes
                    session.isAbsent = remote.isAbsent
                    session.absenceReason = remote.absenceReason
                    session.absencePhotoURL = remote.absencePhotoUrl
                    session.clientCheckInPhotoURL = remote.clientCheckInPhotoUrl
                    session.clientCheckInTime = remote.clientCheckInTime
                    session.isMakeup = remote.isMakeup
                    session.originalSessionId = remote.originalSessionId
                    newSessions.append(session)
                }
            }

            // Set up relationship arrays
            for t in newTrainers {
                t.sessions = newSessions.filter { $0.trainer?.id == t.id }
                t.purchases = newPurchases.filter { $0.trainer?.id == t.id }
            }
            for c in newClients {
                c.sessions = newSessions.filter { $0.client?.id == c.id }
                c.purchases = newPurchases.filter { $0.client?.id == c.id }
            }

            // Fetch attendance (use try? to avoid failing the entire fetch)
            let remoteAttendances: [GymAttendance]
            if role == .trainer, let trainerId = newTrainers.first?.id {
                remoteAttendances = (try? await supabase.from("trainer_attendance").select()
                    .eq("trainer_id", value: trainerId.uuidString).execute().value) ?? []
            } else {
                remoteAttendances = (try? await supabase.from("trainer_attendance").select().execute().value) ?? []
            }
            var newAttendances: [TrainerAttendance] = []
            for remote in remoteAttendances {
                guard let remoteId = remote.id else { continue }
                if let existing = attendances.first(where: { $0.id == remoteId }) {
                    existing.checkInTime = remote.checkInTime
                    existing.checkOutTime = remote.checkOutTime
                    existing.notes = remote.notes
                    existing.trainer = trainerById[remote.trainerId]
                    existing.checkInPhotoURL = remote.checkInPhotoUrl
                    existing.checkOutPhotoURL = remote.checkOutPhotoUrl
                    newAttendances.append(existing)
                } else {
                    let a = TrainerAttendance(
                        trainer: trainerById[remote.trainerId] ?? Trainer(name: "Unknown"),
                        checkInTime: remote.checkInTime,
                        notes: remote.notes
                    )
                    a.id = remoteId
                    a.checkOutTime = remote.checkOutTime
                    a.checkInPhotoURL = remote.checkInPhotoUrl
                    a.checkOutPhotoURL = remote.checkOutPhotoUrl
                    newAttendances.append(a)
                }
            }

            // Fetch meal entries
            let remoteMeals: [GymMealEntry]
            if role == .client {
                let clientId = newClients.first?.id
                if let cid = clientId {
                    remoteMeals = (try? await supabase.from("meal_entries").select()
                        .eq("client_id", value: cid.uuidString).execute().value) ?? []
                } else {
                    remoteMeals = []
                }
            } else {
                remoteMeals = (try? await supabase.from("meal_entries").select().execute().value) ?? []
            }
            var newMeals: [MealEntry] = []
            for remote in remoteMeals {
                guard let remoteId = remote.id else { continue }
                var entry = MealEntry(
                    clientId: remote.clientId,
                    name: remote.name,
                    description: remote.description,
                    calories: remote.calories,
                    protein: remote.protein,
                    carbs: remote.carbs,
                    fat: remote.fat,
                    mealType: MealEntry.MealType(rawValue: remote.mealType) ?? .breakfast,
                    date: remote.date
                )
                entry.id = remoteId
                newMeals.append(entry)
            }

            // Update arrays
            branches = newBranches
            trainers = newTrainers
            clients = newClients
            purchases = newPurchases
            sessions = newSessions
            attendances = newAttendances
            mealEntries = newMeals

        } catch {
            print("fetchAll error: \(error)")
            if "\(error)".contains("Auth") || "\(error)".contains("session") {
                errorMessage = "Chưa đăng nhập"
            } else {
                errorMessage = "Lỗi tải dữ liệu: \(error.localizedDescription)"
            }
        }

        await fetchGymWiFiSSIDs()
    }

    // MARK: - Meal Entry CRUD

    @discardableResult
    func createMealEntry(_ entry: MealEntry) async -> Bool {
        do {
            let userId = try await dataOwnerId()
            let dto = GymMealEntry(
                ownerId: userId,
                clientId: entry.clientId,
                name: entry.name,
                description: entry.description,
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat,
                mealType: entry.mealType.rawValue,
                date: entry.date
            )
            let result: GymMealEntry = try await supabase
                .from("meal_entries")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            var saved = entry
            saved.id = result.id!
            mealEntries.append(saved)
            return true
        } catch {
            errorMessage = "Lỗi lưu bữa ăn: \(error.localizedDescription)"
            return false
        }
    }

    func deleteMealEntry(_ entry: MealEntry) async {
        do {
            try await supabase
                .from("meal_entries")
                .delete()
                .eq("id", value: entry.id.uuidString)
                .execute()
            mealEntries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = "Lỗi xoá bữa ăn: \(error.localizedDescription)"
        }
    }

    // MARK: - Branch CRUD

    @discardableResult
    func createBranch(_ branch: GymBranch) async -> Bool {
        do {
            let userId = try await ownerId()
            let dto = GymBranchDTO(
                ownerId: userId,
                name: branch.name,
                address: branch.address,
                phone: branch.phone,
                isActive: branch.isActive
            )
            let result: GymBranchDTO = try await supabase
                .from("gym_branches")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            branch.id = result.id!
            branches.append(branch)
            return true
        } catch {
            errorMessage = "Lỗi tạo cơ sở: \(error.localizedDescription)"
            return false
        }
    }

    func updateBranch(_ branch: GymBranch) async {
        do {
            try await supabase
                .from("gym_branches")
                .update([
                    "name": AnyJSON.string(branch.name),
                    "address": AnyJSON.string(branch.address),
                    "phone": AnyJSON.string(branch.phone),
                    "is_active": AnyJSON.bool(branch.isActive),
                ])
                .eq("id", value: branch.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật cơ sở: \(error.localizedDescription)"
        }
    }

    func deleteBranch(_ branch: GymBranch) async {
        do {
            try await supabase
                .from("gym_branches")
                .delete()
                .eq("id", value: branch.id.uuidString)
                .execute()
            branches.removeAll { $0.id == branch.id }
            for trainer in trainers where trainer.branchId == branch.id {
                trainer.branchId = nil
                trainer.branch = nil
            }
            for client in clients where client.branchId == branch.id {
                client.branchId = nil
                client.branch = nil
            }
        } catch {
            errorMessage = "Lỗi xoá cơ sở: \(error.localizedDescription)"
        }
    }

    // MARK: - Gym Settings

    func fetchGymWiFiSSIDs() async {
        struct GymSettings: Codable {
            let wifiSsids: [String]
            enum CodingKeys: String, CodingKey {
                case wifiSsids = "wifi_ssids"
            }
        }

        do {
            let userId = try await ownerId()

            // Try direct lookup first (for owners)
            if let settings: GymSettings = try? await supabase
                .from("gym_settings")
                .select("wifi_ssids")
                .eq("owner_id", value: userId.uuidString)
                .single()
                .execute()
                .value {
                gymWiFiSSIDs = settings.wifiSsids
                return
            }

            // For trainers: find their owner's settings
            struct OwnerRow: Codable {
                let ownerId: UUID
                enum CodingKeys: String, CodingKey { case ownerId = "owner_id" }
            }
            if let row: OwnerRow = try? await supabase
                .from("trainers")
                .select("owner_id")
                .eq("profile_id", value: userId.uuidString)
                .single()
                .execute()
                .value,
               let settings: GymSettings = try? await supabase
                .from("gym_settings")
                .select("wifi_ssids")
                .eq("owner_id", value: row.ownerId.uuidString)
                .single()
                .execute()
                .value {
                gymWiFiSSIDs = settings.wifiSsids
            }
        } catch {
            // No settings configured yet
        }
    }

    func saveGymWiFiSSIDs(_ ssids: [String]) async {
        do {
            let userId = try await ownerId()
            let filtered = ssids.filter { !$0.isEmpty }
            try await supabase
                .from("gym_settings")
                .upsert(
                    [
                        "owner_id": AnyJSON.string(userId.uuidString),
                        "wifi_ssids": AnyJSON.array(filtered.map { AnyJSON.string($0) }),
                    ],
                    onConflict: "owner_id"
                )
                .execute()
            gymWiFiSSIDs = filtered
        } catch {
            errorMessage = "Lỗi lưu cài đặt WiFi: \(error.localizedDescription)"
        }
    }

    // MARK: - Attendance CRUD

    func uploadAttendancePhoto(_ imageData: Data, path: String) async throws -> String {
        try await supabase.storage
            .from("attendance-photos")
            .upload(path, data: imageData, options: .init(contentType: "image/jpeg"))

        let publicURL = try supabase.storage
            .from("attendance-photos")
            .getPublicURL(path: path)

        return publicURL.absoluteString
    }

    @discardableResult
    func checkIn(trainer: Trainer, notes: String = "", photoData: Data? = nil) async -> Bool {
        do {
            let userId = try await ownerId()

            // If the current user is the trainer, use the gym owner's ID instead
            var effectiveOwnerId = userId
            if trainer.profileId == userId {
                struct OwnerRow: Codable {
                    let ownerId: UUID
                    enum CodingKeys: String, CodingKey {
                        case ownerId = "owner_id"
                    }
                }
                if let row: OwnerRow = try? await supabase
                    .from("trainers")
                    .select("owner_id")
                    .eq("id", value: trainer.id.uuidString)
                    .single()
                    .execute()
                    .value {
                    effectiveOwnerId = row.ownerId
                }
            }

            // Upload check-in photo
            var photoURL: String?
            if let photoData {
                let path = "checkin/\(trainer.id.uuidString)/\(UUID().uuidString).jpg"
                photoURL = try await uploadAttendancePhoto(photoData, path: path)
            }

            let dto = GymAttendance(
                ownerId: effectiveOwnerId,
                trainerId: trainer.id,
                checkInTime: Date(),
                checkOutTime: nil,
                notes: notes,
                checkInPhotoUrl: photoURL
            )
            let result: GymAttendance = try await supabase
                .from("trainer_attendance")
                .insert(dto)
                .select()
                .single()
                .execute()
                .value
            let attendance = TrainerAttendance(trainer: trainer, checkInTime: result.checkInTime, notes: notes)
            attendance.id = result.id!
            attendance.checkInPhotoURL = photoURL
            attendances.append(attendance)
            return true
        } catch {
            errorMessage = "Lỗi check-in: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func checkOut(_ attendance: TrainerAttendance, photoData: Data? = nil) async -> Bool {
        do {
            let now = Date()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // Upload check-out photo
            var photoURL: String?
            if let photoData, let trainerId = attendance.trainer?.id {
                let path = "checkout/\(trainerId.uuidString)/\(UUID().uuidString).jpg"
                photoURL = try await uploadAttendancePhoto(photoData, path: path)
            }

            var updates: [String: AnyJSON] = [
                "check_out_time": .string(formatter.string(from: now))
            ]
            if let photoURL {
                updates["check_out_photo_url"] = .string(photoURL)
            }

            try await supabase
                .from("trainer_attendance")
                .update(updates)
                .eq("id", value: attendance.id.uuidString)
                .execute()
            attendance.checkOutTime = now
            attendance.checkOutPhotoURL = photoURL
            return true
        } catch {
            errorMessage = "Lỗi check-out: \(error.localizedDescription)"
            return false
        }
    }

    func updateAttendance(_ attendance: TrainerAttendance) async {
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var updates: [String: AnyJSON] = [
                "check_in_time": .string(formatter.string(from: attendance.checkInTime)),
                "notes": .string(attendance.notes),
            ]
            if let checkOut = attendance.checkOutTime {
                updates["check_out_time"] = .string(formatter.string(from: checkOut))
            }
            try await supabase
                .from("trainer_attendance")
                .update(updates)
                .eq("id", value: attendance.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật attendance: \(error.localizedDescription)"
        }
    }

    func deleteAttendance(_ attendance: TrainerAttendance) async {
        do {
            try await supabase
                .from("trainer_attendance")
                .delete()
                .eq("id", value: attendance.id.uuidString)
                .execute()
            attendances.removeAll { $0.id == attendance.id }
        } catch {
            errorMessage = "Lỗi xoá attendance: \(error.localizedDescription)"
        }
    }

    func activeAttendance(for trainer: Trainer) -> TrainerAttendance? {
        attendances.first { $0.trainer?.id == trainer.id && $0.checkOutTime == nil }
    }
}
