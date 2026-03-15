import Foundation

// MARK: - Meal Entry

struct MealEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var clientId: UUID?
    var name: String
    var description: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var mealType: MealType
    var date: Date

    enum MealType: String, Codable, CaseIterable {
        case breakfast = "Sáng"
        case lunch = "Trưa"
        case dinner = "Tối"
        case snack = "Phụ"

        var icon: String {
            switch self {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.stars.fill"
            case .snack: return "leaf.fill"
            }
        }
    }
}

// MARK: - Food Item (for search/library)

struct FoodItem: Identifiable {
    let id: String = UUID().uuidString
    let name: String
    let caloriesPer100g: Int
    let proteinPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let emoji: String
}

// MARK: - Popular Foods

extension FoodItem {
    static var popularFoods: [FoodItem] = [
        FoodItem(name: "Chuối", caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, emoji: "🍌"),
        FoodItem(name: "Bơ", caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, emoji: "🥑"),
        FoodItem(name: "Trứng luộc", caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, emoji: "🥚"),
        FoodItem(name: "Ức gà", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, emoji: "🍗"),
        FoodItem(name: "Cơm gạo lứt", caloriesPer100g: 216, proteinPer100g: 5, carbsPer100g: 45, fatPer100g: 1.8, emoji: "🍚"),
        FoodItem(name: "Yến mạch", caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, emoji: "🌾"),
        FoodItem(name: "Sữa chua Hy Lạp", caloriesPer100g: 59, proteinPer100g: 10, carbsPer100g: 3.6, fatPer100g: 0.7, emoji: "🥛"),
        FoodItem(name: "Cá hồi", caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, emoji: "🐟"),
        FoodItem(name: "Khoai lang", caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1, emoji: "🍠"),
        FoodItem(name: "Đậu hũ", caloriesPer100g: 76, proteinPer100g: 8, carbsPer100g: 1.9, fatPer100g: 4.8, emoji: "🧈"),
    ]

    static var recentFoods: [FoodItem] = [
        FoodItem(name: "Yến mạch", caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, emoji: "🌾"),
        FoodItem(name: "Ức gà luộc", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 4, emoji: "🍗"),
        FoodItem(name: "Cơm gạo lứt", caloriesPer100g: 216, proteinPer100g: 5, carbsPer100g: 45, fatPer100g: 1.8, emoji: "🍚"),
    ]
}
