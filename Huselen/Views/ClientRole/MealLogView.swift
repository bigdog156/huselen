//
//  MealLogView.swift
//  HuselenClient
//
//  Created by Le Thach lam on 17/12/25.
//

import SwiftUI
internal import Combine

struct MealLogView: View {
    @StateObject private var viewModel = MealLogViewModel()
    @State private var captureForMealType: MealType?
    
    let userId: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Month Calendar with fan photos
                    MealCalendarView(
                        viewModel: viewModel,
                        userId: userId,
                        onSelectDate: { _ in }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.horizontal, 16)

                    // Meal List
                    VStack(spacing: 24) {
                        // Daily Nutrition Summary
                        DailyNutritionSummaryView(
                            nutrition: viewModel.dailyNutrition,
                            selectedDate: viewModel.selectedDate,
                            isToday: viewModel.isToday
                        )

                        // Main meals (Sáng, Trưa, Chiều)
                        ForEach([MealType.breakfast, MealType.lunch, MealType.afternoon], id: \.self) { mealType in
                            MealSectionView(
                                mealType: mealType,
                                mealLog: viewModel.mealLogs[mealType],
                                onTapPhoto: {
                                    captureForMealType = mealType
                                },
                                onSaveNote: { note in
                                    Task {
                                        await viewModel.saveMealLog(
                                            userId: userId,
                                            mealType: mealType,
                                            photo: nil,
                                            note: note,
                                            feeling: nil
                                        )
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deleteMealLog(userId: userId, mealType: mealType)
                                    }
                                }
                            )
                        }

                        // Dinner (Optional) - Collapsible
                        MealSectionView(
                            mealType: .dinner,
                            mealLog: viewModel.mealLogs[.dinner],
                            onTapPhoto: {
                                captureForMealType = .dinner
                            },
                            onSaveNote: { note in
                                Task {
                                    await viewModel.saveMealLog(
                                        userId: userId,
                                        mealType: .dinner,
                                        photo: nil,
                                        note: note,
                                        feeling: nil
                                    )
                                }
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deleteMealLog(userId: userId, mealType: .dinner)
                                }
                            },
                            isCollapsible: true
                        )

                        // Motivational quote
                        Text("\"Eat to nourish, not to punish.\"")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .italic()
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Nhật ký ăn uống")
            .navigationBarTitleDisplayMode(.inline)
            .profileToolbar()
            .task {
                viewModel.initializeWeekDates()
                await viewModel.loadMeals(userId: userId)
                viewModel.calculateDailyNutrition()
            }
            .fullScreenCover(item: $captureForMealType) { mealType in
                MealCaptureFlowView(
                    viewModel: viewModel,
                    mealType: mealType,
                    userId: userId,
                    onComplete: {
                        captureForMealType = nil
                    },
                    onDismiss: {
                        captureForMealType = nil
                    }
                )
            }
            .alert("Lỗi", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    

    // MARK: - Month Calendar View
}

// MARK: - Meal Section View
struct MealSectionView: View {
    let mealType: MealType
    let mealLog: UserMealLog?
    let onTapPhoto: () -> Void
    let onSaveNote: (String) -> Void
    let onDelete: () -> Void
    var isCollapsible: Bool = false

    @State private var isExpanded = false
    @State private var noteText: String = ""
    @FocusState private var isNoteFocused: Bool

    private var shouldShowContent: Bool {
        !isCollapsible || isExpanded || mealLog?.hasContent == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isCollapsible {
                collapsibleHeader
            } else {
                standardHeader
            }

            if shouldShowContent {
                mealContentView
                noteInputView

                if let calories = mealLog?.calories, calories > 0 {
                    MealCalorieDisplay(mealLog: mealLog)
                }

                if mealLog?.hasContent == true && !isCollapsible {
                    feelingSelector
                }
            }
        }
        .onAppear {
            noteText = mealLog?.note ?? ""
        }
    }

    // MARK: - Headers

