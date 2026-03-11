import SwiftUI

struct WeekdayOption: Identifiable {
    let id: Int       // 1=CN, 2=T2...7=T7
    let label: String
}

private let weekdayOptions: [WeekdayOption] = [
    .init(id: 2, label: "T2"),
    .init(id: 3, label: "T3"),
    .init(id: 4, label: "T4"),
    .init(id: 5, label: "T5"),
    .init(id: 6, label: "T6"),
    .init(id: 7, label: "T7"),
    .init(id: 1, label: "CN"),
]

struct PurchaseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager
    @State private var packageManager = PackageManager()

    var client: Client

    private var trainers: [Trainer] {
        syncManager.trainers.filter { $0.isActive }.sorted { $0.name < $1.name }
    }

    @State private var selectedPackage: GymPTPackage?
    @State private var selectedTrainer: Trainer?
    @State private var customPrice: Double?
    @State private var selectedDays: Set<Int> = []
    @State private var scheduleTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()
    @State private var bufferWeeks: Int = 0
    @State private var isSaving = false

    private let bufferOptions = [
        (value: 0, label: "Không"),
        (value: 1, label: "1 tuần"),
        (value: 2, label: "2 tuần"),
        (value: 3, label: "3 tuần"),
        (value: 4, label: "4 tuần"),
    ]

    private var activePackages: [GymPTPackage] {
        packageManager.packages.filter { $0.isActive }
    }

    private func formattedPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Khách hàng") {
                    LabeledContent("Tên", value: client.name)
                }

                Section("Chọn gói PT") {
                    if packageManager.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if activePackages.isEmpty {
                        Text("Chưa có gói PT nào. Hãy tạo gói trước.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activePackages) { pkg in
                            Button(action: { selectedPackage = pkg }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(pkg.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text("\(pkg.totalSessions) buổi - \(formattedPrice(pkg.price))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedPackage?.id == pkg.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Chọn PT phụ trách") {
                    if trainers.isEmpty {
                        Text("Chưa có PT nào. Hãy thêm PT trước.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trainers) { trainer in
                            Button(action: { selectedTrainer = trainer }) {
                                HStack {
                                    Text(trainer.name)
                                        .foregroundStyle(.primary)
                                    if !trainer.specialization.isEmpty {
                                        Text("(\(trainer.specialization))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ngày tập trong tuần")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(weekdayOptions) { day in
                                let isSelected = selectedDays.contains(day.id)
                                Button {
                                    if isSelected {
                                        selectedDays.remove(day.id)
                                    } else {
                                        selectedDays.insert(day.id)
                                    }
                                } label: {
                                    Text(day.label)
                                        .font(Theme.Fonts.caption())
                                        .fontWeight(isSelected ? .bold : .regular)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                                .fill(isSelected ? Theme.Colors.warmYellow : Color(.systemGray6))
                                        )
                                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    DatePicker("Giờ tập", selection: $scheduleTime, displayedComponents: .hourAndMinute)
                        .font(Theme.Fonts.body())
                } header: {
                    Text("Lịch tập")
                } footer: {
                    if !selectedDays.isEmpty {
                        let dayLabels = weekdayOptions.filter { selectedDays.contains($0.id) }.map(\.label)
                        let timeStr = scheduleTime.formatted(date: .omitted, time: .shortened)
                        Text("Tập \(dayLabels.joined(separator: ", ")) lúc \(timeStr)")
                    }
                }

                if let selectedPackage {
                    Section("Giá") {
                        HStack {
                            Text("Giá gốc")
                            Spacer()
                            Text(formattedPrice(selectedPackage.price))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Giá bán (VNĐ)")
                            Spacer()
                            TextField("Giá gốc", value: $customPrice, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Thời gian bù tập")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)

                            HStack(spacing: 8) {
                                ForEach(bufferOptions, id: \.value) { option in
                                    let isSelected = bufferWeeks == option.value
                                    Button {
                                        bufferWeeks = option.value
                                    } label: {
                                        Text(option.label)
                                            .font(Theme.Fonts.caption())
                                            .fontWeight(isSelected ? .bold : .regular)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                                    .fill(isSelected ? Theme.Colors.warmYellow : Color(.systemGray6))
                                            )
                                            .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Bù tập")
                    } footer: {
                        if bufferWeeks > 0 {
                            Text("Hạn sử dụng gói sẽ được cộng thêm \(bufferWeeks) tuần để bù tập.")
                        }
                    }
                }
            }
            .navigationTitle("Mua gói PT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xác nhận") { purchase() }
                        .disabled(selectedPackage == nil || selectedTrainer == nil || selectedDays.isEmpty || isSaving)
                        .overlay {
                            if isSaving { ProgressView().tint(.accentColor) }
                        }
                }
            }
            .task {
                await packageManager.fetchPackages()
            }
        }
    }

    private func purchase() {
        guard let selectedPackage, let selectedTrainer else { return }

        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduleTime)
        let hour = timeComponents.hour ?? 18
        let minute = timeComponents.minute ?? 0

        let localPackage = PTPackage(
            name: selectedPackage.name,
            totalSessions: selectedPackage.totalSessions,
            price: selectedPackage.price,
            durationDays: selectedPackage.durationDays,
            packageDescription: selectedPackage.description,
            isActive: selectedPackage.isActive
        )
        if let pkgId = selectedPackage.id {
            localPackage.id = pkgId
        }

        let newPurchase = PackagePurchase(
            package: localPackage,
            client: client,
            trainer: selectedTrainer,
            price: customPrice,
            scheduleDays: Array(selectedDays).sorted(),
            scheduleHour: hour,
            scheduleMinute: minute
        )

        // Add buffer weeks to expiry date
        if bufferWeeks > 0 {
            newPurchase.expiryDate = calendar.date(byAdding: .weekOfYear, value: bufferWeeks, to: newPurchase.expiryDate) ?? newPurchase.expiryDate
        }

        // Auto-generate training sessions
        let sessions = generateSessions(
            purchase: newPurchase,
            trainer: selectedTrainer,
            client: client,
            totalSessions: selectedPackage.totalSessions,
            days: selectedDays,
            hour: hour,
            minute: minute,
            from: Date(),
            maxDate: newPurchase.expiryDate
        )

        // Save to Supabase
        isSaving = true
        Task {
            let purchaseOk = await syncManager.createPurchase(newPurchase)
            if purchaseOk {
                await syncManager.createSessions(sessions)
                isSaving = false
                dismiss()
            } else {
                isSaving = false
            }
        }
    }

    private func generateSessions(
        purchase: PackagePurchase,
        trainer: Trainer,
        client: Client,
        totalSessions: Int,
        days: Set<Int>,
        hour: Int,
        minute: Int,
        from startDate: Date,
        maxDate: Date
    ) -> [TrainingGymSession] {
        guard !days.isEmpty else { return [] }

        var sessions: [TrainingGymSession] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)

        while sessions.count < totalSessions && currentDate <= maxDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            if days.contains(weekday) {
                var components = calendar.dateComponents([.year, .month, .day], from: currentDate)
                components.hour = hour
                components.minute = minute
                if let sessionDate = calendar.date(from: components) {
                    let session = TrainingGymSession(
                        trainer: trainer,
                        client: client,
                        scheduledDate: sessionDate,
                        duration: 60,
                        purchaseID: purchase.purchaseID
                    )
                    sessions.append(session)
                }
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return sessions
    }
}
