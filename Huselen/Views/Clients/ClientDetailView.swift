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
                if client.height > 0 { LabeledContent("Chiều cao", value: String(format: "%.1f cm", client.height)) }
                if client.weight > 0 { LabeledContent("Cân nặng", value: String(format: "%.1f kg", client.weight)) }
                if client.bodyFat > 0 { LabeledContent("Tỷ lệ mỡ", value: String(format: "%.1f%%", client.bodyFat)) }
                if client.muscleMass > 0 { LabeledContent("Khối lượng cơ", value: String(format: "%.1f kg", client.muscleMass)) }
                if client.height == 0 && client.weight == 0 && client.bodyFat == 0 && client.muscleMass == 0 {
                    Text("Chưa cập nhật")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Số đo cơ thể") {
                if client.neck > 0 { LabeledContent("Cổ", value: String(format: "%.1f cm", client.neck)) }
                if client.shoulder > 0 { LabeledContent("Vai", value: String(format: "%.1f cm", client.shoulder)) }
                if client.arm > 0 { LabeledContent("Cánh tay", value: String(format: "%.1f cm", client.arm)) }
                if client.chest > 0 { LabeledContent("Vòng 1", value: String(format: "%.1f cm", client.chest)) }
                if client.waist > 0 { LabeledContent("Eo", value: String(format: "%.1f cm", client.waist)) }
                if client.hip > 0 { LabeledContent("Hông", value: String(format: "%.1f cm", client.hip)) }
                if client.thigh > 0 { LabeledContent("Đùi", value: String(format: "%.1f cm", client.thigh)) }
                if client.calf > 0 { LabeledContent("Bắp chân", value: String(format: "%.1f cm", client.calf)) }
                if client.lowerHip > 0 { LabeledContent("Vòng 3", value: String(format: "%.1f cm", client.lowerHip)) }
                let hasNoMeasurements = client.neck == 0 && client.shoulder == 0 && client.arm == 0 && client.chest == 0 && client.waist == 0 && client.hip == 0 && client.thigh == 0 && client.calf == 0 && client.lowerHip == 0
                if hasNoMeasurements {
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
