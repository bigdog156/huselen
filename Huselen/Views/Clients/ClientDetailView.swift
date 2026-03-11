import SwiftUI

struct ClientDetailView: View {
    var client: Client
    @State private var showingEditForm = false
    @State private var showingPurchaseForm = false
    @State private var editingPurchase: PackagePurchase?

    var body: some View {
        List {
            Section("Thông tin cá nhân") {
                LabeledContent("Tên", value: client.name)
                if !client.phone.isEmpty {
                    LabeledContent("SĐT", value: client.phone)
                }
                if !client.email.isEmpty {
                    LabeledContent("Email", value: client.email)
                }
            }

            Section("Chỉ số cơ thể") {
                if client.weight > 0 {
                    LabeledContent("Cân nặng", value: String(format: "%.1f kg", client.weight))
                }
                if client.bodyFat > 0 {
                    LabeledContent("Tỷ lệ mỡ", value: String(format: "%.1f%%", client.bodyFat))
                }
                if client.muscleMass > 0 {
                    LabeledContent("Khối lượng cơ", value: String(format: "%.1f kg", client.muscleMass))
                }
                if client.weight == 0 && client.bodyFat == 0 && client.muscleMass == 0 {
                    Text("Chưa cập nhật")
                        .foregroundStyle(.secondary)
                }
            }

            if !client.goal.isEmpty {
                Section("Mục tiêu") {
                    Text(client.goal)
                }
            }

            Section {
                HStack {
                    Text("Gói PT đã mua")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingPurchaseForm = true }) {
                        Label("Mua gói", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                }

                let activePurchases = client.purchases.filter { !$0.isExpired && !$0.isFullyUsed }
                if activePurchases.isEmpty {
                    Text("Chưa có gói PT nào")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activePurchases) { purchase in
                        Button {
                            editingPurchase = purchase
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(purchase.package?.name ?? "Gói PT")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(formatVND(purchase.price))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                HStack {
                                    Text("PT: \(purchase.trainer?.name ?? "N/A")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("Còn \(purchase.remainingSessions)/\(purchase.totalSessions) buổi")
                                        .font(.caption)
                                        .foregroundStyle(purchase.remainingSessions > 0 ? .blue : .red)
                                }
                                ProgressView(value: Double(purchase.usedSessions), total: Double(purchase.totalSessions))
                                    .tint(purchase.remainingSessions > 3 ? .green : .orange)
                                Text("HSD: \(purchase.expiryDate, format: .dateTime.day().month().year())")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Lịch sử tập luyện") {
                let completedSessions = client.sessions
                    .filter { $0.isCompleted }
                    .sorted { $0.scheduledDate > $1.scheduledDate }
                    .prefix(10)

                if completedSessions.isEmpty {
                    Text("Chưa có lịch sử tập")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(completedSessions)) { session in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.trainer?.name ?? "N/A")
                                    .font(.subheadline)
                                Text(session.scheduledDate, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle(client.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sửa") { showingEditForm = true }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            ClientFormView(client: client)
        }
        .sheet(isPresented: $showingPurchaseForm) {
            PurchaseFormView(client: client)
        }
        .sheet(item: $editingPurchase) { purchase in
            PurchaseEditView(purchase: purchase)
        }
    }
}
