import SwiftUI

struct RevenueView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var selectedMonth = Date()

    private var allPurchases: [PackagePurchase] {
        syncManager.purchases.sorted { $0.purchaseDate < $1.purchaseDate }
    }

    private var trainers: [Trainer] {
        syncManager.trainers.sorted { $0.name < $1.name }
    }

    var purchasesInMonth: [PackagePurchase] {
        let calendar = Calendar.current
        return allPurchases.filter {
            calendar.isDate($0.purchaseDate, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    var monthlyRevenue: Double {
        purchasesInMonth.reduce(0) { $0 + $1.price }
    }

    var totalRevenue: Double {
        allPurchases.reduce(0) { $0 + $1.price }
    }

    var revenueByTrainer: [(trainer: Trainer, revenue: Double, count: Int, mode: Trainer.RevenueMode)] {
        trainers.compactMap { trainer in
            let revenue = trainer.revenueInMonth(selectedMonth)
            let calendar = Calendar.current
            let sessionsInMonth = trainer.sessions.filter {
                $0.isCompleted && calendar.isDate($0.scheduledDate, equalTo: selectedMonth, toGranularity: .month)
            }.count
            let purchasesCount = purchasesInMonth.filter { $0.trainer?.id == trainer.id }.count
            let count = trainer.revenueMode == .perSession ? sessionsInMonth : purchasesCount
            if revenue > 0 || count > 0 {
                return (trainer: trainer, revenue: revenue, count: count, mode: trainer.revenueMode)
            }
            return nil
        }
        .sorted { $0.revenue > $1.revenue }
    }

    var packageStats: [(name: String, count: Int, revenue: Double)] {
        var stats: [String: (count: Int, revenue: Double)] = [:]
        for purchase in purchasesInMonth {
            let name = purchase.package?.name ?? "Khác"
            let existing = stats[name] ?? (count: 0, revenue: 0)
            stats[name] = (count: existing.count + 1, revenue: existing.revenue + purchase.price)
        }
        return stats.map { (name: $0.key, count: $0.value.count, revenue: $0.value.revenue) }
            .sorted { $0.revenue > $1.revenue }
    }

    var body: some View {
        NavigationStack {
            List {
                // Month selector
                Section {
                    HStack {
                        Button(action: { changeMonth(-1) }) {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(selectedMonth, format: .dateTime.month(.wide).year())
                            .font(.headline)
                        Spacer()
                        Button(action: { changeMonth(1) }) {
                            Image(systemName: "chevron.right")
                        }
                    }
                }

                // Summary cards
                Section("Tổng quan") {
                    HStack(spacing: 16) {
                        StatCard(title: "Doanh thu tháng", value: formatVND(monthlyRevenue), color: .green)
                        StatCard(title: "Gói đã bán", value: "\(purchasesInMonth.count)", color: .blue)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    LabeledContent("Tổng doanh thu") {
                        Text(formatVND(totalRevenue))
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    LabeledContent("Tổng gói đã bán") {
                        Text("\(allPurchases.count)")
                    }
                }

                // Revenue by trainer
                Section("Doanh thu theo PT") {
                    if revenueByTrainer.isEmpty {
                        Text("Không có dữ liệu")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(revenueByTrainer, id: \.trainer.id) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.trainer.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(item.mode == .perSession ? "\(item.count) buổi đã dạy" : "\(item.count) gói bán được")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatVND(item.revenue))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // Package stats
                Section("Thống kê gói PT") {
                    if packageStats.isEmpty {
                        Text("Không có dữ liệu")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(packageStats, id: \.name) { stat in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stat.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(stat.count) gói")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(formatVND(stat.revenue))
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Doanh thu")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

    private func changeMonth(_ offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(Theme.Fonts.headline())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}
