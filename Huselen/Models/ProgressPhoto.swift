//
//  ProgressPhoto.swift
//  Huselen
//
//  Progress photo record — tracks body transformation over time.
//

import Foundation

struct ProgressPhoto: Codable, Identifiable {
    var id: String
    var userId: String
    var photoUrl: String
    var note: String
    var category: PhotoCategory
    var takenAt: Date
    var createdAt: Date

    enum PhotoCategory: String, Codable, CaseIterable, Identifiable {
        case front = "front"
        case side = "side"
        case back = "back"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .front: return "Mặt trước"
            case .side:  return "Mặt bên"
            case .back:  return "Mặt sau"
            }
        }

        var icon: String {
            switch self {
            case .front: return "person.fill"
            case .side:  return "person.fill.turn.right"
            case .back:  return "person.fill.turn.left"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case photoUrl = "photo_url"
        case note
        case category
        case takenAt = "taken_at"
        case createdAt = "created_at"
    }

    // MARK: - Decoder

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        userId = try c.decode(String.self, forKey: .userId)
        photoUrl = try c.decode(String.self, forKey: .photoUrl)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        category = try c.decodeIfPresent(PhotoCategory.self, forKey: .category) ?? .front

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let takenAtStr = try c.decode(String.self, forKey: .takenAt)
        takenAt = isoFormatter.date(from: takenAtStr)
            ?? ISO8601DateFormatter().date(from: takenAtStr)
            ?? Date()

        let createdAtStr = try c.decodeIfPresent(String.self, forKey: .createdAt)
        createdAt = createdAtStr.flatMap { isoFormatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) } ?? Date()
    }

    // MARK: - Encoder (omit id so Postgres generates it)

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        try c.encode(photoUrl, forKey: .photoUrl)
        try c.encode(note, forKey: .note)
        try c.encode(category, forKey: .category)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try c.encode(isoFormatter.string(from: takenAt), forKey: .takenAt)
    }

    // MARK: - Init

    init(userId: String, photoUrl: String, note: String = "", category: PhotoCategory = .front, takenAt: Date = Date()) {
        self.id = UUID().uuidString
        self.userId = userId
        self.photoUrl = photoUrl
        self.note = note
        self.category = category
        self.takenAt = takenAt
        self.createdAt = Date()
    }
}
