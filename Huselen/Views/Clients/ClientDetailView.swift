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
                        NavigationLink(destination: PackageSessionHistoryView(purchase: purchase)) {
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
                        .contextMenu {
                            Button {
                                editingPurchase = purchase
                            } label: {
                                Label("Chỉnh sửa gói", systemImage: "pencil")
                            }
                        }
                    }
                }
            }

            // Expired/used packages
            let expiredPurchases = client.purchases.filter { $0.isExpired || $0.isFullyUsed }
            if !expiredPurchases.isEmpty {
                Section("Gói đã kết thúc") {
                    ForEach(expiredPurchases) { purchase in
                        NavigationLink(destination: PackageSessionHistoryView(purchase: purchase)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(purchase.package?.name ?? "Gói PT")
                                        .font(.subheadline)
                                    Text("Mua: \(purchase.purchaseDate, format: .dateTime.day().month().year())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if purchase.isFullyUsed {
                                    Text("Đã hết buổi")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Hết hạn")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .opacity(0.6)
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
