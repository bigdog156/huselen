import Foundation

// MARK: - Meal Comment

struct MealComment: Codable, Identifiable {
    var id: String?
    var mealLogId: String?       // Specific meal log (optional — if nil, comment is on the whole day)
    var clientId: String          // Which client's meals are being reviewed
    var commentDate: Date         // The date of the meal being commented on
    var authorId: String          // Who wrote the comment
    var authorName: String        // Cached display name
    var authorRole: AuthorRole    // pt or admin
    var message: String
    var createdAt: Date?

    enum AuthorRole: String, Codable, CaseIterable {
        case pt = "pt"
        case admin = "admin"

        var displayName: String {
            switch self {
            case .pt: return "HLV"
            case .admin: return "Quản lý"
            }
        }

        // badgeColor is defined in the View layer (CommentBubble)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case mealLogId = "meal_log_id"
        case clientId = "client_id"
        case commentDate = "comment_date"
        case authorId = "author_id"
        case authorName = "author_name"
        case authorRole = "author_role"
        case message
        case createdAt = "created_at"
    }

    // MARK: - Custom Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
        mealLogId = try container.decodeIfPresent(String.self, forKey: .mealLogId)
        clientId = try container.decode(String.self, forKey: .clientId)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorRole = try container.decode(AuthorRole.self, forKey: .authorRole)
        message = try container.decode(String.self, forKey: .message)

        if let dateString = try container.decodeIfPresent(String.self, forKey: .commentDate) {
            commentDate = DateFormatters.localDateOnly.date(from: dateString) ?? Date()
        } else {
            commentDate = Date()
        }

        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = DateFormatters.iso8601.date(from: createdAtString)
        } else {
            createdAt = nil
        }
    }

    // MARK: - Custom Encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(mealLogId, forKey: .mealLogId)
        try container.encode(clientId, forKey: .clientId)
        try container.encode(DateFormatters.localDateOnly.string(from: commentDate), forKey: .commentDate)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(authorRole, forKey: .authorRole)
        try container.encode(message, forKey: .message)
    }

    // MARK: - Init
    init(
        id: String? = nil,
        mealLogId: String? = nil,
        clientId: String,
        commentDate: Date = Date(),
        authorId: String,
        authorName: String,
        authorRole: AuthorRole,
        message: String,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.mealLogId = mealLogId
        self.clientId = clientId
        self.commentDate = commentDate
        self.authorId = authorId
        self.authorName = authorName
        self.authorRole = authorRole
        self.message = message
        self.createdAt = createdAt
    }

    // MARK: - Helpers

    var isForSpecificMeal: Bool { mealLogId != nil }

    var timeAgo: String {
        guard let created = createdAt else { return "" }
        let interval = Date().timeIntervalSince(created)
        if interval < 60 { return "Vừa xong" }
        if interval < 3600 { return "\(Int(interval / 60)) phút trước" }
        if interval < 86400 { return "\(Int(interval / 3600)) giờ trước" }
        return "\(Int(interval / 86400)) ngày trước"
    }
}

