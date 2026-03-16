//
//  MealLog.swift
//  HuselenClient
//
//  Created by Le Thach lam on 17/12/25.
//

import Foundation
import SwiftUI

// MARK: - Meal Type
enum MealType: String, CaseIterable, Codable, Identifiable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case afternoon = "afternoon"
    case dinner = "dinner"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .breakfast: return "Bữa Sáng"
        case .lunch: return "Bữa Trưa"
        case .afternoon: return "Bữa Chiều"
        case .dinner: return "Bữa Tối"
        }
    }
    
    var shortName: String {
        switch self {
        case .breakfast: return "Sáng"
        case .lunch: return "Trưa"
        case .afternoon: return "Chiều"
        case .dinner: return "Tối"
        }
    }
    
    var placeholder: String {
        switch self {
        case .breakfast: return "Bữa sáng của bạn thế nào?"
        case .lunch: return "Bữa trưa ngon miệng chứ?"
        case .afternoon: return "Nạp chút năng lượng?"
        case .dinner: return "Bữa tối nhẹ nhàng nhé!"
        }
    }
    
    var photoPlaceholder: String {
        switch self {
        case .breakfast: return "Chụp ảnh bữa sáng"
        case .lunch: return "Chụp ảnh bữa trưa"
        case .afternoon: return "Chụp ảnh bữa chiều"
        case .dinner: return "Chụp ảnh bữa tối"
        }
    }
    
    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .dinner: return "moon.stars.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .afternoon: return .purple
        case .dinner: return .indigo
        }
    }
    
    var isOptional: Bool {
        return self == .dinner
    }
    
    // Order for display
    var order: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .afternoon: return 2
        case .dinner: return 3
        }
    }
}

// MARK: - Meal Feeling
enum MealFeeling: String, CaseIterable, Codable {
    case good = "good"
    case normal = "normal"
    case tired = "tired"
    
    var icon: String {
        switch self {
        case .good: return "face.smiling.fill"
        case .normal: return "bolt.fill"
        case .tired: return "figure.walk"
        }
    }
    
    var displayName: String {
        switch self {
        case .good: return "Tốt"
        case .normal: return "Bình thường"
        case .tired: return "Mệt"
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .normal: return .blue
        case .tired: return .orange
        }
    }
}

// MARK: - User Meal Log
struct UserMealLog: Codable, Identifiable {
    var id: String?
    var userId: String
    var mealType: MealType
    var photoUrl: String?
    var note: String?
    var feeling: MealFeeling?
    var energyLevel: String?
    var loggedDate: Date
    var loggedTime: String?
    var createdAt: Date?
    
