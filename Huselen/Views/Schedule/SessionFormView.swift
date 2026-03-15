import SwiftUI

struct SessionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var preselectedDate: Date = Date()
    var editingSession: TrainingGymSession?

    @State private var selectedTrainer: Trainer?
    @State private var selectedClient: Client?
    @State private var scheduledDate = Date()
    @State private var duration = 60
    @State private var selectedPurchase: PackagePurchase?
    @State private var conflictWarning: String?
    @State private var isSaving = false

    private var isEditing: Bool { editingSession != nil }

    let durationOptions = [30, 45, 60, 75, 90, 120]

    private var trainers: [Trainer] {
        syncManager.trainers.filter { $0.isActive }.sorted { $0.name < $1.name }
    }

    private var clients: [Client] {
        syncManager.clients.sorted { $0.name < $1.name }
    }

    var availablePurchases: [PackagePurchase] {
        guard let client = selectedClient, let trainer = selectedTrainer else { return [] }
        return client.purchases.filter {
            $0.trainer?.id == trainer.id &&
            !$0.isExpired &&
            !$0.isFullyUsed
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chọn PT") {
                    if trainers.isEmpty {
                        Text("Chưa có PT nào")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trainers) { trainer in
                            Button(action: {
                                selectedTrainer = trainer
                                selectedPurchase = nil
                                checkConflicts()
                            }) {
                                HStack {
                                    Text(trainer.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTrainer?.id == trainer.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Chọn khách hàng") {
                    if clients.isEmpty {
                        Text("Chưa có khách hàng nào")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(clients) { client in
                            Button(action: {
                                selectedClient = client
                                selectedPurchase = nil
                                checkConflicts()
                            }) {
                                HStack {
                                    Text(client.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedClient?.id == client.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                if !availablePurchases.isEmpty {
                    Section("Trừ từ gói PT") {
                        ForEach(availablePurchases) { purchase in
                            Button(action: { selectedPurchase = purchase }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(purchase.package?.name ?? "Gói PT")
                                            .foregroundStyle(.primary)
                                        Text("Còn \(purchase.remainingSessions) buổi")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedPurchase?.id == purchase.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Thời gian") {
                    DatePicker("Ngày giờ", selection: $scheduledDate)
                        .onChange(of: scheduledDate) { _, _ in checkConflicts() }
                    Picker("Thời lượng", selection: $duration) {
                        ForEach(durationOptions, id: \.self) { mins in
                            Text("\(mins) phút").tag(mins)
                        }
                    }
                    .onChange(of: duration) { _, _ in checkConflicts() }
                }

                if let conflictWarning {
                    Section {
                        Label(conflictWarning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle(isEditing ? "Chỉnh sửa lịch tập" : "Đặt lịch tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Lưu" : "Đặt lịch") { save() }
                        .disabled(selectedTrainer == nil || selectedClient == nil || conflictWarning != nil || isSaving)
                        .overlay {
                            if isSaving { ProgressView().tint(.accentColor) }
                        }
                }
            }
            .onAppear {
                if let session = editingSession {
                    selectedTrainer = session.trainer
                    selectedClient = session.client
                    scheduledDate = session.scheduledDate
                    duration = session.duration
                    if let purchaseID = session.purchaseID, let client = session.client {
                        selectedPurchase = client.purchases.first { $0.purchaseID == purchaseID }
                    }
                } else {
                    scheduledDate = preselectedDate
                }
            }
        }
    }

    private func checkConflicts() {
        guard let trainer = selectedTrainer else {
            conflictWarning = nil
            return
        }

        let newStart = scheduledDate
        let newEnd = Calendar.current.date(byAdding: .minute, value: duration, to: newStart) ?? newStart

        let hasConflict = trainer.sessions.contains { session in
            // Khi đang chỉnh sửa, bỏ qua chính session đó
            if let editing = editingSession, session.id == editing.id { return false }
            return !session.isCompleted &&
                session.scheduledDate < newEnd &&
                session.endDate > newStart
        }

        conflictWarning = hasConflict ? "PT \(trainer.name) đã có lịch vào thời gian này!" : nil
    }

    private func save() {
        guard let trainer = selectedTrainer, let client = selectedClient else { return }
        isSaving = true

        if let session = editingSession {
            // Cập nhật session hiện có
            let oldTrainer = session.trainer
            let oldClient = session.client

            session.trainer = trainer
            session.client = client
            session.scheduledDate = scheduledDate
            session.duration = duration
            session.purchaseID = selectedPurchase?.purchaseID

            // Cập nhật relationship arrays nếu trainer/client thay đổi
            if oldTrainer?.id != trainer.id {
                oldTrainer?.sessions.removeAll { $0.id == session.id }
                if !trainer.sessions.contains(where: { $0.id == session.id }) {
                    trainer.sessions.append(session)
                }
            }
            if oldClient?.id != client.id {
                oldClient?.sessions.removeAll { $0.id == session.id }
                if !client.sessions.contains(where: { $0.id == session.id }) {
                    client.sessions.append(session)
                }
            }

            Task {
                await syncManager.updateSession(session)
                isSaving = false
                dismiss()
            }
        } else {
            // Tạo session mới
            let session = TrainingGymSession(
                trainer: trainer,
                client: client,
                scheduledDate: scheduledDate,
                duration: duration,
                purchaseID: selectedPurchase?.purchaseID
            )
            Task {
                let success = await syncManager.createSession(session)
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}
