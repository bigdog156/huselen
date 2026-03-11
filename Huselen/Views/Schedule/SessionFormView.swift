import SwiftUI

struct SessionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var preselectedDate: Date = Date()

    @State private var selectedTrainer: Trainer?
    @State private var selectedClient: Client?
    @State private var scheduledDate = Date()
    @State private var duration = 60
    @State private var selectedPurchase: PackagePurchase?
    @State private var conflictWarning: String?
    @State private var isSaving = false

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
            .navigationTitle("Đặt lịch tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đặt lịch") { save() }
                        .disabled(selectedTrainer == nil || selectedClient == nil || conflictWarning != nil || isSaving)
                        .overlay {
                            if isSaving { ProgressView().tint(.accentColor) }
                        }
                }
            }
            .onAppear {
                scheduledDate = preselectedDate
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
            !session.isCompleted &&
            session.scheduledDate < newEnd &&
            session.endDate > newStart
        }

        conflictWarning = hasConflict ? "PT \(trainer.name) đã có lịch vào thời gian này!" : nil
    }

    private func save() {
        guard let trainer = selectedTrainer, let client = selectedClient else { return }
        let session = TrainingGymSession(
            trainer: trainer,
            client: client,
            scheduledDate: scheduledDate,
            duration: duration,
            purchaseID: selectedPurchase?.purchaseID
        )
        isSaving = true
        Task {
            let success = await syncManager.createSession(session)
            isSaving = false
            if success { dismiss() }
        }
    }
}
