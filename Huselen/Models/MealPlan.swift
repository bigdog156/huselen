import Foundation

// MARK: - Meal Entry

struct MealEntry: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
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

// MARK: - Sample Data

extension MealEntry {
    static var sampleData: [MealEntry] {
        let today = Date()
        return [
            MealEntry(name: "Bữa sáng", description: "Yến mạch, trứng luộc, chuối",
                      calories: 450, protein: 28, carbs: 52, fat: 14,
                      mealType: .breakfast, date: today),
            MealEntry(name: "Bữa trưa", description: "Cơm gạo lứt, ức gà, rau xào",
                      calories: 650, protein: 45, carbs: 85, fat: 18,
                      mealType: .lunch, date: today),
            MealEntry(name: "Bữa tối", description: "Cá hấp gừng, canh rau, đậu hũ",
                      calories: 750, protein: 55, carbs: 72, fat: 22,
                      mealType: .dinner, date: today),
        ]
    }
}

extension FoodItem {
    static var popularFoods: [FoodItem] = [
        FoodItem(name: "Chuối", caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, emoji: "🍌"),
        FoodItem(name: "Bơ", caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, emoji: "🥑"),
        FoodItem(name: "Trứng luộc", caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, emoji: "🥚"),
        FoodItem(name: "Ức gà", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, emoji: "🍗"),
        FoodItem(name: "Cơm gạo lứt", caloriesPer100g: 216, proteinPer100g: 5, carbsPer100g: 45, fatPer100g: 1.8, emoji: "🍚"),
        FoodItem(name: "Yến mạch", caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, emoji: "🌾"),
    ]

    static var recentFoods: [FoodItem] = [
        FoodItem(name: "Yến mạch", caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, emoji: "🌾"),
        FoodItem(name: "Ức gà luộc", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 4, emoji: "🍗"),
        FoodItem(name: "Cơm gạo lứt", caloriesPer100g: 216, proteinPer100g: 5, carbsPer100g: 45, fatPer100g: 1.8, emoji: "🍚"),
    ]
}
