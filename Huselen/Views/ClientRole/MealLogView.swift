//
//  MealLogView.swift
//  HuselenClient
//
//  Created by Le Thach lam on 17/12/25.
//

import SwiftUI
import AVFoundation
internal import Combine

struct MealLogView: View {
    @StateObject private var viewModel = MealLogViewModel()
    @State private var showDatePicker = false
    @State private var captureForMealType: MealType?
    @State private var capturedImage: UIImage?
    @State private var showAnalysisSheet = false
    @State private var pendingMealType: MealType?
    
    let userId: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week Calendar
                weekCalendarView
                
                Divider()
                
                // Meal List
                ScrollView {
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
                        DinnerSectionView(
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
                            }
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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nhật ký ăn uống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
            .task {
                viewModel.initializeWeekDates()
                await viewModel.loadMeals(userId: userId)
                viewModel.calculateDailyNutrition()
            }
            .sheet(item: $captureForMealType) { mealType in
                MealPhotoCapture(
                    mealType: mealType,
                    onCapture: { image in
                        let selectedMealType = mealType
                        capturedImage = image
                        pendingMealType = selectedMealType
                        captureForMealType = nil
                        
                        // Show analysis sheet first, let user add note before analysis
                        showAnalysisSheet = true
                    },
                    onDismiss: {
                        captureForMealType = nil
                    }
                )
            }
            .sheet(isPresented: $showAnalysisSheet) {
                MealAnalysisResultSheet(
                    viewModel: viewModel,
                    image: capturedImage,
                    mealType: pendingMealType ?? .breakfast,
                    onSave: {
                        Task {
                            if let mealType = pendingMealType {
                                // Combine user note with AI description
                                let combinedNote: String? = {
                                    let userNote = viewModel.userMealNote.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let aiDescription = viewModel.mealDescription ?? ""
                                    
                                    if !userNote.isEmpty && !aiDescription.isEmpty {
                                        return "\(userNote)\n\n\(aiDescription)"
                                    } else if !userNote.isEmpty {
                                        return userNote
                                    } else if !aiDescription.isEmpty {
                                        return aiDescription
                                    }
                                    return nil
                                }()
                                
                                await viewModel.saveMealWithNutrition(
                                    userId: userId,
                                    mealType: mealType,
                                    photo: capturedImage,
                                    note: combinedNote,
                                    feeling: nil,
                                    calories: viewModel.editingCalories > 0 ? viewModel.editingCalories : nil,
                                    proteinG: viewModel.editingProtein > 0 ? viewModel.editingProtein : nil,
                                    carbsG: viewModel.editingCarbs > 0 ? viewModel.editingCarbs : nil,
                                    fatG: viewModel.editingFat > 0 ? viewModel.editingFat : nil,
                                    foodItems: viewModel.editingFoodItems.isEmpty ? nil : viewModel.editingFoodItems
                                )
                            }
                            showAnalysisSheet = false
                            capturedImage = nil
                            pendingMealType = nil
                            viewModel.clearAnalysisResult()
                        }
                    },
                    onDismiss: {
                        showAnalysisSheet = false
                        capturedImage = nil
                        pendingMealType = nil
                        viewModel.clearAnalysisResult()
                    }
                )
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(
                    selectedDate: viewModel.selectedDate,
                    onSelect: { date in
                        Task {
                            await viewModel.selectDate(date, userId: userId)
                        }
                        showDatePicker = false
                    },
                    onDismiss: {
                        showDatePicker = false
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
    private var weekCalendarView: some View {
        VStack(spacing: 8) {
            // Month header with navigation
            HStack {
                // Previous month button
                Button {
                    viewModel.goToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                }
                
                Spacer()
                
                Text(viewModel.currentMonthYear)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Next month button (disabled if current month)
                Button {
                    viewModel.goToNextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.isCurrentMonth ? .gray.opacity(0.4) : .blue)
                        .frame(width: 32, height: 32)
                }
                .disabled(viewModel.isCurrentMonth)
                
                // Today button
                if !viewModel.isCurrentMonth {
                    Button {
                        viewModel.goToToday()
                        Task {
                            await viewModel.selectDate(Date(), userId: userId)
                        }
                    } label: {
                        Text("Hôm nay")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Scrollable dates
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.weekDates.enumerated()), id: \.element) { index, date in
                            Button {
                                Task {
                                    await viewModel.selectDate(date, userId: userId)
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(viewModel.dayName(for: date))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(
                                            viewModel.isSelected(date) ? .white :
                                                viewModel.isDateToday(date) ? .blue : .secondary
                                        )
                                    
                                    Text(viewModel.dayNumber(for: date))
                                        .font(.system(size: 16, weight: viewModel.isSelected(date) ? .bold : .medium))
                                        .foregroundColor(
                                            viewModel.isSelected(date) ? .white :
                                                viewModel.isDateToday(date) ? .blue : .primary
                                        )
                                }
                                .frame(width: 44, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.isSelected(date) ? Color.blue : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            viewModel.isDateToday(date) && !viewModel.isSelected(date) ? Color.blue : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    // Auto-scroll to today on first appear
                    if let todayIndex = viewModel.todayIndex {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(todayIndex, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: viewModel.displayedMonth) { _ in
                    // Scroll to first day when month changes, or to selected date if in this month
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            if let selectedIndex = viewModel.selectedDateIndex {
                                proxy.scrollTo(selectedIndex, anchor: .center)
                            } else if let todayIndex = viewModel.todayIndex {
                                proxy.scrollTo(todayIndex, anchor: .center)
                            } else {
                                proxy.scrollTo(0, anchor: .leading)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Meal Section View
struct MealSectionView: View {
    let mealType: MealType
    let mealLog: UserMealLog?
    let onTapPhoto: () -> Void
    let onSaveNote: (String) -> Void
    let onDelete: () -> Void
    
    @State private var noteText: String = ""
    @State private var showMenu = false
    @FocusState private var isNoteFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
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
            
            // Content - Locket Style 1:1 Photo
            if let log = mealLog, let photoUrl = log.photoUrl, let url = URL(string: photoUrl) {
                // Photo Card - Locket Style
                LocketStylePhotoCard(
                    url: url,
                    note: log.note,
                    onDelete: onDelete
                )
            } else {
                // Empty state - Photo capture area (1:1 ratio)
                Button {
                    onTapPhoto()
                } label: {
                    GeometryReader { geometry in
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
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
                                .foregroundColor(Color(.systemGray4))
                        )
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            
            // Note Input - Always visible below photo/empty state
            VStack(alignment: .leading, spacing: 8) {
                // Show existing note if any (read-only display)
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
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // Note input field
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
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                )
            }
            
            // Calorie display (if meal has calories)
            if let calories = mealLog?.calories, calories > 0 {
                MealCalorieDisplay(mealLog: mealLog)
            }
            
            // Feeling selector (only show if meal has content)
            if mealLog?.hasContent == true {
                feelingSelector
            }
        }
        .onAppear {
            noteText = mealLog?.note ?? ""
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
                            .fill(Color(.systemGray5))
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
                            .fill(Color(.systemGray5))
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

// MARK: - Dinner Section View (Collapsible)
struct DinnerSectionView: View {
    let mealLog: UserMealLog?
    let onTapPhoto: () -> Void
    let onSaveNote: (String) -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    @State private var noteText: String = ""
    @FocusState private var isNoteFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(MealType.dinner.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("TÙY CHỌN")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray5))
                        )
                    
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
            
            // Content (when expanded or has content)
            if isExpanded || mealLog?.hasContent == true {
                // Content - Locket Style 1:1 Photo
                if let log = mealLog, let photoUrl = log.photoUrl, let url = URL(string: photoUrl) {
                    // Photo Card - Locket Style
                    LocketStylePhotoCard(
                        url: url,
                        note: log.note,
                        onDelete: onDelete
                    )
                } else {
                    // Empty state - Photo capture area (1:1 ratio)
                    Button {
                        onTapPhoto()
                    } label: {
                        GeometryReader { geometry in
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(.systemGray5))
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
                                
                                Text(MealType.dinner.photoPlaceholder)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: geometry.size.width, height: geometry.size.width) // 1:1 ratio
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8]))
                                    .foregroundColor(Color(.systemGray4))
                            )
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
                
                // Note Input - Same style as MealSectionView
                VStack(alignment: .leading, spacing: 8) {
                    // Show existing note if any (read-only display)
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
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Note input field
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
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                    )
                }
                
                // Calorie display (if meal has calories)
                if let calories = mealLog?.calories, calories > 0 {
                    MealCalorieDisplay(mealLog: mealLog)
                }
            }
        }
        .onAppear {
            noteText = mealLog?.note ?? ""
        }
    }
}

// MARK: - Meal Photo Capture (Locket Style)
struct MealPhotoCapture: View {
    let mealType: MealType
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var cameraManager = MealCameraManager()
    @State private var capturedImage: UIImage?
    @State private var showPreview = false
    @State private var cameraReady = false
    @State private var isCapturing = false
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showPreview, let image = capturedImage {
                // Preview captured image
                previewView(image: image)
            } else {
                // Camera capture view
                cameraView
            }
        }
        .onAppear {
            // Ensure camera starts when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                cameraManager.startSession()
                cameraReady = true
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Camera View
    private var cameraView: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let squareSize = screenWidth - 40
            
            ZStack {
                // Full screen camera preview
                MealCameraPreview(session: cameraManager.session)
                    .frame(width: screenWidth, height: screenHeight)
                
                // Dark overlay with rounded square cutout
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                                .fill(Color.white)
                            
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.black)
                                .frame(width: squareSize, height: squareSize)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                
                // Viewfinder border - matches the cutout exactly
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: squareSize, height: squareSize)
                
                // UI Overlay
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .environment(\.colorScheme, .dark)
                                )
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(mealType.displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Flash toggle
                        Button {
                            cameraManager.toggleFlash()
                        } label: {
                            Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .environment(\.colorScheme, .dark)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Capture button
                    Button {
                        isCapturing = true
                        cameraManager.capturePhoto { image in
                            isCapturing = false
                            if let image = image {
                                // First normalize orientation, then crop
                                let normalizedImage = normalizeImageOrientation(image)
                                let croppedImage = cropToSquare(
                                    image: normalizedImage,
                                    viewfinderSize: squareSize,
                                    screenSize: geometry.size
                                )
                                capturedImage = croppedImage
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showPreview = true
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 85, height: 85)
                            
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 75, height: 75)
                            
                            if isCapturing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    }
                    .disabled(!cameraReady || isCapturing)
                    .padding(.bottom, 50)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Preview View
    private func previewView(image: UIImage) -> some View {
        GeometryReader { geometry in
            let squareSize = geometry.size.width - 40
            
            VStack {
                // Top bar
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showPreview = false
                            capturedImage = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Chụp lại")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                    }
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Preview image - Locket style
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: squareSize, height: squareSize)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Spacer()
                
                // Confirm button
                Button {
                    isSaving = true
                    onCapture(image)
                } label: {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                        }
                        Text(isSaving ? "Đang lưu..." : "Sử dụng ảnh này")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSaving ? Color.blue.opacity(0.7) : Color.blue)
                    )
                }
                .disabled(isSaving)
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
        }
    }
    
    // MARK: - Normalize Image Orientation
    private func normalizeImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
    
    // MARK: - Crop to Square
    private func cropToSquare(image: UIImage, viewfinderSize: CGFloat, screenSize: CGSize) -> UIImage {
        let imageSize = image.size
        
        // Camera uses aspectFill - image fills the screen
        // Calculate which dimension is the constraint
        let screenAspect = screenSize.width / screenSize.height
        let imageAspect = imageSize.width / imageSize.height
        
        var displayedWidth: CGFloat
        var displayedHeight: CGFloat
        var imageOffsetX: CGFloat = 0
        var imageOffsetY: CGFloat = 0
        
        if imageAspect > screenAspect {
            // Image is wider - height fills screen
            displayedHeight = imageSize.height
            displayedWidth = screenSize.width * (imageSize.height / screenSize.height)
            imageOffsetX = (imageSize.width - displayedWidth) / 2
        } else {
            // Image is taller - width fills screen
            displayedWidth = imageSize.width
            displayedHeight = screenSize.height * (imageSize.width / screenSize.width)
            imageOffsetY = (imageSize.height - displayedHeight) / 2
        }
        
        // Scale from screen to image coordinates
        let scaleX = displayedWidth / screenSize.width
        let scaleY = displayedHeight / screenSize.height
        
        // Viewfinder center position on screen
        let viewfinderCenterX = screenSize.width / 2
        let viewfinderCenterY = screenSize.height / 2
        
        // Convert to image coordinates
        let imageCropCenterX = imageOffsetX + (viewfinderCenterX * scaleX)
        let imageCropCenterY = imageOffsetY + (viewfinderCenterY * scaleY)
        let imageCropSize = viewfinderSize * scaleX
        
        // Calculate crop rect
        var cropX = imageCropCenterX - (imageCropSize / 2)
        var cropY = imageCropCenterY - (imageCropSize / 2)
        var cropSize = imageCropSize
        
        // Clamp to image bounds
        cropX = max(0, min(cropX, imageSize.width - cropSize))
        cropY = max(0, min(cropY, imageSize.height - cropSize))
        cropSize = min(cropSize, min(imageSize.width - cropX, imageSize.height - cropY))
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
        
        // Perform crop
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            // Fallback: simple center crop
            return simpleCenterCrop(image: image)
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }
    
    // MARK: - Simple Center Crop (Fallback)
    private func simpleCenterCrop(image: UIImage) -> UIImage {
        let size = image.size
        let minDimension = min(size.width, size.height)
        
        let cropRect = CGRect(
            x: (size.width - minDimension) / 2,
            y: (size.height - minDimension) / 2,
            width: minDimension,
            height: minDimension
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
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

// MARK: - Meal Camera Manager
class MealCameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var isSessionRunning = false
    
    private var photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((UIImage?) -> Void)?
    private var currentDevice: AVCaptureDevice?
    private var isConfigured = false
    
    override init() {
        super.init()
        checkPermissionAndSetup()
    }
    
    private func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                }
            }
        default:
            break
        }
    }
    
    func setupCamera() {
        guard !isConfigured else { return }
        
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        
        currentDevice = device
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Remove existing outputs
        session.outputs.forEach { session.removeOutput($0) }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        session.commitConfiguration()
        isConfigured = true
    }
    
    func startSession() {
        guard isConfigured, !session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.session.isRunning ?? false
            }
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard session.isRunning else {
            completion(nil)
            return
        }
        
        captureCompletion = completion
        let settings = AVCapturePhotoSettings()
        
        // Set flash mode
        if let device = currentDevice, device.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
}

extension MealCameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.captureCompletion?(nil)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.captureCompletion?(image)
        }
    }
}

