//
//  MealLogViewModel.swift
//  HuselenClient
//
//  Created by Le Thach lam on 17/12/25.
//

import Foundation
import SwiftUI
import Supabase
internal import Combine

@MainActor
class MealLogViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedDate: Date = Date()
    @Published var displayedMonth: Date = Date()  // The month being displayed in calendar
    @Published var weekDates: [Date] = []
    @Published var mealLogs: [MealType: UserMealLog] = [:]
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var saveSuccess = false
    
    // Current editing meal
    @Published var editingMealType: MealType?
    @Published var editingNote: String = ""
    @Published var editingPhoto: UIImage?
    @Published var editingFeeling: MealFeeling?
    
    // Nutrition tracking
    @Published var dailyNutrition: DailyNutritionSummary = DailyNutritionSummary()
    @Published var editingCalories: Int = 0
    @Published var editingProtein: Double = 0
    @Published var editingCarbs: Double = 0
    @Published var editingFat: Double = 0
    @Published var editingFoodItems: [MealLogFoodItem] = []
    @Published var showFoodDatabase = false
    @Published var searchFoodText: String = ""
    
    // AI Analysis
    @Published var isAnalyzing = false
    @Published var analysisResult: MealAnalysisResult?
    @Published var analysisError: String?
    @Published var showAnalysisResult = false
    @Published var mealDescription: String?
    @Published var healthNote: String?
    @Published var userMealNote: String = ""  // User's custom note about the meal
    
    private let openAIService = OpenAIService.shared
    
    // MARK: - Computed Properties
    var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEEE, dd/MM"
        return formatter.string(from: selectedDate).capitalized
    }
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth).capitalized
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    // Computed nutrition values from food items
    var calculatedCalories: Int {
        editingFoodItems.reduce(0) { $0 + $1.totalCalories }
    }
    
    var calculatedProtein: Double {
        editingFoodItems.reduce(0) { $0 + (($1.proteinG ?? 0) * $1.quantity) }
    }
    
    var calculatedCarbs: Double {
        editingFoodItems.reduce(0) { $0 + (($1.carbsG ?? 0) * $1.quantity) }
    }
    
    var calculatedFat: Double {
        editingFoodItems.reduce(0) { $0 + (($1.fatG ?? 0) * $1.quantity) }
    }
    
    // Search filtered foods
    var filteredFoods: [CommonFood] {
        if searchFoodText.isEmpty {
            return CommonFood.database
        }
        return CommonFood.database.filter { 
            $0.name.localizedCaseInsensitiveContains(searchFoodText) 
        }
    }
    
    // Foods grouped by category
    var foodsByCategory: [CommonFood.FoodCategory: [CommonFood]] {
        Dictionary(grouping: filteredFoods, by: { $0.category })
    }
    
    // Index of today in the dates array (for auto-scrolling)
    var todayIndex: Int? {
        weekDates.firstIndex { Calendar.current.isDateInToday($0) }
    }
    
    // Index of selected date in the dates array (for scrolling when changing months)
    var selectedDateIndex: Int? {
        weekDates.firstIndex { Calendar.current.isDate($0, inSameDayAs: selectedDate) }
    }
    
    // MARK: - Initialize Month Dates
    func initializeWeekDates() {
        let calendar = Calendar.current
        let today = Date()
        
        // Set selectedDate and displayedMonth to start of today
        selectedDate = calendar.startOfDay(for: today)
        displayedMonth = selectedDate
        
        // Generate dates for the current month
        generateDatesForMonth(displayedMonth)
    }
    
    // Generate dates for a specific month
    func generateDatesForMonth(_ month: Date) {
        let calendar = Calendar.current
        
        // Get the start of the month
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return }
        
        // Get the range of days in the month
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return }
        
        // Generate all days of the month
        weekDates = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    // Navigate to previous month
    func goToPreviousMonth() {
        let calendar = Calendar.current
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = previousMonth
            generateDatesForMonth(displayedMonth)
        }
    }
    
    // Navigate to next month
    func goToNextMonth() {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = nextMonth
            generateDatesForMonth(displayedMonth)
        }
    }
    
    // Check if displayed month is current month (to potentially disable "next" button)
    var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    // Go to today and show current month
    func goToToday() {
        let calendar = Calendar.current
        let today = Date()
        selectedDate = calendar.startOfDay(for: today)
        displayedMonth = selectedDate
        generateDatesForMonth(displayedMonth)
    }
    
    // MARK: - Load Meals for Date
    func loadMeals(userId: String, for date: Date? = nil) async {
        let targetDate = date ?? selectedDate
        isLoading = true
        errorMessage = nil
        
        let dateString = DateFormatters.localDateOnly.string(from: targetDate)
        
        do {
            let response: [UserMealLog] = try await supabase
                .from("user_meal_logs")
                .select()
                .eq("user_id", value: userId)
                .eq("logged_date", value: dateString)
                .execute()
                .value
            
            // Convert to dictionary by meal type
            var mealsDict: [MealType: UserMealLog] = [:]
            for meal in response {
                mealsDict[meal.mealType] = meal
            }
            self.mealLogs = mealsDict
            
        } catch {
            self.errorMessage = "Không thể tải dữ liệu: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Analyze Meal Image with AI
    func analyzeMealImage(_ image: UIImage, userContext: String? = nil) async -> MealAnalysisResult? {
        isAnalyzing = true
        analysisError = nil
        analysisResult = nil
        
        do {
            let result = try await openAIService.analyzeMealImage(image, userContext: userContext)
            
            // Update editing values with AI results
            analysisResult = result
            editingCalories = result.totalCalories
            editingProtein = result.totalProteinG
            editingCarbs = result.totalCarbsG
            editingFat = result.totalFatG
            editingFoodItems = result.toFoodItems()
            mealDescription = result.mealDescription
            healthNote = result.healthNote
            showAnalysisResult = true
            
            isAnalyzing = false
            return result
            
        } catch {
            analysisError = error.localizedDescription
            isAnalyzing = false
            return nil
        }
    }
    
    // MARK: - Save Meal With AI Analysis
    func saveMealWithAnalysis(
        userId: String,
        mealType: MealType,
        photo: UIImage?,
        note: String?
    ) async -> Bool {
        // First analyze the image if available
        if let photo = photo {
            _ = await analyzeMealImage(photo)
        }
        
        // Then save with the analyzed nutrition data
        return await saveMealWithNutrition(
            userId: userId,
            mealType: mealType,
            photo: photo,
            note: note ?? mealDescription,
            feeling: nil,
            calories: editingCalories > 0 ? editingCalories : nil,
            proteinG: editingProtein > 0 ? editingProtein : nil,
            carbsG: editingCarbs > 0 ? editingCarbs : nil,
            fatG: editingFat > 0 ? editingFat : nil,
            foodItems: editingFoodItems.isEmpty ? nil : editingFoodItems
        )
    }
    
    // MARK: - Clear Analysis Result
    func clearAnalysisResult() {
        analysisResult = nil
        analysisError = nil
        showAnalysisResult = false
        mealDescription = nil
        healthNote = nil
        userMealNote = ""
    }
    
    // MARK: - Save Meal Log
    func saveMealLog(
        userId: String,
        mealType: MealType,
        photo: UIImage?,
        note: String?,
        feeling: MealFeeling?
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        saveSuccess = false

        do {
            var photoUrl: String? = nil

            // Upload photo if exists — resize + compress off main thread
            if let photo = photo,
               let imageData = await prepareUploadData(photo: photo) {
                let dateString = DateFormatters.localDateOnly.string(from: selectedDate)
                let fileName = "\(userId.lowercased())/\(dateString)_\(mealType.rawValue)_\(Date().timeIntervalSince1970).jpg"

                try await supabase.storage
                    .from("meal-photos")
                    .upload(
                        path: fileName,
                        file: imageData,
                        options: FileOptions(contentType: "image/jpeg")
                    )

                photoUrl = try supabase.storage
                    .from("meal-photos")
                    .getPublicURL(path: fileName)
                    .absoluteString
            }

            // Get current time
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let currentTime = timeFormatter.string(from: Date())

            // Merge with existing meal so upsert preserves untouched fields
            let existing = mealLogs[mealType]
            let mealLog = UserMealLog(
                id: nil,   // omit id — let DB manage primary key on upsert
                userId: userId,
                mealType: mealType,
                photoUrl: photoUrl ?? existing?.photoUrl,
                note: note?.isEmpty == true ? nil : (note ?? existing?.note),
                feeling: feeling ?? existing?.feeling,
                loggedDate: selectedDate,
                loggedTime: currentTime,
                calories: existing?.calories,
                proteinG: existing?.proteinG,
                carbsG: existing?.carbsG,
                fatG: existing?.fatG,
                foodItems: existing?.foodItems
            )

            try await supabase
                .from("user_meal_logs")
                .upsert(mealLog, onConflict: "user_id,meal_type,logged_date")
                .execute()

            // Reload data
            await loadMeals(userId: userId)

            // Reset editing state
            resetEditing()
            saveSuccess = true
            isSaving = false

            return true

        } catch {
            isSaving = false
            errorMessage = "Không thể lưu: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Delete Meal Log
    func deleteMealLog(userId: String, mealType: MealType) async -> Bool {
        guard let meal = mealLogs[mealType], let mealId = meal.id else {
            return false
        }
        
        isSaving = true
        
        do {
            try await supabase
                .from("user_meal_logs")
                .delete()
                .eq("id", value: mealId)
                .execute()
            
            await loadMeals(userId: userId)
            isSaving = false
            return true
            
        } catch {
            isSaving = false
            errorMessage = "Không thể xóa: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Select Date
    func selectDate(_ date: Date, userId: String) async {
        let calendar = Calendar.current
        selectedDate = date
        
        // If selected date is in a different month, update displayedMonth and regenerate dates
        if !calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = date
            generateDatesForMonth(displayedMonth)
        }
        
        await loadMeals(userId: userId, for: date)
        calculateDailyNutrition()
    }
    
    // MARK: - Start Editing
    func startEditing(mealType: MealType) {
        editingMealType = mealType
        
        // Load existing data if available
        if let existingMeal = mealLogs[mealType] {
            editingNote = existingMeal.note ?? ""
            editingFeeling = existingMeal.feeling
        } else {
            editingNote = ""
            editingFeeling = nil
        }
        editingPhoto = nil
    }
    
    // MARK: - Reset Editing
    func resetEditing() {
        editingMealType = nil
        editingNote = ""
        editingPhoto = nil
        editingFeeling = nil
    }
    
    // MARK: - Get Day Name
    func dayName(for date: Date) -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch weekday {
        case 1: return "CN"
        case 2: return "T2"
        case 3: return "T3"
        case 4: return "T4"
        case 5: return "T5"
        case 6: return "T6"
        case 7: return "T7"
        default: return ""
        }
    }
    
    func dayNumber(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return String(day)
    }
    
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    func isDateToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    // MARK: - Calculate Daily Nutrition
    func calculateDailyNutrition() {
        var summary = DailyNutritionSummary()
        
        for (_, meal) in mealLogs {
            summary.totalCalories += meal.calories ?? 0
            summary.totalProtein += meal.proteinG ?? 0
            summary.totalCarbs += meal.carbsG ?? 0
            summary.totalFat += meal.fatG ?? 0
            summary.totalFiber += meal.fiberG ?? 0
        }
        
        dailyNutrition = summary
    }
    
    // MARK: - Add Food Item
    func addFoodItem(_ food: CommonFood, quantity: Double = 1) {
        let foodItem = MealLogFoodItem(
            name: food.name,
            calories: food.calories,
            proteinG: food.proteinG,
            carbsG: food.carbsG,
            fatG: food.fatG,
            servingSize: food.servingSize,
            quantity: quantity
        )
        editingFoodItems.append(foodItem)
        updateEditingNutrition()
    }
    
    // MARK: - Remove Food Item
    func removeFoodItem(at index: Int) {
        guard index < editingFoodItems.count else { return }
        editingFoodItems.remove(at: index)
        updateEditingNutrition()
    }
    
    // MARK: - Update Food Item Quantity
    func updateFoodItemQuantity(at index: Int, quantity: Double) {
        guard index < editingFoodItems.count else { return }
        editingFoodItems[index].quantity = quantity
        updateEditingNutrition()
    }
    
    // MARK: - Update Editing Nutrition
    func updateEditingNutrition() {
        editingCalories = calculatedCalories
        editingProtein = calculatedProtein
        editingCarbs = calculatedCarbs
        editingFat = calculatedFat
    }
    
    // MARK: - Add Custom Food
    func addCustomFood(name: String, calories: Int, protein: Double = 0, carbs: Double = 0, fat: Double = 0) {
        let foodItem = MealLogFoodItem(
            name: name,
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            quantity: 1
        )
        editingFoodItems.append(foodItem)
        updateEditingNutrition()
    }
    
    // MARK: - Prepare Upload Data off main thread
    private func prepareUploadData(photo: UIImage, maxDimension: CGFloat = 1200) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            // Resize for upload (1200px is plenty for storage display)
            let size = photo.size
            let needsResize = max(size.width, size.height) > maxDimension
            let resized: UIImage
            if needsResize {
                let scale = maxDimension / max(size.width, size.height)
                let newSize = CGSize(width: size.width * scale, height: size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                resized = renderer.image { _ in
                    photo.draw(in: CGRect(origin: .zero, size: newSize))
                }
            } else {
                resized = photo
            }
            return resized.jpegData(compressionQuality: 0.6)
        }.value
    }

    // MARK: - Save Meal With Nutrition
    func saveMealWithNutrition(
        userId: String,
        mealType: MealType,
        photo: UIImage?,
        note: String?,
        feeling: MealFeeling?,
        calories: Int?,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        foodItems: [MealLogFoodItem]?
    ) async -> Bool {
        isSaving = true
        errorMessage = nil
        saveSuccess = false

        do {
            var photoUrl: String? = nil

            // Upload photo if exists — resize + compress off main thread
            if let photo = photo,
               let imageData = await prepareUploadData(photo: photo) {
                let dateString = DateFormatters.localDateOnly.string(from: selectedDate)
                let fileName = "\(userId.lowercased())/\(dateString)_\(mealType.rawValue)_\(Date().timeIntervalSince1970).jpg"

                try await supabase.storage
                    .from("meal-photos")
                    .upload(
                        path: fileName,
                        file: imageData,
                        options: FileOptions(contentType: "image/jpeg")
                    )

                photoUrl = try supabase.storage
                    .from("meal-photos")
                    .getPublicURL(path: fileName)
                    .absoluteString
            }
            
            // Get current time
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm:ss"
            let currentTime = timeFormatter.string(from: Date())

            // Merge new values over existing meal so upsert preserves untouched fields
            let existing = mealLogs[mealType]
            let mealLog = UserMealLog(
                id: nil,   // omit id — let DB manage primary key on upsert
                userId: userId,
                mealType: mealType,
                photoUrl: photoUrl ?? existing?.photoUrl,
                note: note?.isEmpty == true ? nil : (note ?? existing?.note),
                feeling: feeling ?? existing?.feeling,
                loggedDate: selectedDate,
                loggedTime: currentTime,
                calories: calories ?? existing?.calories,
                proteinG: proteinG ?? existing?.proteinG,
                carbsG: carbsG ?? existing?.carbsG,
                fatG: fatG ?? existing?.fatG,
                foodItems: (foodItems?.isEmpty == false ? foodItems : nil) ?? existing?.foodItems
            )

            try await supabase
                .from("user_meal_logs")
                .upsert(mealLog, onConflict: "user_id,meal_type,logged_date")
                .execute()
            
            // Reload data and recalculate nutrition
            await loadMeals(userId: userId)
            calculateDailyNutrition()
            
            // Reset editing state
            resetEditing()
            saveSuccess = true
            isSaving = false
            
            return true
            
        } catch {
            isSaving = false
            errorMessage = "Không thể lưu: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Reset Editing With Nutrition
    func resetEditingWithNutrition() {
        resetEditing()
        editingCalories = 0
        editingProtein = 0
        editingCarbs = 0
        editingFat = 0
        editingFoodItems = []
        searchFoodText = ""
    }
    
    // MARK: - Load Editing Data For Meal
    func loadEditingData(for mealType: MealType) {
        startEditing(mealType: mealType)
        
        if let existingMeal = mealLogs[mealType] {
            editingCalories = existingMeal.calories ?? 0
            editingProtein = existingMeal.proteinG ?? 0
            editingCarbs = existingMeal.carbsG ?? 0
            editingFat = existingMeal.fatG ?? 0
            editingFoodItems = existingMeal.foodItems ?? []
        } else {
            editingCalories = 0
            editingProtein = 0
            editingCarbs = 0
            editingFat = 0
            editingFoodItems = []
        }
    }
}

