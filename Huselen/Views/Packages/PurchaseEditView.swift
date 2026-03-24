import SwiftUI

struct PurchaseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var purchase: PackagePurchase

    private var trainers: [Trainer] {
        syncManager.trainers.filter { $0.isActive }.sorted { $0.name < $1.name }
    }

    @State private var price: Double
    @State private var totalSessions: Int
    @State private var expiryDate: Date
    @State private var notes: String
    @State private var selectedDays: Set<Int>
    @State private var scheduleTime: Date
    @State private var selectedTrainer: Trainer?
    @State private var remainingSessions: Int
    @State private var isSaving = false

    init(purchase: PackagePurchase) {
        self.purchase = purchase
        _price = State(initialValue: purchase.price)
        _totalSessions = State(initialValue: purchase.totalSessions)
        _expiryDate = State(initialValue: purchase.expiryDate)
        _notes = State(initialValue: purchase.notes)
        _selectedDays = State(initialValue: Set(purchase.scheduleDays))
        _scheduleTime = State(initialValue: Calendar.current.date(from: DateComponents(hour: purchase.scheduleHour, minute: purchase.scheduleMinute)) ?? Date())
        _selectedTrainer = State(initialValue: purchase.trainer)
        _remainingSessions = State(initialValue: purchase.remainingSessions)
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
                Section("Thông tin gói") {
                    LabeledContent("Gói", value: purchase.package?.name ?? "Gói PT")
                    LabeledContent("Khách hàng", value: purchase.client?.name ?? "N/A")
                }

                Section("PT phụ trách") {
                    if trainers.isEmpty {
                        Text("Chưa có PT nào")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trainers) { trainer in
                            Button {
                                selectedTrainer = trainer
                            } label: {
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

                Section("Giá & số buổi") {
                    HStack {
                        Text("Giá (VNĐ)")
                        Spacer()
                        TextField("0", value: $price, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                    }
                    HStack {
                        Text("Tổng số buổi")
                        Spacer()
                        TextField("0", value: $totalSessions, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: totalSessions) { _, newValue in
                                remainingSessions = max(newValue - purchase.usedSessions, 0)
                            }
                    }
                    LabeledContent("Đã dùng", value: "\(purchase.usedSessions) buổi")

                    HStack {
                        Text("Còn lại")
                            .fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                if remainingSessions > 0 {
                                    remainingSessions -= 1
                                    totalSessions = purchase.usedSessions + remainingSessions
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(remainingSessions > 0 ? Color.fitCoral : Color.gray.opacity(0.3))
                            }
                            .disabled(remainingSessions <= 0)

                            Text("\(remainingSessions)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(remainingSessions > 0 ? Color.fitGreen : Color.fitCoral)
                                .frame(minWidth: 40)

                            Button {
                                remainingSessions += 1
                                totalSessions = purchase.usedSessions + remainingSessions
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.fitGreen)
                            }
                        }
                        Text("buổi")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Hạn sử dụng") {
                    DatePicker("Ngày hết hạn", selection: $expiryDate, displayedComponents: .date)
                    LabeledContent("Ngày mua", value: purchase.purchaseDate.formatted(.dateTime.day().month().year()))
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ngày tập trong tuần")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                            ForEach(weekdayEditOptions) { day in
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
                }

                Section("Ghi chú") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle("Sửa gói đã mua")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .disabled(totalSessions < purchase.usedSessions || isSaving)
                        .overlay {
                            if isSaving { ProgressView().tint(.accentColor) }
                        }
                }
            }
        }
    }

    private func save() {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduleTime)

        purchase.price = price
        purchase.totalSessions = totalSessions
        purchase.expiryDate = expiryDate
        purchase.notes = notes
        purchase.scheduleDays = Array(selectedDays).sorted()
        purchase.scheduleHour = timeComponents.hour ?? 18
        purchase.scheduleMinute = timeComponents.minute ?? 0
        purchase.trainer = selectedTrainer

        isSaving = true
        Task {
            await syncManager.updatePurchase(purchase)
            isSaving = false
            dismiss()
        }
    }
}

private let weekdayEditOptions: [WeekdayOption] = [
    .init(id: 2, label: "T2"),
    .init(id: 3, label: "T3"),
    .init(id: 4, label: "T4"),
    .init(id: 5, label: "T5"),
    .init(id: 6, label: "T6"),
    .init(id: 7, label: "T7"),
    .init(id: 1, label: "CN"),
]
