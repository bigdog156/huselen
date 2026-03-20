import SwiftUI

struct MyPackagesView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var selectedPurchase: PackagePurchase?

    private var purchases: [PackagePurchase] {
        syncManager.purchases.sorted { $0.purchaseDate > $1.purchaseDate }
    }

    private var activePurchases: [PackagePurchase] {
        purchases.filter { !$0.isExpired && !$0.isFullyUsed }
    }

    private var expiredPurchases: [PackagePurchase] {
        purchases.filter { $0.isExpired || $0.isFullyUsed }
    }

    private var totalRemaining: Int {
        activePurchases.reduce(0) { $0 + $1.remainingSessions }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                if purchases.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 20) {
                        if !activePurchases.isEmpty {
                            summaryCard
                                .padding(.horizontal, 24)

                            sectionBlock(title: "Gói đang dùng", purchases: activePurchases, active: true)
                        }

                        if !expiredPurchases.isEmpty {
                            sectionBlock(title: "Đã kết thúc", purchases: expiredPurchases, active: false)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color(.systemBackground))
        .refreshable { await syncManager.refresh() }
        .sheet(item: $selectedPurchase) { purchase in
            PackageDetailSheet(purchase: purchase)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ClientHeaderView(subtitle: "Quản lý gói tập", title: "Gói của tôi", accentColor: Color.fitGreen)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Buổi còn lại")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(totalRemaining)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(activePurchases.count) gói đang hoạt động")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(
            LinearGradient(
                colors: [Color.fitGreen, Color.fitGreenDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
    }

    // MARK: - Section Block

    private func sectionBlock(title: String, purchases: [PackagePurchase], active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.fitTextSecondary)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(purchases) { purchase in
                    packageCard(purchase, active: active)
                        .padding(.horizontal, 24)
                        .onTapGesture { selectedPurchase = purchase }
                }
            }
        }
    }

    // MARK: - Package Card

    private func packageCard(_ purchase: PackagePurchase, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(purchase.package?.name ?? "Gói PT")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.fitTextTertiary)
                        Text("PT: \(purchase.trainer?.name ?? "N/A")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                }
                Spacer()
                statusBadge(purchase, active: active)
            }

            if active {
                VStack(spacing: 6) {
                    HStack {
                        Text("Đã dùng \(purchase.usedSessions)/\(purchase.totalSessions) buổi")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.fitTextSecondary)
                        Spacer()
                        Text("\(purchase.remainingSessions) còn lại")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(progressColor(purchase))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.fitCard)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [progressColor(purchase), progressColor(purchase).opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geo.size.width * CGFloat(purchase.usedSessions) / CGFloat(max(purchase.totalSessions, 1)),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }

                HStack {
                    Label(
                        purchase.expiryDate.formatted(.dateTime.day().month().year()),
                        systemImage: "calendar"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(expiryColor(purchase))

                    Spacer()

                    if !purchase.scheduleDays.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(scheduleText(purchase))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.fitTextTertiary)
                    }
                }
            } else {
                HStack {
                    Label(
                        "Mua: \(purchase.purchaseDate.formatted(.dateTime.day().month().year()))",
                        systemImage: "cart"
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.fitTextTertiary)
                    Spacer()
                    Text("\(purchase.usedSessions)/\(purchase.totalSessions) buổi")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(active ? Color(.systemBackground) : Color.fitCard.opacity(0.7))
                .shadow(color: active ? .black.opacity(0.06) : .clear, radius: 10, y: 4)
        )
        .opacity(active ? 1 : 0.7)
    }

    // MARK: - Badges & Helpers

    private func statusBadge(_ purchase: PackagePurchase, active: Bool) -> some View {
        Group {
            if purchase.isFullyUsed {
                Text("Đã hết buổi")
                    .foregroundStyle(Color.fitGreen)
                    .background(Capsule().fill(Color.fitGreenSoft))
            } else if purchase.isExpired {
                Text("Hết hạn")
                    .foregroundStyle(Color.fitCoral)
                    .background(Capsule().fill(Color.fitCoral.opacity(0.1)))
            } else if purchase.remainingSessions <= 3 {
                Text("Sắp hết")
                    .foregroundStyle(.orange)
                    .background(Capsule().fill(Color.orange.opacity(0.1)))
            } else {
                Text("Đang dùng")
                    .foregroundStyle(Color.fitGreen)
                    .background(Capsule().fill(Color.fitGreenSoft))
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func progressColor(_ purchase: PackagePurchase) -> Color {
        if purchase.remainingSessions <= 3 { return .orange }
        return Color.fitGreen
    }

    private func expiryColor(_ purchase: PackagePurchase) -> Color {
        let soon = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return purchase.expiryDate < soon ? Color.fitCoral : Color.fitTextTertiary
    }

    private func scheduleText(_ purchase: PackagePurchase) -> String {
        let dayNames = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
        let days = purchase.scheduleDays.sorted().compactMap { dayNames[safe: $0 - 1] }.joined(separator: ", ")
        let timeStr = String(format: "%02d:%02d", purchase.scheduleHour, purchase.scheduleMinute)
        return "\(days) • \(timeStr)"
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(Color.fitTextTertiary)
            Text("Chưa mua gói PT")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.fitTextPrimary)
            Text("Liên hệ phòng gym để mua gói tập")
                .font(.system(size: 13))
                .foregroundStyle(Color.fitTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Package Detail Sheet

private struct PackageDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager
    let purchase: PackagePurchase

    private var relatedSessions: [TrainingGymSession] {
        syncManager.sessions
            .filter { $0.purchaseID == purchase.purchaseID }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private var completedSessions: [TrainingGymSession] {
        relatedSessions.filter { $0.isCompleted }
    }

    private var upcomingSessions: [TrainingGymSession] {
        relatedSessions.filter { !$0.isCompleted && !$0.isAbsent && $0.scheduledDate >= Date() }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Colored header
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 12)

                        Text(purchase.package?.name ?? "Gói PT")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("PT: \(purchase.trainer?.name ?? "N/A")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.fitGreen, Color.fitGreenDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    VStack(spacing: 16) {
                        // Stats grid
                        HStack(spacing: 10) {
                            detailStat(value: "\(purchase.totalSessions)", label: "Tổng buổi", color: Color.fitIndigo)
                            detailStat(value: "\(purchase.usedSessions)", label: "Đã dùng", color: Color.fitOrange)
                            detailStat(value: "\(purchase.remainingSessions)", label: "Còn lại", color: Color.fitGreen)
                        }

                        // Dates
                        VStack(spacing: 0) {
                            infoRow(
                                icon: "cart.fill",
                                title: "Ngày mua",
                                value: purchase.purchaseDate.formatted(.dateTime.day().month().year()),
                                iconColor: Color.fitIndigo
                            )
                            Divider().padding(.leading, 48)
                            infoRow(
                                icon: "calendar.badge.clock",
                                title: "Hết hạn",
                                value: purchase.expiryDate.formatted(.dateTime.day().month().year()),
                                iconColor: expiryColor,
                                valueColor: expiryColor
                            )
                            if !purchase.scheduleDays.isEmpty {
                                Divider().padding(.leading, 48)
                                infoRow(
                                    icon: "clock.fill",
                                    title: "Lịch tập",
                                    value: scheduleText,
                                    iconColor: Color.fitGreen
                                )
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                        )

                        // Progress bar
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tiến độ sử dụng")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fitTextSecondary)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.fitCard)
                                        .frame(height: 12)
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(LinearGradient(
                                            colors: [Color.fitGreen, Color.fitGreenDark],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(
                                            width: geo.size.width * CGFloat(purchase.usedSessions) / CGFloat(max(purchase.totalSessions, 1)),
                                            height: 12
                                        )
                                }
                            }
                            .frame(height: 12)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                        )

                        // Upcoming sessions
                        if !upcomingSessions.isEmpty {
                            sessionsList(title: "Buổi sắp tới", sessions: Array(upcomingSessions.prefix(5)), iconColor: Color.fitIndigo)
                        }

                        // Completed sessions
                        if !completedSessions.isEmpty {
                            sessionsList(title: "Buổi đã hoàn thành", sessions: Array(completedSessions.prefix(10)), iconColor: Color.fitGreen)
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var expiryColor: Color {
        let soon = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return purchase.expiryDate < soon ? Color.fitCoral : Color.fitTextSecondary
    }

    private var scheduleText: String {
        let dayNames = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
        let days = purchase.scheduleDays.sorted().compactMap { dayNames[safe: $0 - 1] }.joined(separator: ", ")
        let timeStr = String(format: "%02d:%02d", purchase.scheduleHour, purchase.scheduleMinute)
        return "\(days) • \(timeStr)"
    }

    private func detailStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    private func infoRow(icon: String, title: String, value: String, iconColor: Color, valueColor: Color = Color.fitTextPrimary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.fitTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func sessionsList(title: String, sessions: [TrainingGymSession], iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.fitTextSecondary)

            VStack(spacing: 8) {
                ForEach(sessions) { session in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(iconColor.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(iconColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.scheduledDate.formatted(.dateTime.weekday(.abbreviated).day().month()))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.fitTextPrimary)
                            Text(session.scheduledDate.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.fitTextSecondary)
                        }
                        Spacer()
                        Text("\(session.duration)p")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.fitCard)
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
    }
}
