import SwiftUI

// MARK: - Meal Plan Editor View
/// PT creates/edits a meal plan for a client: daily calorie & macro targets,
/// optional per-meal-type targets, and day-by-day scheduling.

struct MealPlanEditorView: View {
    let client: Client

    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var planName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    // Daily targets
    @State private var calorieGoal: Int
    @State private var proteinGoal: Double
    @State private var carbsGoal: Double
    @State private var fatGoal: Double

    // Per-meal targets toggle
    @State private var usePerMealTargets = false
    @State private var mealTargets: [MealType: MealMacroTarget] = [:]

    // Selected day for day-by-day editing
    @State private var selectedDayIndex = 0
    @State private var showSaveConfirm = false

    // MARK: - Init

    init(client: Client) {
        self.client = client
        _calorieGoal = State(initialValue: client.calorieGoal)
        _proteinGoal = State(initialValue: client.proteinGoal)
        _carbsGoal = State(initialValue: client.carbsGoal)
        _fatGoal = State(initialValue: client.fatGoal)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                planHeaderSection
                dateRangeSection
                dailyTargetsSection
                if usePerMealTargets { perMealTargetsSection }
                dayByDayPreview
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Theme.Colors.screenBackground)
        .navigationTitle("Ke hoach dinh duong")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Huy") { dismiss() }
                    .foregroundStyle(Color.fitTextSecondary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Luu") { showSaveConfirm = true }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.fitGreen)
            }
        }
        .confirmationDialog(
            "Luu ke hoach dinh duong cho \(client.name)?",
            isPresented: $showSaveConfirm,
            titleVisibility: .visible
        ) {
            Button("Luu ke hoach") {
                Task {
                    await savePlan()
                    dismiss()
                }
            }
            Button("Huy", role: .cancel) {}
        }
        .onAppear { setupDefaultMealTargets() }
    }

    // MARK: - Plan Header

    private var planHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Client info bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.fitGreen)
                        .frame(width: 44, height: 44)
                    let initials = client.name.split(separator: " ")
                        .compactMap { $0.first }
                        .suffix(2)
                        .map { String($0) }
                        .joined()
                        .uppercased()
                    Text(initials.isEmpty ? "HV" : initials)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(client.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    if !client.goal.isEmpty {
                        Text(client.goal)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.fitTextSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Body stats badges
                if client.weight > 0 {
                    VStack(spacing: 2) {
                        Text("\(Int(client.weight))kg")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fitTextPrimary)
                        Text("Can nang")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.fitCard)
                    )
                }
            }

            // Plan name
            VStack(alignment: .leading, spacing: 4) {
                Text("TEN KE HOACH")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .tracking(0.8)
                TextField("VD: Giam mo - Giai doan 1", text: $planName)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .cuteTextField()
            }
        }
        .cuteCard()
    }

    // MARK: - Date Range

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THOI GIAN AP DUNG")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(0.8)

            HStack(spacing: 12) {
                // Start date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bat dau")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.fitGreen)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)

                // End date
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ket thuc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                    DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .labelsHidden()
                        .tint(Color.fitGreen)
                }
                .frame(maxWidth: .infinity)
            }

            // Duration badge
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                Text("\(days) ngay")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.fitGreen)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.fitGreen.opacity(0.12)))
        }
        .cuteCard()
    }

    // MARK: - Daily Calorie & Macro Targets

    private var dailyTargetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MUC TIEU HANG NGAY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(0.8)

            // Calorie hero
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.fitOrange)
                    Text("Calo muc tieu")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    Spacer()
                    Text("\(calorieGoal) kcal")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitOrange)
                }

                Slider(
                    value: Binding(
                        get: { Double(calorieGoal) },
                        set: { calorieGoal = Int($0) }
                    ),
                    in: 1200...4000,
                    step: 50
                )
                .tint(Color.fitOrange)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(Color.fitOrange.opacity(0.06))
            )

            // Macro breakdown
            VStack(spacing: 12) {
                macroSliderRow(
                    icon: "dumbbell.fill",
                    label: "Protein (Dam)",
                    value: $proteinGoal,
                    range: 50...300,
                    step: 5,
                    color: .fitIndigo,
                    unit: "g"
                )
                macroSliderRow(
                    icon: "leaf.fill",
                    label: "Carbs (Tinh bot)",
                    value: $carbsGoal,
                    range: 50...500,
                    step: 10,
                    color: .fitBlue,
                    unit: "g"
                )
                macroSliderRow(
                    icon: "drop.fill",
                    label: "Fat (Chat beo)",
                    value: $fatGoal,
                    range: 20...200,
                    step: 5,
                    color: .fitCoral,
                    unit: "g"
                )
            }

            // Macro distribution visual
            macroPiePreview
        }
        .cuteCard()
    }

    private func macroSliderRow(
        icon: String,
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        color: Color,
        unit: String
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
                Spacer()
                Text("\(Int(value.wrappedValue))\(unit)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }

            Slider(value: value, in: range, step: step)
                .tint(color)
        }
    }

    private var macroPiePreview: some View {
        let proteinCal = proteinGoal * 4
        let carbsCal = carbsGoal * 4
        let fatCal = fatGoal * 9
        let total = proteinCal + carbsCal + fatCal
        let proteinPct = total > 0 ? Int(proteinCal / total * 100) : 0
        let carbsPct = total > 0 ? Int(carbsCal / total * 100) : 0
        let fatPct = total > 0 ? Int(fatCal / total * 100) : 0
        let estimatedCal = Int(total)

        return VStack(spacing: 8) {
            HStack {
                Text("Phan bo dinh duong")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
                Spacer()
                Text("~ \(estimatedCal) kcal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
            }

            // Horizontal macro bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fitIndigo)
                        .frame(width: geo.size.width * CGFloat(proteinPct) / 100)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fitBlue)
                        .frame(width: geo.size.width * CGFloat(carbsPct) / 100)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.fitCoral)
                        .frame(width: geo.size.width * CGFloat(fatPct) / 100)
                }
            }
            .frame(height: 10)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(Color.fitIndigo).frame(width: 6, height: 6)
                    Text("P \(proteinPct)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.fitBlue).frame(width: 6, height: 6)
                    Text("C \(carbsPct)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.fitCoral).frame(width: 6, height: 6)
                    Text("F \(fatPct)%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: - Per-Meal Targets

    private var perMealTargetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MUC TIEU TUNG BUA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .tracking(0.8)
                Spacer()
                Toggle("", isOn: $usePerMealTargets)
                    .labelsHidden()
                    .tint(Color.fitGreen)
            }

            ForEach(MealType.allCases.sorted(by: { $0.order < $1.order }), id: \.self) { mealType in
                if let target = mealTargets[mealType] {
                    MealTargetRow(
                        mealType: mealType,
                        target: Binding(
                            get: { target },
                            set: { mealTargets[mealType] = $0 }
                        )
                    )
                }
            }
        }
        .cuteCard()
    }

    // MARK: - Day-by-Day Preview

    private var dayByDayPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("XEM TRUOC KE HOACH")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(0.8)

            // Day tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<min(7, dayCount), id: \.self) { i in
                        let date = Calendar.current.date(byAdding: .day, value: i, to: startDate) ?? startDate
                        let isSelected = i == selectedDayIndex

                        Button {
                            selectedDayIndex = i
                        } label: {
                            VStack(spacing: 2) {
                                Text(vietWeekdayShort(date))
                                    .font(.system(size: 9, weight: .medium))
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                            }
                            .foregroundStyle(isSelected ? .white : Color.fitTextSecondary)
                            .frame(width: 40, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isSelected ? Color.fitGreen : Color.fitCard)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Day summary preview
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.fitOrange)
                    Text("\(calorieGoal) kcal")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    Spacer()
                }

                if usePerMealTargets {
                    ForEach(MealType.allCases.sorted(by: { $0.order < $1.order }), id: \.self) { mealType in
                        if let target = mealTargets[mealType] {
                            HStack(spacing: 8) {
                                Image(systemName: mealType.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(mealType.color)
                                    .frame(width: 20)
                                Text(mealType.shortName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.fitTextPrimary)
                                Spacer()
                                Text("\(target.calories) kcal")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.fitTextSecondary)
                                Text("P:\(Int(target.protein))g C:\(Int(target.carbs))g F:\(Int(target.fat))g")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.fitTextTertiary)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        macroPreviewChip("Dam", value: proteinGoal, color: .fitIndigo)
                        macroPreviewChip("Carbs", value: carbsGoal, color: .fitBlue)
                        macroPreviewChip("Beo", value: fatGoal, color: .fitCoral)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(Color.fitCard)
            )
        }
        .cuteCard()
    }

    private func macroPreviewChip(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(Int(value))g \(label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.fitTextSecondary)
        }
    }

    // MARK: - Helpers

    private var dayCount: Int {
        max(1, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
    }

    private func vietWeekdayShort(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        let map = [1: "CN", 2: "T2", 3: "T3", 4: "T4", 5: "T5", 6: "T6", 7: "T7"]
        return map[weekday] ?? ""
    }

    private func setupDefaultMealTargets() {
        for mealType in MealType.allCases {
            if mealTargets[mealType] == nil {
                let fraction: Double
                switch mealType {
                case .breakfast: fraction = 0.25
                case .lunch: fraction = 0.35
                case .afternoon: fraction = 0.10
                case .dinner: fraction = 0.30
                }
                mealTargets[mealType] = MealMacroTarget(
                    calories: Int(Double(calorieGoal) * fraction),
                    protein: proteinGoal * fraction,
                    carbs: carbsGoal * fraction,
                    fat: fatGoal * fraction
                )
            }
        }
    }

    private func savePlan() async {
        await syncManager.updateClientNutritionGoals(
            clientId: client.id,
            calorieGoal: calorieGoal,
            proteinGoal: proteinGoal,
            carbsGoal: carbsGoal,
            fatGoal: fatGoal
        )
    }
}

// MARK: - Meal Macro Target

struct MealMacroTarget {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
}

// MARK: - Meal Target Row

struct MealTargetRow: View {
    let mealType: MealType
    @Binding var target: MealMacroTarget

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(mealType.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: mealType.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(mealType.color)
                    }

                    Text(mealType.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)

                    Spacer()

                    Text("\(target.calories) kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mealType.color)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.fitTextTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    macroField("Calo", value: Binding(
                        get: { Double(target.calories) },
                        set: { target.calories = Int($0) }
                    ), range: 100...2000, step: 25, unit: "kcal", color: mealType.color)

                    macroField("Protein", value: $target.protein, range: 5...150, step: 5, unit: "g", color: .fitIndigo)
                    macroField("Carbs", value: $target.carbs, range: 10...250, step: 5, unit: "g", color: .fitBlue)
                    macroField("Fat", value: $target.fat, range: 5...100, step: 5, unit: "g", color: .fitCoral)
                }
                .padding(.top, 10)
                .padding(.leading, 42)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    private func macroField(
        _ label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        color: Color
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.fitTextSecondary)
                .frame(width: 50, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .tint(color)
            Text("\(Int(value.wrappedValue))\(unit)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 55, alignment: .trailing)
        }
    }
}
