import SwiftUI
import Charts

struct RevenueView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var selectedMonth = Date()

    // MARK: - Computed Properties

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

    private var last6MonthsRevenue: [(label: String, revenue: Double)] {
        let cal = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "MM/yy"
        return (0..<6).reversed().map { offset in
            let date = cal.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
            let rev = allPurchases.filter {
                cal.isDate($0.purchaseDate, equalTo: date, toGranularity: .month)
            }.reduce(0) { $0 + $1.price }
            return (label: df.string(from: date), revenue: rev)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthPickerSection
                    summaryCardsRow
                    revenueChartSection
                    revenueByTrainerSection
                    packageStatsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.Colors.screenBackground.ignoresSafeArea())
            .navigationTitle("Doanh thu")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

    private func changeMonth(_ offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedMonth = newDate
            }
        }
    }
}

// MARK: - Subviews

private extension RevenueView {

    // MARK: Month Picker

    var monthPickerSection: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.fitCard)
                    .clipShape(Circle())
            }

            Spacer()

            Text(selectedMonth, format: .dateTime.month(.wide).year())
                .font(Theme.Fonts.headline())
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.fitCard)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Summary Cards

    var summaryCardsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Doanh thu tháng",
                value: formatVND(monthlyRevenue),
                color: Theme.Colors.warmYellow
            )
            StatCard(
                title: "Gói đã bán",
                value: "\(purchasesInMonth.count)",
                color: .fitIndigo
            )
        }
    }

    // MARK: Revenue Chart

    var revenueChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biểu đồ doanh thu")
                .font(Theme.Fonts.headline())
                .foregroundStyle(Theme.Colors.textPrimary)

            Chart(last6MonthsRevenue, id: \.label) { item in
                BarMark(
                    x: .value("Tháng", item.label),
                    y: .value("Doanh thu", item.revenue)
                )
                .foregroundStyle(Theme.Colors.warmYellow.gradient)
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.fitTextTertiary.opacity(0.4))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(abbreviateVND(amount))
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Color.fitTextTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Color.fitTextSecondary)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Revenue by Trainer

    var revenueByTrainerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Doanh thu theo PT")
                .font(Theme.Fonts.headline())
                .foregroundStyle(Theme.Colors.textPrimary)

            if revenueByTrainer.isEmpty {
                emptyState(text: "Không có dữ liệu")
            } else {
                let maxRevenue = revenueByTrainer.first?.revenue ?? 1
                ForEach(revenueByTrainer, id: \.trainer.id) { item in
                    trainerRevenueCard(item: item, maxRevenue: maxRevenue)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    func trainerRevenueCard(
        item: (trainer: Trainer, revenue: Double, count: Int, mode: Trainer.RevenueMode),
        maxRevenue: Double
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.trainer.name)
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(item.mode == .perSession ? "\(item.count) buổi đã dạy" : "\(item.count) gói bán được")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextTertiary)
                }
                Spacer()
                Text(formatVND(item.revenue))
                    .font(Theme.Fonts.subheadline())
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.warmYellow)
            }

            // Progress bar showing relative share
            GeometryReader { geo in
                let fraction = maxRevenue > 0 ? item.revenue / maxRevenue : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.Colors.warmYellow.opacity(0.12))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.Colors.warmYellow)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: Package Stats

    var packageStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thống kê gói PT")
                .font(Theme.Fonts.headline())
                .foregroundStyle(Theme.Colors.textPrimary)

            if packageStats.isEmpty {
                emptyState(text: "Không có dữ liệu")
            } else {
                ForEach(packageStats, id: \.name) { stat in
                    packageStatCard(stat: stat)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    func packageStatCard(stat: (name: String, count: Int, revenue: Double)) -> some View {
        HStack {
            CuteIconCircle(icon: "shippingbox.fill", color: Theme.Colors.softOrange, size: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(stat.name)
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(stat.count) gói")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Color.fitTextTertiary)
            }

            Spacer()

            Text(formatVND(stat.revenue))
                .font(Theme.Fonts.subheadline())
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.mintGreen)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: Empty State

    func emptyState(text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.body())
            .foregroundStyle(Color.fitTextTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }
}

// MARK: - Helpers

private func abbreviateVND(_ amount: Double) -> String {
    if amount >= 1_000_000 {
        let millions = amount / 1_000_000
        return String(format: "%.1ftr", millions)
    } else if amount >= 1_000 {
        let thousands = amount / 1_000
        return String(format: "%.0fk", thousands)
    }
    return "\(Int(amount))"
}

// MARK: - StatCard

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
