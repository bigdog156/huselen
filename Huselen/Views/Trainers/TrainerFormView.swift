import SwiftUI

struct TrainerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var trainer: Trainer?

    @State private var name = ""
    @State private var phone = ""
    @State private var specialization = ""
    @State private var experienceYears = 0
    @State private var bio = ""
    @State private var isActive = true
    @State private var isSaving = false

    var isEditing: Bool { trainer != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin cơ bản") {
                    TextField("Tên PT *", text: $name)
                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Chuyên môn", text: $specialization)
                    Stepper("Kinh nghiệm: \(experienceYears) năm", value: $experienceYears, in: 0...50)
                }

                Section("Giới thiệu") {
                    TextEditor(text: $bio)
                        .frame(minHeight: 80)
                }

                Section {
                    Toggle("Đang hoạt động", isOn: $isActive)
                }
            }
            .navigationTitle(isEditing ? "Sửa PT" : "Thêm PT mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .overlay {
                            if isSaving { ProgressView().tint(.accentColor) }
                        }
                }
            }
            .onAppear {
                if let trainer {
                    name = trainer.name
                    phone = trainer.phone
                    specialization = trainer.specialization
                    experienceYears = trainer.experienceYears
                    bio = trainer.bio
                    isActive = trainer.isActive
                }
            }
        }
    }

    private func save() {
        isSaving = true
        if let trainer {
            trainer.name = name.trimmingCharacters(in: .whitespaces)
            trainer.phone = phone
            trainer.specialization = specialization
            trainer.experienceYears = experienceYears
            trainer.bio = bio
            trainer.isActive = isActive
            Task {
                await syncManager.updateTrainer(trainer)
                isSaving = false
                dismiss()
            }
        } else {
            let newTrainer = Trainer(
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone,
                specialization: specialization,
                experienceYears: experienceYears,
                bio: bio,
                isActive: isActive
            )
            Task {
                let success = await syncManager.createTrainer(newTrainer)
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}
