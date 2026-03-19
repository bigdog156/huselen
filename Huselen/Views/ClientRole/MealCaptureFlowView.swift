import SwiftUI

/// Unified meal photo capture + AI analysis flow in a single sheet.
/// Replaces the old 2-sheet flow (camera → dismiss → 600ms delay → analysis sheet).
struct MealCaptureFlowView: View {
    @ObservedObject var viewModel: MealLogViewModel
    let mealType: MealType
    let userId: String
    let onComplete: () -> Void
    let onDismiss: () -> Void

    enum FlowStep {
        case camera
        case analyzing
        case results
    }

    @State private var step: FlowStep = .camera
    @State private var capturedImage: UIImage?

    var body: some View {
        ZStack {
            switch step {
            case .camera:
                cameraStep

            case .analyzing:
                analyzingStep

            case .results:
                resultsStep
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Camera Step

    private var cameraStep: some View {
        LocketCameraView(title: mealType.displayName, useBackCamera: true) { data in
            guard let image = UIImage(data: data) else { return }
            capturedImage = image
            step = .analyzing
            // Auto-analyze immediately
            Task {
                let context = viewModel.userMealNote.isEmpty ? nil : viewModel.userMealNote
                await viewModel.analyzeMealImage(image, userContext: context)
                step = .results
            }
        }
    }

    // MARK: - Analyzing Step

    private var analyzingStep: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                // Photo preview
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 20)
                }

                // Loading skeleton
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.fitGreen)
                            .symbolEffect(.variableColor.iterative, options: .repeating)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Đang phân tích bữa ăn...")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.fitTextPrimary)
                            Text("AI đang nhận diện món ăn và tính calo")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.fitTextSecondary)
                        }
                    }

                    // Skeleton loading bars
                    VStack(spacing: 10) {
                        skeletonBar(width: 0.9)
                        skeletonBar(width: 0.7)
                        skeletonBar(width: 0.5)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.fitCard)
                )
                .padding(.horizontal, 20)

                Spacer()

                // Cancel button
                Button {
                    viewModel.clearAnalysisResult()
                    capturedImage = nil
                    step = .camera
                } label: {
                    Text("Huỷ bỏ")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }
                .padding(.bottom, 32)
            }
            .padding(.top, 20)
        }
    }

    private func skeletonBar(width: CGFloat) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.fitTextTertiary.opacity(0.15))
                .frame(width: geo.size.width * width, height: 14)
                .shimmering()
        }
        .frame(height: 14)
    }

    // MARK: - Results Step

    private var resultsStep: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo preview
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                // Retake button on photo
                                Button {
                                    viewModel.clearAnalysisResult()
                                    capturedImage = nil
                                    step = .camera
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Chụp lại")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(.black.opacity(0.55)))
                                }
                                .padding(10)
                            }
                            .padding(.horizontal, 16)
                    }

                    // User Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ghi chú của bạn")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.fitTextSecondary)

                        TextField("Thêm mô tả về bữa ăn...", text: $viewModel.userMealNote, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(2...4)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 16)

                    // Error state
                    if let error = viewModel.analysisError {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.orange)

                            Text("Không thể phân tích")
                                .font(.system(size: 16, weight: .semibold))

                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.fitTextSecondary)
                                .multilineTextAlignment(.center)

                            Button {
                                if let image = capturedImage {
                                    step = .analyzing
                                    Task {
                                        let context = viewModel.userMealNote.isEmpty ? nil : viewModel.userMealNote
                                        await viewModel.analyzeMealImage(image, userContext: context)
                                        step = .results
                                    }
                                }
                            } label: {
                                Label("Thử lại", systemImage: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color.fitGreen))
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.fitCard)
                        )
                        .padding(.horizontal, 16)
                    }

                    // Analysis results
                    if viewModel.analysisResult != nil {
                        // Calorie summary
                        CalorieSummaryCard(
                            calories: viewModel.editingCalories,
                            protein: viewModel.editingProtein,
                            carbs: viewModel.editingCarbs,
                            fat: viewModel.editingFat
                        )
                        .padding(.horizontal, 16)

                        // Meal description
                        if let description = viewModel.mealDescription {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mô tả")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.fitTextSecondary)
                                Text(description)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.fitTextPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.fitCard)
                            )
                            .padding(.horizontal, 16)
                        }

                        // Detected foods
                        if !viewModel.editingFoodItems.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Các món ăn phát hiện")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.fitTextSecondary)
                                    .padding(.horizontal, 16)

                                ForEach(viewModel.editingFoodItems) { item in
                                    DetectedFoodRow(item: item)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Health note
                        if let note = viewModel.healthNote {
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.yellow)
                                Text(note)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.fitTextPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.yellow.opacity(0.1))
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 120)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Kết quả phân tích")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Huỷ") { dismissFlow() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    // Save button
                    Button { saveAndDismiss() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(viewModel.analysisResult != nil ? "Lưu bữa ăn" : "Lưu chỉ với ảnh")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.fitGreen)
                        )
                    }

                    // Re-analyze with note context
                    if viewModel.analysisResult != nil && !viewModel.userMealNote.isEmpty {
                        Button {
                            if let image = capturedImage {
                                step = .analyzing
                                Task {
                                    await viewModel.analyzeMealImage(image, userContext: viewModel.userMealNote)
                                    step = .results
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "wand.and.stars")
                                Text("Phân tích lại với ghi chú")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.fitGreen)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        Task {
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
            viewModel.clearAnalysisResult()
            onComplete()
        }
    }

    private func dismissFlow() {
        viewModel.clearAnalysisResult()
        capturedImage = nil
        onDismiss()
    }
}

// MARK: - Shimmer Effect

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
