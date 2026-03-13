import SwiftUI

// MARK: - Fitness Color Palette

extension Color {
    static let fitGreen = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let fitGreenDark = Color(red: 0.086, green: 0.639, blue: 0.290)
    static let fitGreenSoft = Color(red: 0.941, green: 0.992, blue: 0.957)
    static let fitCard = Color(red: 0.965, green: 0.969, blue: 0.973)
    static let fitIndigo = Color(red: 0.388, green: 0.400, blue: 0.945)
    static let fitOrange = Color(red: 0.851, green: 0.467, blue: 0.024)
    static let fitCoral = Color(red: 1.0, green: 0.420, blue: 0.420)
    static let fitBlue = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let fitLavender = Color(red: 0.600, green: 0.502, blue: 0.957)
    static let fitTextPrimary = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let fitTextSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let fitTextTertiary = Color(red: 0.612, green: 0.639, blue: 0.675)
}

// MARK: - Main View

struct MealPlanView: View {
    @State private var selectedDate = Date()
    @State private var showAddFood = false
    @State private var showReport = false
    @State private var waterCups = 5
    @State private var mealEntries: [MealEntry] = MealEntry.sampleData

    private let calorieGoal = 2200
    private let proteinGoal = 150.0
    private let carbsGoal = 280.0
    private let fatGoal = 70.0

    private var todayEntries: [MealEntry] {
        let cal = Calendar.current
        return mealEntries.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var totalCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { todayEntries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { todayEntries.reduce(0) { $0 + $1.fat } }
    private var remainingCalories: Int { max(0, calorieGoal - totalCalories) }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthNavigationView
                    weekStripView
                    heroCardView
                    waterTrackerView
                    mealsSectionView
                    if remainingCalories > 0 {
                        suggestionBannerView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Meal Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showReport = true } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color.fitGreen)
                    }
                }
            }
            .profileToolbar()
            .sheet(isPresented: $showAddFood) {
                AddFoodView(mealEntries: $mealEntries, date: selectedDate)
            }
            .sheet(isPresented: $showReport) {
                NutritionReportView(entries: mealEntries)
            }
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationView: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
            }

            Spacer()

            Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Week Strip

    private var weekStripView: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)

                Button {
                    selectedDate = day
                } label: {
                    VStack(spacing: 6) {
                        Text(vietWeekdayShort(day))
                            .font(.system(size: 11, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? Color.fitGreen : Color.fitTextTertiary)

                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color.fitGreen)
                                    .frame(width: 28, height: 28)
                            }
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : Color.fitTextSecondary)
                        }
                        .frame(width: 28, height: 28)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Hero Card

    private var heroCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.fitGreen, .fitGreenDark, Color(red: 0.024, green: 0.588, blue: 0.412)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative circle
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 160, height: 160)
                .offset(x: 90, y: -20)

            HStack(alignment: .center) {
                // Left — Calories
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hôm nay")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(totalCalories)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("/ \(calorieGoal) kcal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.2)).frame(height: 5)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width * min(1, Double(totalCalories) / Double(calorieGoal)), height: 5)
                        }
                    }
                    .frame(height: 5)
                }

                Spacer()

                // Right — Macro chips
                VStack(alignment: .leading, spacing: 8) {
                    macroPill("💪", label: "Protein", value: "\(Int(totalProtein))/\(Int(proteinGoal))g")
                    macroPill("🍚", label: "Carbs", value: "\(Int(totalCarbs))/\(Int(carbsGoal))g")
                    macroPill("🥑", label: "Fat", value: "\(Int(totalFat))/\(Int(fatGoal))g")
                }
            }
            .padding(20)
        }
        .frame(height: 160)
    }

    private func macroPill(_ emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(emoji) \(label)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Water Tracker

    private var waterTrackerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.937, green: 0.961, blue: 1.0))
                    .frame(width: 36, height: 36)
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fitBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Nước uống")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                Text("\(waterCups * 250)ml / 2,000ml hôm nay")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fitTextSecondary)
            }

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<8) { i in
                    Button {
                        waterCups = i < waterCups ? i : i + 1
                    } label: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(i < waterCups ? Color.fitBlue : Color(red: 0.75, green: 0.86, blue: 0.996))
                            .frame(width: 8, height: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding([.horizontal, .vertical], 14)
        .background(Color.fitCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Meals Section

    private var mealsSectionView: some View {
        VStack(spacing: 10) {
            HStack {
                Text("BỮA ĂN HÔM NAY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .tracking(1)
                Spacer()
                Button { showAddFood = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Thêm")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.fitGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.fitGreenSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            ForEach(MealEntry.MealType.allCases, id: \.self) { type in
                let entries = todayEntries.filter { $0.mealType == type }
                MealTypeCard(
                    mealType: type,
                    entries: entries,
                    onAdd: { showAddFood = true }
                )
            }
        }
    }

    // MARK: - Suggestion Banner

    private var suggestionBannerView: some View {
        Button { showAddFood = true } label: {
            HStack(spacing: 10) {
                Text("✨")
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gợi ý bữa phụ hôm nay")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fitTextPrimary)
                    Text("Còn \(remainingCalories) kcal · Xem snack phù hợp")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fitTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitGreen)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.fitGreenSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.fitGreen.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func vietWeekdayShort(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        let map = [1: "CN", 2: "T2", 3: "T3", 4: "T4", 5: "T5", 6: "T6", 7: "T7"]
        return map[weekday] ?? ""
    }
}

// MARK: - Meal Type Card

struct MealTypeCard: View {
    let mealType: MealEntry.MealType
    let entries: [MealEntry]
    let onAdd: () -> Void

    private var totalCalories: Int { entries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { entries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }

    var body: some View {
        VStack(spacing: 0) {
            if entries.isEmpty {
                emptyState
            } else {
                filledState
            }
        }
        .background(Color(red: 0.965, green: 0.969, blue: 0.973))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var emptyState: some View {
        Button(action: onAdd) {
            HStack(spacing: 12) {
                Image(systemName: mealType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fitGreen)
                    .frame(width: 42, height: 42)
                    .background(Color.fitGreenSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Thêm \(mealType.rawValue.lowercased())")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.fitGreen.opacity(0.4))
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    private var filledState: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: mealType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                        .frame(width: 42, height: 42)
                        .background(Color.fitGreenSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                            Spacer()
                            Text("\(entry.calories) kcal")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fitGreen)
                        }

                        if !entry.description.isEmpty {
                            Text(entry.description)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.420, green: 0.447, blue: 0.502))
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            macroTag("💪", value: "\(Int(entry.protein))g", color: Color.fitIndigo)
                            macroTag("🍚", value: "\(Int(entry.carbs))g", color: Color.fitOrange)
                            macroTag("🥑", value: "\(Int(entry.fat))g", color: Color.fitCoral)
                        }
                    }
                }
                .padding(16)

                if entry.id != entries.last?.id {
                    Divider().padding(.leading, 70)
                }
            }

            // Add more button
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Thêm vào \(mealType.rawValue.lowercased())")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.fitGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.fitGreenSoft)
            }
            .buttonStyle(.plain)
        }
    }

    private func macroTag(_ emoji: String, value: String, color: Color) -> some View {
        Text("\(emoji) \(value)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
    }
}
