import SwiftUI

struct MyPackagesView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var purchases: [PackagePurchase] {
        syncManager.purchases.sorted { $0.purchaseDate < $1.purchaseDate }
    }

    var activePurchases: [PackagePurchase] {
        purchases.filter { !$0.isExpired && !$0.isFullyUsed }
    }

    var expiredPurchases: [PackagePurchase] {
        purchases.filter { $0.isExpired || $0.isFullyUsed }
    }

    var totalRemaining: Int {
        activePurchases.reduce(0) { $0 + $1.remainingSessions }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary
                if !activePurchases.isEmpty {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tổng buổi còn lại")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(totalRemaining)")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue.opacity(0.3))
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Active packages
                Section("Gói đang sử dụng") {
                    if activePurchases.isEmpty {
                        Text("Chưa có gói PT nào")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activePurchases) { purchase in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(purchase.package?.name ?? "Gói PT")
                                        .font(.headline)
                                    Spacer()
                                    Text("PT: \(purchase.trainer?.name ?? "N/A")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(value: Double(purchase.usedSessions), total: Double(purchase.totalSessions))
                                    .tint(purchase.remainingSessions > 3 ? .green : .orange)

                                HStack {
                                    Text("Đã dùng \(purchase.usedSessions)/\(purchase.totalSessions) buổi")
                                        .font(.caption)
                                    Spacer()
                                    Text("HSD: \(purchase.expiryDate, format: .dateTime.day().month().year())")
                                        .font(.caption)
                                        .foregroundStyle(purchase.expiryDate < Calendar.current.date(byAdding: .day, value: 7, to: Date())! ? .red : .secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Expired/used packages
                if !expiredPurchases.isEmpty {
                    Section("Gói đã kết thúc") {
                        ForEach(expiredPurchases) { purchase in
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
            .navigationTitle("Gói của tôi")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
            .overlay {
                if purchases.isEmpty {
                    ContentUnavailableView("Chưa mua gói PT", systemImage: "creditcard", description: Text("Liên hệ phòng gym để mua gói tập"))
                }
            }
        }
    }
}
