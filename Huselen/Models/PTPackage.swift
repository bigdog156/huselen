import Foundation

@Observable
final class PTPackage: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var totalSessions: Int = 0
    var price: Double = 0
    var durationDays: Int = 30
    var packageDescription: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    var purchases: [PackagePurchase] = []

    init(name: String, totalSessions: Int, price: Double, durationDays: Int = 30, packageDescription: String = "", isActive: Bool = true) {
        self.name = name
        self.totalSessions = totalSessions
        self.price = price
        self.durationDays = durationDays
        self.packageDescription = packageDescription
        self.isActive = isActive
        self.createdAt = Date()
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    static func == (lhs: PTPackage, rhs: PTPackage) -> Bool {
        lhs.id == rhs.id
    }
}