    private var standardHeader: some View {
        HStack {
            Text(mealType.displayName)
                .font(.system(size: 18, weight: .bold))

            Spacer()

            if let log = mealLog, log.hasContent {
                Text(log.formattedTime)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Text(mealType.placeholder)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var collapsibleHeader: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(mealType.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)

                Text("TÙY CHỌN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.fitCard))

                Spacer()

                if let log = mealLog, log.hasContent {
                    Text(log.formattedTime)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded || mealLog?.hasContent == true ? 180 : 0))
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var mealContentView: some View {
        if let log = mealLog, let photoUrl = log.photoUrl, let url = URL(string: photoUrl) {
            LocketStylePhotoCard(url: url, note: log.note, onDelete: onDelete)
        } else {
            Button { onTapPhoto() } label: {
                GeometryReader { geometry in
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.fitCard)
                                .frame(width: 56, height: 56)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.secondary)

                            // Plus badge
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                )
                                .offset(x: 20, y: -20)
                        }

                        Text(mealType.photoPlaceholder)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width) // 1:1 ratio
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                            .foregroundStyle(Color.fitTextTertiary)
                    )
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    private var noteInputView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let log = mealLog, let existingNote = log.note, !existingNote.isEmpty, noteText.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "note.text")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)

                    Text(existingNote)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .lineLimit(3)

                    Spacer()

                    Button {
                        noteText = existingNote
                        isNoteFocused = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.fitCard))
            }

            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                TextField("Thêm ghi chú cho bữa ăn...", text: $noteText)
                    .font(.system(size: 15))
                    .focused($isNoteFocused)
                    .onSubmit {
                        if !noteText.isEmpty {
                            onSaveNote(noteText)
                            noteText = ""
                        }
                    }

                if !noteText.isEmpty {
                    Button {
                        onSaveNote(noteText)
                        noteText = ""
                        isNoteFocused = false
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.fitCard)
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
        }
    }

    // MARK: - Feeling Selector

    private var feelingSelector: some View {
        HStack(spacing: 16) {
            Text("CẢM NHẬN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1)

            Spacer()

            ForEach(MealFeeling.allCases, id: \.self) { feeling in
                Button {
                    // Handle feeling selection
                } label: {
                    Image(systemName: feeling.icon)
                        .font(.system(size: 20))
                        .foregroundColor(mealLog?.feeling == feeling ? feeling.color : .secondary.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Locket Style Photo Card
struct LocketStylePhotoCard: View {
    let url: URL
    let note: String?
    let onDelete: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Photo with 1:1 aspect ratio
            GeometryReader { geometry in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.fitCard)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.fitCard)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                // Locket style shadow
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
            .aspectRatio(1, contentMode: .fit)
            
            // Menu button - Locket style
            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Xóa", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
            .padding(16)
        }
        
    }
}

// MARK: - Meal Photo Capture (Locket Style)
struct MealPhotoCapture: View {
    let mealType: MealType
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void

    var body: some View {
        LocketCameraView(title: mealType.displayName, useBackCamera: true) { data in
            if let image = UIImage(data: data) {
                onCapture(image)
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void
    let onDismiss: () -> Void
    
    @State private var tempDate: Date
    
    init(selectedDate: Date, onSelect: @escaping (Date) -> Void, onDismiss: @escaping () -> Void) {
        self.selectedDate = selectedDate
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self._tempDate = State(initialValue: selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Chọn ngày",
                    selection: $tempDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Chọn ngày")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chọn") {
                        onSelect(tempDate)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Daily Nutrition Summary View
struct DailyNutritionSummaryView: View {
    let nutrition: DailyNutritionSummary
    let selectedDate: Date
    let isToday: Bool
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()

    private var dateLabel: String {
        if isToday {
            return "Tổng calo hôm nay"
        } else {
            return "Tổng calo ngày \(Self.dateFormatter.string(from: selectedDate))"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(nutrition.totalCalories)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("/ \(nutrition.calorieGoal) kcal")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(Color.fitCard, lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: nutrition.calorieProgress)
                        .stroke(
                            calorieProgressColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(nutrition.calorieProgress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(calorieProgressColor)
                }
            }
            
            // Remaining calories
            if nutrition.remainingCalories > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Còn lại: \(nutrition.remainingCalories) kcal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    
                    Text("Đã đạt mục tiêu calo!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.green)
                }
            }
            
            Divider()
            
            // Macros
            HStack(spacing: 0) {
                MacroProgressView(
                    title: "Protein",
                    value: nutrition.totalProtein,
                    goal: Double(nutrition.proteinGoal),
                    unit: "g",
                    color: .blue
                )
                
                Spacer()
                
                MacroProgressView(
                    title: "Carbs",
                    value: nutrition.totalCarbs,
                    goal: Double(nutrition.carbsGoal),
                    unit: "g",
                    color: .orange
                )
                
                Spacer()
                
                MacroProgressView(
                    title: "Fat",
                    value: nutrition.totalFat,
                    goal: Double(nutrition.fatGoal),
                    unit: "g",
                    color: .pink
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.fitCard)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private var calorieProgressColor: Color {
        if nutrition.calorieProgress < 0.5 {
            return .blue
        } else if nutrition.calorieProgress < 0.8 {
            return .green
        } else if nutrition.calorieProgress < 1.0 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Macro Progress View
struct MacroProgressView: View {
    let title: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    
    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.fitCard, lineWidth: 4)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
            }
            
            Text("\(Int(value))/\(Int(goal))\(unit)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Add Calories Button View
struct AddCaloriesButtonView: View {
    let mealType: MealType
    let currentCalories: Int?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                if let calories = currentCalories, calories > 0 {
                    Text("\(calories) kcal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                } else {
                    Text("Thêm calo")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.fitCard)
            )
        }
    }
}

// MARK: - Food Selection Sheet
struct FoodSelectionSheet: View {
    @ObservedObject var viewModel: MealLogViewModel
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    TextField("Tìm món ăn...", text: $viewModel.searchFoodText)
                        .font(.system(size: 16))
                    
                    if !viewModel.searchFoodText.isEmpty {
                        Button {
                            viewModel.searchFoodText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.fitCard)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Current selections summary
                if !viewModel.editingFoodItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(viewModel.editingFoodItems.enumerated()), id: \.element.id) { index, item in
                                FoodItemChip(
                                    item: item,
                                    onRemove: {
                                        viewModel.removeFoodItem(at: index)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                    .background(Color.fitCard)
                    
                    // Total calories display
                    HStack {
                        Text("Tổng cộng:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(viewModel.calculatedCalories) kcal")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                
                Divider()
                
                // Food list by category
                List {
                    ForEach(CommonFood.FoodCategory.allCases, id: \.self) { category in
                        if let foods = viewModel.foodsByCategory[category], !foods.isEmpty {
                            Section(header: Text(category.rawValue)) {
                                ForEach(foods, id: \.name) { food in
                                    FoodLogRowView(food: food) {
                                        viewModel.addFoodItem(food)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle("Chọn món ăn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        onSave()
                        dismiss()
                    }
                    .disabled(viewModel.editingFoodItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Food Item Chip
struct FoodItemChip: View {
    let item: MealLogFoodItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(item.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Text("\(item.totalCalories)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.fitCard)
        )
    }
}

// MARK: - Food Row View
struct FoodLogRowView: View {
    let food: CommonFood
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: onAdd) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(food.servingSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(food.calories) kcal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 8) {
                        MacroLabel(value: food.proteinG, unit: "P", color: .blue)
                        MacroLabel(value: food.carbsG, unit: "C", color: .orange)
                        MacroLabel(value: food.fatG, unit: "F", color: .pink)
                    }
                }
                
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .padding(.leading, 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Macro Label
struct MacroLabel: View {
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        Text("\(Int(value))\(unit)")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
    }
}

// MARK: - Meal Calorie Display
struct MealCalorieDisplay: View {
    let mealLog: UserMealLog?
    
    var body: some View {
        if let log = mealLog {
            HStack(spacing: 12) {
                // Calories
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    
                    Text("\(log.calories ?? 0) kcal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                Divider()
                    .frame(height: 16)
                
                // Macros
                HStack(spacing: 10) {
                    if let protein = log.proteinG, protein > 0 {
                        MiniMacroView(value: protein, label: "P", color: .blue)
                    }
                    if let carbs = log.carbsG, carbs > 0 {
                        MiniMacroView(value: carbs, label: "C", color: .orange)
                    }
                    if let fat = log.fatG, fat > 0 {
                        MiniMacroView(value: fat, label: "F", color: .pink)
                    }
                }
                
                Spacer()
                
                // Food items count
                if let items = log.foodItems, !items.isEmpty {
                    Text("\(items.count) món")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.fitCard)
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.fitCard)
            )
        }
    }
}

// MARK: - Mini Macro View
struct MiniMacroView: View {
    let value: Double
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text("\(Int(value))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Meal Analysis Result Sheet
struct MealAnalysisResultSheet: View {
    @ObservedObject var viewModel: MealLogViewModel
    let image: UIImage?
    let mealType: MealType
    let onSave: () -> Void
    let onDismiss: () -> Void
    
    @FocusState private var isNoteFocused: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Captured Image
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                    }
                    
                    // User Note Input - Always visible
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ghi chú của bạn")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("Thêm mô tả về bữa ăn của bạn...", text: $viewModel.userMealNote, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(3...6)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Theme.Colors.separator, lineWidth: 1)
                            )
                            .focused($isNoteFocused)
                    }
                    .padding(.horizontal, 16)
                    
                    // Not yet analyzed state - show analyze button
                    if !viewModel.isAnalyzing && viewModel.analysisResult == nil && viewModel.analysisError == nil {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Phân tích dinh dưỡng bằng AI")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Thêm mô tả để AI nhận diện chính xác hơn")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                isNoteFocused = false
                                if let image = image {
                                    Task {
                                        let context = viewModel.userMealNote.isEmpty ? nil : viewModel.userMealNote
                                        await viewModel.analyzeMealImage(image, userContext: context)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("Phân tích ngay")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 20)
                    }
                    
                    // Loading State
                    else if viewModel.isAnalyzing {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Đang phân tích hình ảnh...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("AI đang nhận diện món ăn và tính toán calo")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: 200)
                    }
                    
                    // Error State
                    else if let error = viewModel.analysisError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("Không thể phân tích")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                if let image = image {
                                    Task {
                                        let context = viewModel.userMealNote.isEmpty ? nil : viewModel.userMealNote
                                        await viewModel.analyzeMealImage(image, userContext: context)
                                    }
                                }
                            } label: {
                                Label("Thử lại", systemImage: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Analysis Results
                    else if viewModel.analysisResult != nil {
                        VStack(spacing: 16) {
                            // Calorie Summary Card
                            CalorieSummaryCard(
                                calories: viewModel.editingCalories,
                                protein: viewModel.editingProtein,
                                carbs: viewModel.editingCarbs,
                                fat: viewModel.editingFat
                            )
                            .padding(.horizontal, 16)
                            
                            // Meal Description
                            if let description = viewModel.mealDescription {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Mô tả")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    
                                    Text(description)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.fitCard)
                                )
                                .padding(.horizontal, 16)
                            }
                            
                            // Detected Foods
                            if !viewModel.editingFoodItems.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Các món ăn phát hiện")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                    
                                    ForEach(viewModel.editingFoodItems) { item in
                                        DetectedFoodRow(item: item)
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            
                            // Health Note
                            if let note = viewModel.healthNote {
                                HStack(spacing: 12) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.yellow)
                                    
                                    Text(note)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.yellow.opacity(0.1))
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Kết quả phân tích")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        onSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(viewModel.isAnalyzing)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !viewModel.isAnalyzing {
                    VStack(spacing: 12) {
                        // Show save button with analysis results
                        if viewModel.analysisResult != nil {
                            Button {
                                onSave()
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Lưu bữa ăn")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(14)
                            }
                        }
                        // Show save without analysis option when not yet analyzed
                        else if viewModel.analysisResult == nil && viewModel.analysisError == nil {
                            Button {
                                onSave()
                            } label: {
                                HStack {
                                    Image(systemName: "photo.badge.checkmark")
                                    Text("Lưu chỉ với ảnh")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 1.5)
                                )
                            }
                        }
                        
                        Button {
                            onDismiss()
                        } label: {
                            Text("Huỷ bỏ")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.fitCard)
                }
            }
        }
    }
}

// MARK: - Calorie Summary Card
struct CalorieSummaryCard: View {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var body: some View {
        VStack(spacing: 16) {
            // Main calories
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tổng calo")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(calories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("kcal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
            }
            
            Divider()
            
            // Macros
            HStack(spacing: 0) {
                MacroItemView(title: "Protein", value: protein, unit: "g", color: .blue)
                Spacer()
                MacroItemView(title: "Carbs", value: carbs, unit: "g", color: .orange)
                Spacer()
                MacroItemView(title: "Fat", value: fat, unit: "g", color: .pink)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.fitCard)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }
}

// MARK: - Macro Item View
struct MacroItemView: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detected Food Row
struct DetectedFoodRow: View {
    let item: MealLogFoodItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                if let serving = item.servingSize {
                    Text(serving)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.totalCalories) kcal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                
                HStack(spacing: 6) {
                    if let p = item.proteinG {
                        Text("\(Int(p))P")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    if let c = item.carbsG {
                        Text("\(Int(c))C")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    if let f = item.fatG {
                        Text("\(Int(f))F")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.pink)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.fitCard)
        )
    }
}

#Preview {
    MealLogView(userId: "test-user-id")
}
