import SwiftUI

// MARK: - Add / Edit Exercise Sheet

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss

    var initial: ExerciseEntry?
    var onSave: (ExerciseEntry) -> Void

    @State private var exerciseName = ""
    @State private var sets = 3
    @State private var reps = 10
    @State private var weightText = ""
    @State private var isBodyweight = true
    @State private var notes = ""

    // Search
    @State private var searchText = ""

    private var filteredExercises: [CommonExercise] {
        if searchText.isEmpty { return CommonExercise.all }
        return CommonExercise.all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var isEditing: Bool { initial != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Exercise name
                Section("Tên bài tập") {
                    TextField("Nhập hoặc chọn bên dưới", text: $exerciseName)
                        .autocorrectionDisabled()

                    if !filteredExercises.isEmpty && !exerciseName.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filteredExercises.prefix(8)) { ex in
                                    Button {
                                        exerciseName = ex.name
                                    } label: {
                                        Label(ex.name, systemImage: ex.icon)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(
                                                exerciseName == ex.name
                                                    ? Theme.Colors.softOrange.opacity(0.2)
                                                    : Color(.tertiarySystemFill),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(
                                                exerciseName == ex.name
                                                    ? Theme.Colors.softOrange
                                                    : Color.fitTextSecondary
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Quick pick grid
                Section("Chọn nhanh") {
                    TextField("Tìm bài tập...", text: $searchText)
                        .autocorrectionDisabled()

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 8
                    ) {
                        ForEach(filteredExercises) { ex in
                            Button {
                                exerciseName = ex.name
                                searchText = ""
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: ex.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.softOrange)
                                        .frame(width: 24)
                                    Text(ex.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color.fitTextPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            exerciseName == ex.name
                                                ? Theme.Colors.softOrange.opacity(0.15)
                                                : Color(.secondarySystemGroupedBackground)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Sets & Reps
                Section("Số hiệp & Số lần") {
                    Stepper("Số hiệp: \(sets)", value: $sets, in: 1...20)
                    Stepper("Số lần: \(reps)", value: $reps, in: 1...200)
                }

                // Weight
                Section {
                    Toggle("Tự trọng (không tạ)", isOn: $isBodyweight)
                        .onChange(of: isBodyweight) { _, new in
                            if new { weightText = "" }
                        }

                    if !isBodyweight {
                        HStack {
                            Text("Trọng lượng")
                            Spacer()
                            TextField("kg", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                } header: {
                    Text("Trọng lượng")
                }

                // Notes
                Section("Ghi chú (tuỳ chọn)") {
                    TextField("Kỹ thuật, lưu ý...", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }
            }
            .navigationTitle(isEditing ? "Sửa bài tập" : "Thêm bài tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .fontWeight(.semibold)
                        .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { populate() }
        }
    }

    private func populate() {
        guard let e = initial else { return }
        exerciseName = e.exerciseName
        sets = e.sets
        reps = e.reps
        if let w = e.weightKg, w > 0 {
            isBodyweight = false
            weightText = w.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", w)
                : String(format: "%.1f", w)
        } else {
            isBodyweight = true
        }
        notes = e.notes
    }

    private func save() {
        var entry = ExerciseEntry(
            exerciseName: exerciseName.trimmingCharacters(in: .whitespaces),
            sets: sets,
            reps: reps,
            weightKg: isBodyweight ? nil : Double(weightText),
            notes: notes,
            orderIndex: initial?.orderIndex ?? 0
        )
        if let existing = initial {
            entry.id = existing.id
        }
        onSave(entry)
        dismiss()
    }
}
