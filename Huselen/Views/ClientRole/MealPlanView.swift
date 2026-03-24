import SwiftUI

// MARK: - Main View

struct MealPlanView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var showAddFood = false
    @State private var showReport = false
    @State private var waterLiters: Double = 1.5

    private var myProfile: Client? { syncManager.clients.first }

    private var calorieGoal: Int { myProfile?.calorieGoal ?? 2200 }
    private var proteinGoal: Double { myProfile?.proteinGoal ?? 150 }
    private var carbsGoal: Double { myProfile?.carbsGoal ?? 280 }
    private var fatGoal: Double { myProfile?.fatGoal ?? 70 }

    private var todayEntries: [MealEntry] {
        let cal = Calendar.current
        return syncManager.mealEntries.filter { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var totalCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { todayEntries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { todayEntries.reduce(0) { $0 + $1.fat } }

    private var snackCalories: Int {
        todayEntries.filter { $0.mealType == .snack }.reduce(0) { $0 + $1.calories }
    }

    // MARK: - Calendar helpers

    private var calendarWeeks: [[Date?]] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1=Sun
        let offset = firstWeekday - 1 // days to skip before 1st

        var weeks: [[Date?]] = []
        var week: [Date?] = Array(repeating: nil, count: offset)

        for day in range {
            if let date = cal.date(bySetting: .day, value: day, of: firstOfMonth) {
                week.append(date)
                if week.count == 7 {
                    weeks.append(week)
                    week = []
                }
            }
        }
        if !week.isEmpty {
            while week.count < 7 { week.append(nil) }
            weeks.append(week)
        }
        return weeks
    }

    private func hasEntries(for date: Date) -> Bool {
        let cal = Calendar.current
        return syncManager.mealEntries.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    private var monthLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "MMMM, yyyy"
        let result = df.string(from: displayedMonth)
        return result.prefix(1).uppercased() + result.dropFirst()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                monthNavigationView
                calendarGridView
                heroCardView
                mealsSectionView
                quickStatsView
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.Colors.screenBackground)
        .refreshable { await syncManager.refresh() }
        .sheet(isPresented: $showAddFood) {
            AddFoodView(date: selectedDate)
        }
        .sheet(isPresented: $showReport) {
            NutritionReportView()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kế hoạch dinh dưỡng")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
                Text("Meal Plan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
            }
            Spacer()
            Button { showReport = true } label: {
                let name = myProfile?.name ?? ""
                let initials = name.split(separator: " ").compactMap { $0.first }.suffix(2).map { String($0) }.joined()
                let display = initials.isEmpty ? "NH" : initials.uppercased()
                ZStack {
                    Circle()
                        .fill(Color.fitGreen)
                        .frame(width: 44, height: 44)
                    Text(display)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Month Navigation

    private var monthNavigationView: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
            }

            Spacer()

            Text(monthLabel)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()

            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGridView: some View {
        VStack(spacing: 4) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(["CN", "T2", "T3", "T4", "T5", "T6", "T7"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week rows
            ForEach(Array(calendarWeeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { index in
                        if let date = week[index] {
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let dayHasEntries = hasEntries(for: date)

                            Button {
                                selectedDate = date
                            } label: {
                                ZStack {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.fitGreen)
                                    } else if dayHasEntries {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.fitCard)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .strokeBorder(Theme.Colors.separator, lineWidth: 1.5)
                                            )
                                    }

                                    Text("\(Calendar.current.component(.day, from: date))")
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .foregroundStyle(isSelected ? .white : Color.fitTextPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Card

    private var heroCardView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.fitGreen,
                                 Color.fitGreenDark,
                                 Color.fitGreenDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .offset(x: 240, y: -10)

            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 80, height: 80)
                .offset(x: 260, y: 70)

            VStack(alignment: .leading, spacing: 8) {
                Text("Hôm nay")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(totalCalories)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(calorieGoal) kcal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.3)).frame(height: 6)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * min(1, Double(totalCalories) / Double(max(1, calorieGoal))), height: 6)
                    }
                }
                .frame(height: 6)
                .frame(width: 200)

                // Macro row
                HStack(spacing: 16) {
                    Text("P: \(Int(totalProtein))g")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("C: \(Int(totalCarbs))g")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("F: \(Int(totalFat))g")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(24)
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Meals Section

    private var mealsSectionView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("BỮA ĂN HÔM NAY")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
                    .tracking(0.5)
                Spacer()
                Button { showAddFood = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text("Thêm")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.fitGreen)
                }
                .buttonStyle(.plain)
            }

            ForEach(MealEntry.MealType.allCases, id: \.self) { type in
                let entries = todayEntries.filter { $0.mealType == type }
                if !entries.isEmpty {
                    MealSummaryCard(
                        mealType: type,
                        entries: entries,
                        onDelete: { entry in
                            Task { await syncManager.deleteMealEntry(entry) }
                        }
                    )
                }
            }

            // Show empty state if no entries at all
            if todayEntries.isEmpty {
                Button { showAddFood = true } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.fitGreen.opacity(0.4))
                        Text("Thêm bữa ăn đầu tiên")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.fitCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStatsView: some View {
        HStack(spacing: 12) {
            // Snack card
            VStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.fitOrange)
                Text("\(snackCalories)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.fitTextPrimary)
                Text("Snack (kcal)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.fitCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            // Water card
            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.fitBlue)
                Text(String(format: "%.1fL", waterLiters))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.fitTextPrimary)
                Text("Nước / 2.5L")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(Color.fitCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onTapGesture {
                waterLiters = min(5.0, waterLiters + 0.25)
            }
        }
    }
}

// MARK: - Meal Summary Card

struct MealSummaryCard: View {
    let mealType: MealEntry.MealType
    let entries: [MealEntry]
    let onDelete: (MealEntry) -> Void

    private var totalCalories: Int { entries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { entries.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { entries.reduce(0) { $0 + $1.fat } }

    private var mealLabel: String {
        switch mealType {
        case .breakfast: return "Bữa sáng"
        case .lunch: return "Bữa trưa"
        case .dinner: return "Bữa tối"
        case .snack: return "Bữa phụ"
        }
    }
    private var mealColor: Color {
        switch mealType {
        case .breakfast: return .orange
        case .lunch: return .blue
        case .dinner: return .indigo
        case .snack: return .purple
        }
    }
    private var descriptionText: String {
        entries.map { $0.name }.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(mealColor.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: mealType.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(mealColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mealLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.fitTextPrimary)
                    Text(descriptionText)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.fitTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(totalCalories) kcal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mealColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(mealColor.opacity(0.12)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if totalProtein > 0 || totalCarbs > 0 || totalFat > 0 {
                Divider().padding(.horizontal, 14)
                HStack(spacing: 16) {
                    macroChip(value: totalProtein, label: "Đạm", color: .blue)
                    macroChip(value: totalCarbs, label: "Carbs", color: .orange)
                    macroChip(value: totalFat, label: "Béo", color: .pink)
                    Spacer()
                    Text("\(entries.count) món")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Color.fitCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            ForEach(entries) { entry in
                Button(role: .destructive) {
                    onDelete(entry)
                } label: {
                    Label("Xoá \(entry.name)", systemImage: "trash")
                }
            }
        }
    }

    private func macroChip(value: Double, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(Int(value))g \(label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.fitTextSecondary)
        }
    }
}
