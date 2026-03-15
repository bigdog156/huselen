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
    @State private var revenueMode: Trainer.RevenueMode = .perPackage
    @State private var sessionRateType: Trainer.SessionRateType = .fixed
    @State private var sessionRate: Double = 0
    @State private var sessionRatePercent: Double = 0
    @State private var selectedBranchId: UUID?
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

                if !syncManager.branches.isEmpty {
                    Section("Cơ sở") {
                        Picker("Cơ sở phòng tập", selection: $selectedBranchId) {
                            Text("Chưa chọn").tag(nil as UUID?)
                            ForEach(syncManager.branches.filter(\.isActive)) { branch in
                                Text(branch.name).tag(branch.id as UUID?)
                            }
                        }
                    }
                }

                Section {
                    Toggle("Đang hoạt động", isOn: $isActive)
                }

                Section {
                    Picker("Tính doanh thu", selection: $revenueMode) {
                        ForEach(Trainer.RevenueMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }

                    if revenueMode == .perSession {
                        Picker("Cách tính buổi", selection: $sessionRateType) {
                            ForEach(Trainer.SessionRateType.allCases, id: \.self) { type in
                                Text(type.label).tag(type)
                            }
                        }

                        if sessionRateType == .fixed {
                            HStack {
                                Text("Tiền / buổi (VNĐ)")
                                Spacer()
                                TextField("0", value: $sessionRate, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 150)
                            }
                        } else {
                            HStack {
                                Text("Phần trăm (%)")
                                Spacer()
                                TextField("0", value: $sessionRatePercent, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 150)
                            }
                        }
                    }
                } header: {
                    Text("Cách tính doanh thu")
                } footer: {
                    if revenueMode == .perPackage {
                        Text("Doanh thu PT = tổng giá trị các gói đã bán.")
                    } else if sessionRateType == .fixed {
                        Text("Doanh thu PT = số buổi đã dạy × tiền cố định mỗi buổi.")
                    } else {
                        Text("Doanh thu PT = số buổi × (giá gói ÷ số buổi trong gói × \(Int(sessionRatePercent))%).")
                    }
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
                    revenueMode = trainer.revenueMode
                    sessionRateType = trainer.sessionRateType
                    sessionRate = trainer.sessionRate
                    sessionRatePercent = trainer.sessionRatePercent
                    selectedBranchId = trainer.branchId
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
            trainer.revenueMode = revenueMode
            trainer.sessionRateType = sessionRateType
            trainer.sessionRate = sessionRate
            trainer.sessionRatePercent = sessionRatePercent
            trainer.branchId = selectedBranchId
            trainer.branch = selectedBranchId.flatMap { bid in syncManager.branches.first { $0.id == bid } }
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
                isActive: isActive,
                revenueMode: revenueMode,
                sessionRateType: sessionRateType,
                sessionRate: sessionRate,
                sessionRatePercent: sessionRatePercent
            )
            newTrainer.branchId = selectedBranchId
            newTrainer.branch = selectedBranchId.flatMap { bid in syncManager.branches.first { $0.id == bid } }
            Task {
                let success = await syncManager.createTrainer(newTrainer)
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}