    // Nutrition fields
    var calories: Int?
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var fiberG: Double?
    var foodItems: [MealLogFoodItem]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mealType = "meal_type"
        case photoUrl = "photo_url"
        case note
        case feeling
        case energyLevel = "energy_level"
        case loggedDate = "logged_date"
        case loggedTime = "logged_time"
        case createdAt = "created_at"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case fiberG = "fiber_g"
        case foodItems = "food_items"
    }
    
    // MARK: - Formatted Time
    var formattedTime: String {
        if let time = loggedTime {
            // Parse HH:mm:ss format and return HH:mm AM/PM
            let components = time.split(separator: ":")
            if components.count >= 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                let period = hour >= 12 ? "PM" : "AM"
                let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
                return String(format: "%d:%02d %@", displayHour, minute, period)
            }
        }
        return ""
    }
    
    var hasContent: Bool {
        return photoUrl != nil || (note != nil && !note!.isEmpty)
    }
    
    // MARK: - Custom Decoder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        mealType = try container.decode(MealType.self, forKey: .mealType)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        feeling = try container.decodeIfPresent(MealFeeling.self, forKey: .feeling)
        energyLevel = try container.decodeIfPresent(String.self, forKey: .energyLevel)
        loggedTime = try container.decodeIfPresent(String.self, forKey: .loggedTime)
        
        // Nutrition fields
        calories = try container.decodeIfPresent(Int.self, forKey: .calories)
        proteinG = try container.decodeIfPresent(Double.self, forKey: .proteinG)
        carbsG = try container.decodeIfPresent(Double.self, forKey: .carbsG)
        fatG = try container.decodeIfPresent(Double.self, forKey: .fatG)
        fiberG = try container.decodeIfPresent(Double.self, forKey: .fiberG)
        foodItems = try container.decodeIfPresent([MealLogFoodItem].self, forKey: .foodItems)
        
        // Handle logged_date
        if let dateString = try container.decodeIfPresent(String.self, forKey: .loggedDate) {
            loggedDate = DateFormatters.localDateOnly.date(from: dateString) ?? Date()
        } else {
            loggedDate = Date()
        }
        
        // Handle created_at
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
        try container.encode(userId, forKey: .userId)
        try container.encode(mealType, forKey: .mealType)
        try container.encodeIfPresent(photoUrl, forKey: .photoUrl)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(feeling, forKey: .feeling)
        try container.encodeIfPresent(energyLevel, forKey: .energyLevel)
        try container.encode(DateFormatters.localDateOnly.string(from: loggedDate), forKey: .loggedDate)
        try container.encodeIfPresent(loggedTime, forKey: .loggedTime)
        
        // Nutrition fields
        try container.encodeIfPresent(calories, forKey: .calories)
        try container.encodeIfPresent(proteinG, forKey: .proteinG)
        try container.encodeIfPresent(carbsG, forKey: .carbsG)
        try container.encodeIfPresent(fatG, forKey: .fatG)
        try container.encodeIfPresent(fiberG, forKey: .fiberG)
        try container.encodeIfPresent(foodItems, forKey: .foodItems)
    }
    
    // MARK: - Init
    init(
        id: String? = nil,
        userId: String,
        mealType: MealType,
        photoUrl: String? = nil,
        note: String? = nil,
        feeling: MealFeeling? = nil,
        energyLevel: String? = nil,
        loggedDate: Date = Date(),
        loggedTime: String? = nil,
        createdAt: Date? = nil,
        calories: Int? = nil,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        fiberG: Double? = nil,
        foodItems: [MealLogFoodItem]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.mealType = mealType
        self.photoUrl = photoUrl
        self.note = note
        self.feeling = feeling
        self.energyLevel = energyLevel
        self.loggedDate = loggedDate
        self.loggedTime = loggedTime
        self.createdAt = createdAt
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.foodItems = foodItems
    }
}

// MARK: - Food Item (for tracking individual foods in a meal)
struct MealLogFoodItem: Codable, Identifiable {
    var id: String
    var name: String
    var calories: Int
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var servingSize: String?
    var quantity: Double
    
    enum CodingKeys: String, CodingKey {
        case id, name, calories, quantity
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case servingSize = "serving_size"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        calories: Int,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        servingSize: String? = nil,
        quantity: Double = 1
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.servingSize = servingSize
        self.quantity = quantity
    }
    
    var totalCalories: Int {
        Int(Double(calories) * quantity)
    }
}

// MARK: - Daily Nutrition Summary
struct DailyNutritionSummary {
    var totalCalories: Int = 0
    var totalProtein: Double = 0
    var totalCarbs: Double = 0
    var totalFat: Double = 0
    var totalFiber: Double = 0
    
    var calorieGoal: Int = 2000
    var proteinGoal: Int = 50
    var carbsGoal: Int = 250
    var fatGoal: Int = 65
    
    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(totalCalories) / Double(calorieGoal), 1.0)
    }
    
    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(totalProtein / Double(proteinGoal), 1.0)
    }
    
    var carbsProgress: Double {
        guard carbsGoal > 0 else { return 0 }
        return min(totalCarbs / Double(carbsGoal), 1.0)
    }
    
    var fatProgress: Double {
        guard fatGoal > 0 else { return 0 }
        return min(totalFat / Double(fatGoal), 1.0)
    }
    
    var remainingCalories: Int {
        max(0, calorieGoal - totalCalories)
    }
}

// MARK: - Daily Meal Summary
struct DailyMealSummary {
    let date: Date
    var meals: [MealType: UserMealLog]
    
    var completedMeals: Int {
        meals.values.filter { $0.hasContent }.count
    }
    
    var totalCalories: Int {
        meals.values.compactMap { $0.calories }.reduce(0, +)
    }
    
    var totalProtein: Double {
        meals.values.compactMap { $0.proteinG }.reduce(0, +)
    }
    
    var totalCarbs: Double {
        meals.values.compactMap { $0.carbsG }.reduce(0, +)
    }
    
    var totalFat: Double {
        meals.values.compactMap { $0.fatG }.reduce(0, +)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEEE, dd/MM"
        return formatter.string(from: date).capitalized
    }
    
    func meal(for type: MealType) -> UserMealLog? {
        return meals[type]
    }
}