// MARK: - Meal Camera Preview
struct MealCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> MealCameraPreviewUIView {
        let view = MealCameraPreviewUIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        return view
    }
    
    func updateUIView(_ uiView: MealCameraPreviewUIView, context: Context) {
        uiView.setSession(session)
    }
    
    static func dismantleUIView(_ uiView: MealCameraPreviewUIView, coordinator: ()) {
        // Cleanup if needed
    }
}

class MealCameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    func setSession(_ session: AVCaptureSession) {
        // Remove existing layer if any
        previewLayer?.removeFromSuperlayer()
        
        // Create new preview layer
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Daily Nutrition Summary View
struct DailyNutritionSummaryView: View {
    let nutrition: DailyNutritionSummary
    let selectedDate: Date
    let isToday: Bool
    
    private var dateLabel: String {
        if isToday {
            return "Tổng calo hôm nay"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "vi_VN")
            formatter.dateFormat = "dd/MM"
            return "Tổng calo ngày \(formatter.string(from: selectedDate))"
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
                        .stroke(Color(.systemGray5), lineWidth: 6)
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
                .fill(Color(.systemBackground))
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
                    .stroke(Color(.systemGray5), lineWidth: 4)
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
                    .fill(Color(.systemGray6))
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
                .background(Color(.systemGray6))
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
                    .background(Color(.systemBackground))
                    
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
                .fill(Color(.systemGray6))
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
                                .fill(Color(.systemGray6))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
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
                                    .stroke(Color(.systemGray4), lineWidth: 1)
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
                                        .fill(Color(.systemGray6))
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
                    .background(Color(.systemBackground))
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
                .fill(Color(.systemBackground))
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
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    MealLogView(userId: "test-user-id")
}
