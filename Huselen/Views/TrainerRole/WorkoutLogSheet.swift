import SwiftUI

// MARK: - Workout Log Sheet

struct WorkoutLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    let session: TrainingGymSession
    let client: Client

    @State private var exercises: [ExerciseEntry] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showAddExercise = false
    @State private var editingExercise: ExerciseEntry?

    private var sessionId: String { session.id.uuidString }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "EEEE, d 'tháng' M · HH:mm"
        return df
    }()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Đang tải...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }
            }
            .navigationTitle("Ghi chép bài tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Lưu")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseSheet { newEntry in
                    var e = newEntry
                    e.orderIndex = exercises.count
                    exercises.append(e)
                }
            }
            .sheet(item: $editingExercise) { entry in
                AddExerciseSheet(initial: entry) { updated in
                    if let idx = exercises.firstIndex(where: { $0.id == updated.id }) {
                        exercises[idx] = updated
                    }
                }
            }
        }
        .task {
            await syncManager.fetchWorkoutExercises(for: sessionId)
            exercises = syncManager.workoutExercises[sessionId] ?? []
            isLoading = false
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                sessionInfoCard
                exerciseListSection
                addButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Session Info Card

    private var sessionInfoCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(client.name, systemImage: "person.fill")
                    .font(.headline)
                    .foregroundStyle(Color.fitTextPrimary)

                Label(
                    Self.dateFormatter.string(from: session.scheduledDate),
                    systemImage: "calendar"
                )
                .font(.subheadline)
                .foregroundStyle(Color.fitTextSecondary)

                Label("\(session.duration) phút", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(Color.fitTextTertiary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(exercises.count)")
                    .font(.title.bold())
                    .foregroundStyle(Theme.Colors.softOrange)
                Text("bài tập")
                    .font(.caption)
                    .foregroundStyle(Color.fitTextTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: - Exercise List

    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if exercises.isEmpty {
                emptyState
            } else {
                Label("Danh sách bài tập", systemImage: "list.bullet.clipboard")
                    .font(.headline)
                    .foregroundStyle(Color.fitTextPrimary)

                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                    exerciseCard(exercise, index: idx)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.softOrange.opacity(0.5))
            Text("Chưa có bài tập")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.fitTextSecondary)
            Text("Nhấn \"+ Thêm bài tập\" để bắt đầu ghi chép")
                .font(.caption)
                .foregroundStyle(Color.fitTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func exerciseCard(_ exercise: ExerciseEntry, index: Int) -> some View {
        HStack(spacing: 14) {
            // Order badge
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.Colors.softOrange, in: Circle())

            // Exercise info
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                Text(exercise.summary)
                    .font(.caption)
                    .foregroundStyle(Color.fitTextSecondary)
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption2)
                        .foregroundStyle(Color.fitTextTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    editingExercise = exercise
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.softOrange)
                        .padding(8)
                        .background(Theme.Colors.softOrange.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation {
                        exercises.removeAll { $0.id == exercise.id }
                        for i in exercises.indices { exercises[i].orderIndex = i }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(Color.fitCoral)
                        .padding(8)
                        .background(Color.fitCoral.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showAddExercise = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                Text("Thêm bài tập")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.Colors.softOrange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Colors.softOrange.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        Task { @MainActor in
            await syncManager.saveWorkoutExercises(
                exercises,
                for: sessionId,
                trainerId: session.trainer?.id,
                clientId: client.id
            )
            isSaving = false
            dismiss()
        }
    }
}