// MARK: - Common Food Database (Vietnamese foods)
struct CommonFood {
    let name: String
    let calories: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let servingSize: String
    let category: FoodCategory
    
    enum FoodCategory: String, CaseIterable {
        case rice = "Cơm/Bún/Phở"
        case meat = "Thịt"
        case seafood = "Hải sản"
        case vegetable = "Rau củ"
        case fruit = "Trái cây"
        case drink = "Đồ uống"
        case snack = "Ăn vặt"
        case other = "Khác"
    }
    
    // Common Vietnamese foods database
    static let database: [CommonFood] = [
        // Rice & Noodles
        CommonFood(name: "Cơm trắng", calories: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3, servingSize: "1 chén (100g)", category: .rice),
        CommonFood(name: "Phở bò", calories: 350, proteinG: 20, carbsG: 45, fatG: 8, servingSize: "1 tô", category: .rice),
        CommonFood(name: "Bún bò Huế", calories: 400, proteinG: 25, carbsG: 50, fatG: 10, servingSize: "1 tô", category: .rice),
        CommonFood(name: "Bánh mì thịt", calories: 350, proteinG: 15, carbsG: 40, fatG: 15, servingSize: "1 ổ", category: .rice),
        CommonFood(name: "Bún chả", calories: 450, proteinG: 30, carbsG: 45, fatG: 18, servingSize: "1 phần", category: .rice),
        
        // Meat
        CommonFood(name: "Thịt heo nướng", calories: 250, proteinG: 25, carbsG: 2, fatG: 16, servingSize: "100g", category: .meat),
        CommonFood(name: "Thịt gà luộc", calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6, servingSize: "100g", category: .meat),
        CommonFood(name: "Thịt bò xào", calories: 200, proteinG: 26, carbsG: 3, fatG: 10, servingSize: "100g", category: .meat),
        CommonFood(name: "Trứng chiên", calories: 90, proteinG: 6, carbsG: 0.6, fatG: 7, servingSize: "1 quả", category: .meat),
        
        // Seafood
        CommonFood(name: "Cá kho tộ", calories: 180, proteinG: 22, carbsG: 5, fatG: 8, servingSize: "100g", category: .seafood),
        CommonFood(name: "Tôm hấp", calories: 100, proteinG: 20, carbsG: 1, fatG: 1.5, servingSize: "100g", category: .seafood),
        
        // Vegetables
        CommonFood(name: "Rau muống xào", calories: 50, proteinG: 3, carbsG: 6, fatG: 2, servingSize: "1 đĩa", category: .vegetable),
        CommonFood(name: "Canh chua", calories: 80, proteinG: 5, carbsG: 10, fatG: 2, servingSize: "1 tô", category: .vegetable),
        CommonFood(name: "Salad", calories: 50, proteinG: 2, carbsG: 8, fatG: 1, servingSize: "1 đĩa", category: .vegetable),
        
        // Fruits
        CommonFood(name: "Chuối", calories: 90, proteinG: 1.1, carbsG: 23, fatG: 0.3, servingSize: "1 quả", category: .fruit),
        CommonFood(name: "Táo", calories: 52, proteinG: 0.3, carbsG: 14, fatG: 0.2, servingSize: "1 quả", category: .fruit),
        CommonFood(name: "Cam", calories: 45, proteinG: 1, carbsG: 11, fatG: 0.1, servingSize: "1 quả", category: .fruit),
        
        // Drinks
        CommonFood(name: "Trà đá", calories: 0, proteinG: 0, carbsG: 0, fatG: 0, servingSize: "1 ly", category: .drink),
        CommonFood(name: "Cà phê sữa đá", calories: 120, proteinG: 2, carbsG: 20, fatG: 4, servingSize: "1 ly", category: .drink),
        CommonFood(name: "Sinh tố bơ", calories: 250, proteinG: 4, carbsG: 30, fatG: 14, servingSize: "1 ly", category: .drink),
        CommonFood(name: "Nước ép cam", calories: 110, proteinG: 1.5, carbsG: 26, fatG: 0.5, servingSize: "1 ly", category: .drink),
        
        // Snacks
        CommonFood(name: "Bánh bao", calories: 200, proteinG: 8, carbsG: 30, fatG: 5, servingSize: "1 cái", category: .snack),
        CommonFood(name: "Xôi", calories: 180, proteinG: 4, carbsG: 35, fatG: 3, servingSize: "1 gói nhỏ", category: .snack),
    ]
}

// MARK: - Date Formatters
enum DateFormatters {
    static let localDateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
