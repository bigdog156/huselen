import Foundation

@Observable
final class GymBranch: Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var address: String = ""
    var phone: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(name: String, address: String = "", phone: String = "", isActive: Bool = true) {
        self.name = name
        self.address = address
        self.phone = phone
        self.isActive = isActive
    }

    static func == (lhs: GymBranch, rhs: GymBranch) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
