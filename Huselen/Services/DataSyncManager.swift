import Foundation
import Supabase

// MARK: - Supabase DTOs

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

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case profileId = "profile_id"
        case name, phone, specialization
        case experienceYears = "experience_years"
        case bio
        case isActive = "is_active"
    }
}

struct GymClient: Codable {
    var id: UUID?
    let ownerId: UUID
    var profileId: UUID?
    var name: String
    var phone: String
    var email: String
    var weight: Double
    var bodyFat: Double
    var muscleMass: Double
    var goal: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case profileId = "profile_id"
        case name, phone, email, weight
        case bodyFat = "body_fat"
        case muscleMass = "muscle_mass"
        case goal, notes
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
    var notes: String

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
        case notes
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

    func refresh() async {
        await fetchAll(role: lastRole)
    }

    private func ownerId() async throws -> UUID {
        try await supabase.auth.session.user.id
    }

    func clearAll() {
        trainers = []
        clients = []
        sessions = []
        purchases = []
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
                isActive: trainer.isActive
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
                weight: client.weight,
                bodyFat: client.bodyFat,
                muscleMass: client.muscleMass,
                goal: client.goal,
                notes: client.notes
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
                    "weight": AnyJSON.double(client.weight),
                    "body_fat": AnyJSON.double(client.bodyFat),
                    "muscle_mass": AnyJSON.double(client.muscleMass),
                    "goal": AnyJSON.string(client.goal),
                    "notes": AnyJSON.string(client.notes),
                ])
                .eq("id", value: client.id.uuidString)
                .execute()
        } catch {
            errorMessage = "Lỗi cập nhật client: \(error.localizedDescription)"
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
            let userId = try await ownerId()
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
                notes: session.notes
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
                    notes: session.notes
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
            var updates: [String: AnyJSON] = [
                "is_completed": .bool(session.isCompleted),
                "is_checked_in": .bool(session.isCheckedIn),
                "notes": .string(session.notes),
            ]
            if let checkInTime = session.checkInTime {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                updates["check_in_time"] = .string(formatter.string(from: checkInTime))
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
            _ = try await ownerId()

            // Fetch trainers
            let remoteTrainers: [GymTrainer] = try await supabase.from("trainers").select().execute().value
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
                    newTrainers.append(existing)
                } else {
                    let t = Trainer(name: remote.name, phone: remote.phone, specialization: remote.specialization, experienceYears: remote.experienceYears, bio: remote.bio, isActive: remote.isActive, profileId: remote.profileId)
                    t.id = remoteId
                    newTrainers.append(t)
                }
            }

            // Fetch clients
            let remoteClients: [GymClient] = try await supabase.from("clients").select().execute().value
            var newClients: [Client] = []
            for remote in remoteClients {
                guard let remoteId = remote.id else { continue }
                if let existing = clients.first(where: { $0.id == remoteId }) {
                    existing.name = remote.name
                    existing.phone = remote.phone
                    existing.email = remote.email
                    existing.weight = remote.weight
                    existing.bodyFat = remote.bodyFat
                    existing.muscleMass = remote.muscleMass
                    existing.goal = remote.goal
                    existing.notes = remote.notes
                    existing.profileId = remote.profileId
                    newClients.append(existing)
                } else {
                    let c = Client(name: remote.name, phone: remote.phone, email: remote.email, weight: remote.weight, bodyFat: remote.bodyFat, muscleMass: remote.muscleMass, goal: remote.goal, notes: remote.notes, profileId: remote.profileId)
                    c.id = remoteId
                    newClients.append(c)
                }
            }

            // Build lookup dictionaries
            let trainerById = Dictionary(uniqueKeysWithValues: newTrainers.map { ($0.id, $0) })
            let clientById = Dictionary(uniqueKeysWithValues: newClients.map { ($0.id, $0) })

            // Fetch purchases
            let remotePurchases: [GymPurchase] = try await supabase.from("package_purchases").select().execute().value
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
                    newPurchases.append(existing)
                } else {
                    let pkg = PTPackage(name: "Gói đã mua", totalSessions: remote.totalSessions, price: remote.price)
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
                    existing.notes = remote.notes
                    existing.purchaseID = remote.purchaseId
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
                    session.notes = remote.notes
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

            // Update arrays
            trainers = newTrainers
            clients = newClients
            purchases = newPurchases
            sessions = newSessions

        } catch {
            errorMessage = "Chưa đăng nhập"
        }
    }
}
