import SwiftUI

struct AddFoodView: View {
    @Binding var mealEntries: [MealEntry]
    let date: Date
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMealType: MealEntry.MealType = .breakfast
    @State private var searchText = ""
    @State private var selectedFood: FoodItem?
    @State private var quantity: Double = 100
    @State private var showCustomEntry = false

    private var filteredFoods: [FoodItem] {
        let pool = FoodItem.popularFoods
        guard !searchText.isEmpty else { return pool }
        return pool.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var recentFoods: [FoodItem] { FoodItem.recentFoods }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Meal type selector
                mealTypePillsView
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                // Search bar
                searchBarView
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        // Recent foods
                        if searchText.isEmpty {
                            foodSection(title: "GẦN ĐÂY", foods: recentFoods)
                        }

                        // Popular / search results
                        foodSection(
                            title: searchText.isEmpty ? "PHỔ BIẾN" : "KẾT QUẢ",
                            foods: filteredFoods,
                            showSeeAll: searchText.isEmpty
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Thêm thức ăn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                }
            }
            .sheet(item: $selectedFood) { food in
                FoodDetailSheet(food: food, mealType: selectedMealType, date: date, mealEntries: $mealEntries)
            }
        }
    }

    // MARK: - Meal Type Pills

    private var mealTypePillsView: some View {
        HStack(spacing: 8) {
            ForEach(MealEntry.MealType.allCases, id: \.self) { type in
                Button {
                    selectedMealType = type
                } label: {
                    Text(type.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectedMealType == type ? .white : Color(red: 0.420, green: 0.447, blue: 0.502))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedMealType == type
                                      ? Color(red: 0.133, green: 0.773, blue: 0.369)
                                      : Color(red: 0.965, green: 0.969, blue: 0.973))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))

            TextField("Tìm thực phẩm...", text: $searchText)
                .font(.system(size: 14))

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(red: 0.941, green: 0.992, blue: 0.957))
                        .frame(width: 30, height: 30)
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color(red: 0.965, green: 0.969, blue: 0.973))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Food Section

    private func foodSection(title: String, foods: [FoodItem], showSeeAll: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))
                    .tracking(1)
                Spacer()
                if showSeeAll {
                    Text("Xem tất cả")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                }
            }

            VStack(spacing: 6) {
                ForEach(foods) { food in
                    FoodRowView(food: food) {
                        selectedFood = food
                    }
                }
            }
        }
    }
}

// MARK: - Food Row

struct FoodRowView: View {
    let food: FoodItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Dot indicator
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                    Text("\(food.caloriesPer100g) kcal · 100g")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.420, green: 0.447, blue: 0.502))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text("P \(Int(food.proteinPer100g))g")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                    Text("C \(Int(food.carbsPer100g))g")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.851, green: 0.467, blue: 0.024))

                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 0.133, green: 0.773, blue: 0.369))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(red: 0.965, green: 0.969, blue: 0.973))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dotColor: Color {
        switch food.name {
        case _ where food.proteinPer100g > 20: return Color(red: 0.388, green: 0.400, blue: 0.945)
        case _ where food.fatPer100g > 10: return Color(red: 1.0, green: 0.420, blue: 0.420)
        default: return Color(red: 0.133, green: 0.773, blue: 0.369)
        }
    }
}

// MARK: - Food Detail Sheet

struct FoodDetailSheet: View {
    let food: FoodItem
    let mealType: MealEntry.MealType
    let date: Date
    @Binding var mealEntries: [MealEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Double = 100

    private var scaledCalories: Int { Int(Double(food.caloriesPer100g) * quantity / 100) }
    private var scaledProtein: Double { food.proteinPer100g * quantity / 100 }
    private var scaledCarbs: Double { food.carbsPer100g * quantity / 100 }
    private var scaledFat: Double { food.fatPer100g * quantity / 100 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Food header
                VStack(spacing: 8) {
                    Text(food.emoji)
                        .font(.system(size: 56))
                    Text(food.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                }
                .padding(.top, 8)

                // Macro summary
                HStack(spacing: 12) {
                    macroStat(label: "Calories", value: "\(scaledCalories)", unit: "kcal", color: Color(red: 0.133, green: 0.773, blue: 0.369))
                    macroStat(label: "Protein", value: String(format: "%.1f", scaledProtein), unit: "g", color: Color(red: 0.388, green: 0.400, blue: 0.945))
                    macroStat(label: "Carbs", value: String(format: "%.1f", scaledCarbs), unit: "g", color: Color(red: 0.851, green: 0.467, blue: 0.024))
                    macroStat(label: "Fat", value: String(format: "%.1f", scaledFat), unit: "g", color: Color(red: 1.0, green: 0.420, blue: 0.420))
                }
                .padding(.horizontal, 20)

                // Quantity stepper
                VStack(spacing: 12) {
                    Text("Khối lượng")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))
                    HStack(spacing: 20) {
                        Button {
                            quantity = max(10, quantity - 10)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(red: 0.965, green: 0.969, blue: 0.973))
                        }

                        Text("\(Int(quantity))g")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.102, green: 0.102, blue: 0.102))
                            .frame(minWidth: 80)

                        Button {
                            quantity += 10
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color(red: 0.133, green: 0.773, blue: 0.369))
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.965, green: 0.969, blue: 0.973))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)

                Spacer()

                // Add button
                Button {
                    let entry = MealEntry(
                        name: food.name,
                        description: "\(Int(quantity))g",
                        calories: scaledCalories,
                        protein: scaledProtein,
                        carbs: scaledCarbs,
                        fat: scaledFat,
                        mealType: mealType,
                        date: date
                    )
                    mealEntries.append(entry)
                    dismiss()
                } label: {
                    Text("Thêm vào \(mealType.rawValue)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.133, green: 0.773, blue: 0.369), Color(red: 0.086, green: 0.639, blue: 0.290)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Huỷ") { dismiss() }.foregroundStyle(.secondary)
                }
            }
        }
    }

    private func macroStat(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 0.612, green: 0.639, blue: 0.675))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
