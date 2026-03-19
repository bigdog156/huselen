import SwiftUI

struct NutritionReportView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss

    @State private var weekOffset = 0
    @State private var weekLogs: [UserMealLog] = []
    @State private var isLoading = false

    private var myProfile: Client? { syncManager.clients.first }
    private var calorieGoal: Int { myProfile?.calorieGoal ?? 2200 }
    private var proteinGoal: Double { myProfile?.proteinGoal ?? 150 }
    private var carbsGoal: Double { myProfile?.carbsGoal ?? 280 }
    private var fatGoal: Double { myProfile?.fatGoal ?? 70 }

    private var weekDates: [Date] {
        let cal = Calendar.current
        let baseDate = cal.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        let startOfWeek = cal.dateInterval(of: .weekOfYear, for: baseDate)?.start ?? baseDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var weekLabel: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let df = DateFormatter()
        df.dateFormat = "d"
        return "\(df.string(from: first)) – \(df.string(from: last)) Tháng \(Calendar.current.component(.month, from: first)), \(Calendar.current.component(.year, from: first))"
    }

    private func logsFor(_ date: Date) -> [UserMealLog] {
        let cal = Calendar.current
        return weekLogs.filter { cal.isDate($0.loggedDate, inSameDayAs: date) }
    }

    private func caloriesFor(_ date: Date) -> Int {
        logsFor(date).compactMap(\.calories).reduce(0, +)
    }

    private var avgCalories: Int {
        let daysWithData = weekDates.filter { caloriesFor($0) > 0 }.count
        guard daysWithData > 0 else { return 0 }
        let total = weekLogs.compactMap(\.calories).reduce(0, +)
        return total / daysWithData
    }

    private var daysOnGoal: Int {
        weekDates.filter { caloriesFor($0) >= calorieGoal - 200 && caloriesFor($0) > 0 }.count
    }

    private var totalProtein: Double { weekLogs.compactMap(\.proteinG).reduce(0, +) }
    private var totalCarbs: Double { weekLogs.compactMap(\.carbsG).reduce(0, +) }
    private var totalFat: Double { weekLogs.compactMap(\.fatG).reduce(0, +) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weekSelectorView
                    if isLoading {
                        ProgressView()
                            .padding(.vertical, 40)
                    } else {
                        summaryCardView
                        barChartView
                        macroBreakdownView
                        streakBannerView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Báo cáo dinh dưỡng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.fitGreen)
                    }
                }
            }
            .task { await loadWeekData() }
            .onChange(of: weekOffset) { _, _ in
                Task { await loadWeekData() }
            }
        }
    }

    private func loadWeekData() async {
        isLoading = true
        weekLogs = await syncManager.fetchWeeklyMealLogs(for: weekDates)
        isLoading = false
    }

    // MARK: - Week Selector

    private var weekSelectorView: some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
            }

            Spacer()

            Text(weekLabel)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()

            Button {
                if weekOffset < 0 { weekOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(weekOffset < 0 ? Color.fitTextSecondary : Color.fitTextTertiary)
            }
            .disabled(weekOffset >= 0)
        }
        .padding(.top, 4)
    }

    // MARK: - Summary Card

    private var summaryCardView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.fitGreen, Color.fitGreenDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TB Calo / ngày")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                    Text(avgCalories > 0 ? "\(avgCalories)" : "–")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("kcal · \(daysOnGoal)/7 ngày đạt mục tiêu")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                VStack(spacing: 4) {
                    let pct = daysOnGoal > 0 ? Int(Double(daysOnGoal) / 7 * 100) : 0
                    Text("\(pct)%")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Đạt mục tiêu")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(20)
        }
    }

    // MARK: - Bar Chart

    private var barChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CALO THEO NGÀY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .tracking(1)
                Spacer()
                Text("Mục tiêu: \(calorieGoal)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fitTextSecondary)
            }

            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(weekDates, id: \.self) { day in
                        let cal = Calendar.current
                        let isToday = cal.isDateInToday(day)
                        let kcal = caloriesFor(day)
                        let maxHeight: CGFloat = 100
                        let barH = kcal > 0
                            ? max(14, CGFloat(kcal) / CGFloat(calorieGoal) * maxHeight)
                            : 14

                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: isToday ? 8 : 6, style: .continuous)
                                .fill(
                                    kcal == 0
                                    ? Color.fitCard
                                    : (isToday ? Color.fitGreen : Color.fitGreen.opacity(0.35))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: isToday ? 8 : 6, style: .continuous)
                                        .strokeBorder(
                                            kcal > 0 && !isToday ? Color.fitGreen.opacity(0.5) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                                .frame(height: barH)
                                .frame(maxWidth: .infinity)

                            Text(vietWeekdayShort(day))
                                .font(.system(size: 10, weight: isToday ? .bold : .medium))
                                .foregroundStyle(isToday ? Color.fitGreen : Color.fitTextTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: maxHeight + 20, alignment: .bottom)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 4)
            }
            .padding(16)
            .background(Color.fitCard)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Macro Breakdown

    private var macroBreakdownView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PHÂN BỔ DINH DƯỠNG")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)

            let daysWithData = max(1, weekDates.filter { caloriesFor($0) > 0 }.count)
            let avgProtein = totalProtein / Double(daysWithData)
            let avgCarbs = totalCarbs / Double(daysWithData)
            let avgFat = totalFat / Double(daysWithData)

            macroProgressRow("💪 Protein", value: avgProtein, goal: proteinGoal, color: Color.fitIndigo)
            macroProgressRow("🍚 Carbs", value: avgCarbs, goal: carbsGoal, color: Color.fitOrange)
            macroProgressRow("🥑 Fat", value: avgFat, goal: fatGoal, color: Color.fitCoral)
        }
        .padding(16)
        .background(Color.fitCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func macroProgressRow(_ label: String, value: Double, goal: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                Spacer()
                Text(String(format: "%.0fg / %.0fg", value, goal))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.878, green: 0.882, blue: 0.886))
                        .frame(height: 8)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(1, value / goal), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Streak Banner

    private var streakBannerView: some View {
        HStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text("Streak \(daysOnGoal) ngày liên tiếp!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.fitOrange)
                Text("Tiếp tục duy trì để đạt huy hiệu tuần")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fitTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(red: 1.0, green: 0.984, blue: 0.922))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0.988, green: 0.831, blue: 0.302), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Helpers

    private func vietWeekdayShort(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        let map = [1: "CN", 2: "T2", 3: "T3", 4: "T4", 5: "T5", 6: "T6", 7: "T7"]
        return map[weekday] ?? ""
    }
}
