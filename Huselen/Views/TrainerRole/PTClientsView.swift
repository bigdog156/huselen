import SwiftUI

// MARK: - PTClientsView

struct PTClientsView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if syncManager.clients.isEmpty {
                    emptyState
                } else {
                    summaryBanner
                    filterChips
                    clientList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Học viên")
            .searchable(text: $searchText, prompt: "Tìm học viên...")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}

// MARK: - Subviews

private extension PTClientsView {

    // MARK: Filter Option

    enum FilterOption {
        case all, active, expired
    }

    // MARK: Displayed Clients

    var displayedClients: [Client] {
        let base = syncManager.clients.sorted { $0.name < $1.name }
        let searched = searchText.isEmpty ? base : base.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        switch selectedFilter {
        case .all: return searched
        case .active: return searched.filter { $0.remainingSessions > 0 }
        case .expired: return searched.filter { $0.remainingSessions == 0 }
        }
    }

    // MARK: Summary Banner

    var summaryBanner: some View {
        let allClients = syncManager.clients
        let upcomingCount = allClients.filter { client in
            client.sessions.contains { !$0.isCompleted && !$0.isAbsent && $0.scheduledDate > Date() }
        }.count
        let renewCount = allClients.filter { $0.remainingSessions <= 3 }.count

        return HStack(spacing: 0) {
            bannerCell(
                icon: "person.2.fill",
                value: "\(allClients.count)",
                label: "học viên"
            )
            bannerCell(
                icon: "calendar.badge.checkmark",
                value: "\(upcomingCount)",
                label: "có buổi sắp tới"
            )
            bannerCell(
                icon: "clock.arrow.circlepath",
                value: "\(renewCount)",
                label: "cần gia hạn"
            )
        }
        .padding(.vertical, 14)
        .background(Theme.Colors.softOrange.opacity(0.08))
    }

    func bannerCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.softOrange)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fitTextPrimary)
            Text(label)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Color.fitTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Filter Chips

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chipButton("Tất cả", option: .all)
                chipButton("Còn buổi", option: .active)
                chipButton("Hết buổi", option: .expired)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    func chipButton(_ title: String, option: FilterOption) -> some View {
        let isSelected = selectedFilter == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = option
            }
        } label: {
            Text(title)
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(isSelected ? .white : Color.fitTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.Colors.softOrange : Color.fitCard)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Client List

    var clientList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(displayedClients) { client in
                    NavigationLink(destination: PTClientDetailView(client: client)) {
                        clientCard(client)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: Client Card

    func clientCard(_ client: Client) -> some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accentColor(for: client))
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                // Row 1 — Header
                HStack(spacing: 12) {
                    // Avatar initials circle
                    Text(initialsFrom(client.name))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(
                                    client.remainingSessions > 0
                                        ? LinearGradient(
                                            colors: [Theme.Colors.softOrange, Theme.Colors.warmYellow],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.fitTextTertiary, Color.fitTextTertiary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(client.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fitTextPrimary)

                        if !client.goal.isEmpty {
                            Text(client.goal)
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Color.fitTextSecondary)
                                .lineLimit(1)
                        }

                        // Upcoming session
                        if let next = upcomingSession(for: client) {
                            Label(
                                next.scheduledDate.formatted(
                                    .dateTime.weekday(.abbreviated).day().month()
                                ),
                                systemImage: "calendar"
                            )
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.fitIndigo)
                        } else {
                            Label("Không có lịch sắp tới", systemImage: "calendar.badge.minus")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.fitTextTertiary)
                        }
                    }

                    Spacer()

                    // Remaining sessions badge
                    remainingBadge(for: client)
                }

                // Row 2 — Active package progress (first active package only)
                if let purchase = client.purchases.first(where: { !$0.isExpired && !$0.isFullyUsed }) {
                    packageProgressRow(purchase, client: client)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        )
    }

    // MARK: Remaining Sessions Badge

    func remainingBadge(for client: Client) -> some View {
        let count = client.remainingSessions
        let badgeColor: Color = {
            if count > 3 { return Color.fitGreen }
            if count >= 1 { return Color.fitOrange }
            return Color.fitCoral
        }()
        let text = count > 0 ? "\(count) buổi" : "Hết buổi"

        return Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(badgeColor))
    }

    // MARK: Package Progress Row

    func packageProgressRow(_ purchase: PackagePurchase, client: Client) -> some View {
        let progressTint = purchase.remainingSessions > 3 ? Color.fitGreen : Color.fitCoral

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.softOrange)

                Text(purchase.package?.name ?? "Gói PT")
                    .font(Theme.Fonts.caption())
                    .fontWeight(.medium)
                    .foregroundStyle(Color.fitTextPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(purchase.usedSessions)/\(purchase.totalSessions) buổi")
                    .font(Theme.Fonts.caption())
                    .fontWeight(.semibold)
                    .foregroundStyle(progressTint)
            }

            ProgressView(
                value: Double(purchase.usedSessions),
                total: Double(max(purchase.totalSessions, 1))
            )
            .tint(progressTint)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.fitTextTertiary)
            Text("Chưa có học viên")
                .font(Theme.Fonts.title3())
                .foregroundStyle(Color.fitTextPrimary)
            Text("Học viên sẽ xuất hiện khi được admin phân bổ gói PT")
                .font(Theme.Fonts.caption())
                .foregroundStyle(Color.fitTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    func upcomingSession(for client: Client) -> TrainingGymSession? {
        client.sessions
            .filter { !$0.isCompleted && !$0.isAbsent && $0.scheduledDate > Date() }
            .min(by: { $0.scheduledDate < $1.scheduledDate })
    }

    func accentColor(for client: Client) -> Color {
        if client.remainingSessions > 3 { return Color.fitGreen }
        if client.remainingSessions >= 1 { return Color.fitOrange }
        return Color.fitCoral
    }

    func initialsFrom(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts.first!.prefix(1) + parts.last!.prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Preview

#Preview {
    PTClientsView()
        .environment(DataSyncManager())
}

// MARK: - PTClientDetailView

struct PTClientDetailView: View {
    let client: Client
    @State private var showUpdateStats = false
    @State private var showMealReview = false

    private var completedSessions: Int {
        client.sessions.filter { $0.isCompleted }.count
    }

    private var activePurchases: [PackagePurchase] {
        client.purchases.filter { !$0.isExpired && !$0.isFullyUsed }
    }

    private var expiredPurchases: [PackagePurchase] {
        client.purchases.filter { $0.isExpired || $0.isFullyUsed }
    }

    private var hasBodyStats: Bool {
        client.weight > 0 || client.bodyFat > 0 || client.muscleMass > 0
    }

    private var hasMeasurements: Bool {
        client.neck > 0 || client.shoulder > 0 || client.arm > 0 ||
        client.chest > 0 || client.waist > 0 || client.hip > 0 ||
        client.thigh > 0 || client.calf > 0 || client.lowerHip > 0
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                mealReviewBanner
                trainingStatsRow
                if hasBodyStats { bodyStatsGrid }
                if hasMeasurements { measurementsSection }
                if !client.goal.isEmpty { goalSection }
                activePackagesSection
                if !expiredPurchases.isEmpty { expiredPackagesSection }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cập nhật") { showUpdateStats = true }
                    .foregroundStyle(Theme.Colors.softOrange)
            }
        }
        .sheet(isPresented: $showUpdateStats) {
            UpdateBodyStatsSheet(client: client)
        }
        .navigationDestination(isPresented: $showMealReview) {
            ClientMealReviewView(client: client)
        }
    }
}

// MARK: - PTClientDetailView Subviews

private extension PTClientDetailView {

    // MARK: Meal Review Banner

    var mealReviewBanner: some View {
        Button { showMealReview = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.fitGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nhật ký bữa ăn")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    Text("Xem & nhận xét bữa ăn hằng ngày")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.fitCard)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Profile Card

    var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                // Avatar circle with initials
                Text(ptInitials(from: client.name))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.Colors.softOrange, Theme.Colors.warmYellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.title3.bold())
                        .foregroundStyle(Color.fitTextPrimary)

                    if !client.goal.isEmpty {
                        Text(client.goal)
                            .font(.caption)
                            .foregroundStyle(Color.fitTextSecondary)
                            .lineLimit(1)
                    }

                    if !client.phone.isEmpty {
                        Label(client.phone, systemImage: "phone.fill")
                            .font(.caption)
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                }

                Spacer()
            }

            // Body stat chips
            if hasBodyStats {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if client.weight > 0 {
                            bodyStatChip(
                                label: "Cân nặng",
                                value: String(format: "%.1f kg", client.weight),
                                color: Color.fitIndigo
                            )
                        }
                        if client.bodyFat > 0 {
                            bodyStatChip(
                                label: "Mỡ",
                                value: String(format: "%.1f%%", client.bodyFat),
                                color: Color.fitOrange
                            )
                        }
                        if client.muscleMass > 0 {
                            bodyStatChip(
                                label: "Cơ bắp",
                                value: String(format: "%.1f kg", client.muscleMass),
                                color: Color.fitGreen
                            )
                        }
                    }
                }
            }

            // Update button — full width pill
            Button {
                showUpdateStats = true
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Cập nhật chỉ số")
                    Spacer()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Colors.softOrange)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .strokeBorder(Theme.Colors.softOrange, lineWidth: 1.5)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    func bodyStatChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Training Stats Row

    var trainingStatsRow: some View {
        HStack(spacing: 12) {
            trainingStatCard(
                icon: "list.clipboard",
                value: "\(client.sessions.count)",
                label: "Tổng buổi",
                color: Color.fitIndigo
            )
            trainingStatCard(
                icon: "checkmark.circle.fill",
                value: "\(completedSessions)",
                label: "Hoàn thành",
                color: Color.fitGreen
            )
            trainingStatCard(
                icon: "clock.arrow.circlepath",
                value: "\(client.remainingSessions)",
                label: "Còn lại",
                color: Theme.Colors.softOrange
            )
        }
    }

    func trainingStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color.fitTextPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Body Stats Grid

    var bodyStatsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Chỉ số cơ thể", icon: "figure.arms.open")

            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                if client.weight > 0 {
                    bodyStatCell(label: "Cân nặng", value: String(format: "%.1f", client.weight), unit: "kg")
                }
                if client.bodyFat > 0 {
                    bodyStatCell(label: "Mỡ cơ thể", value: String(format: "%.1f", client.bodyFat), unit: "%")
                }
                if client.muscleMass > 0 {
                    bodyStatCell(label: "Cơ bắp", value: String(format: "%.1f", client.muscleMass), unit: "kg")
                }
                if client.height > 0 {
                    bodyStatCell(label: "Chiều cao", value: String(format: "%.0f", client.height), unit: "cm")
                }
            }
        }
    }

    func bodyStatCell(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.fitTextTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(Color.fitTextPrimary)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.fitTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: Measurements Section

    var measurementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Số đo cơ thể", icon: "ruler")

            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                if client.neck > 0 { measurementCell(name: "Cổ", value: client.neck) }
                if client.shoulder > 0 { measurementCell(name: "Vai", value: client.shoulder) }
                if client.arm > 0 { measurementCell(name: "Cánh tay", value: client.arm) }
                if client.chest > 0 { measurementCell(name: "Vòng 1", value: client.chest) }
                if client.waist > 0 { measurementCell(name: "Eo", value: client.waist) }
                if client.hip > 0 { measurementCell(name: "Hông", value: client.hip) }
                if client.thigh > 0 { measurementCell(name: "Đùi", value: client.thigh) }
                if client.calf > 0 { measurementCell(name: "Bắp chân", value: client.calf) }
                if client.lowerHip > 0 { measurementCell(name: "Vòng 3", value: client.lowerHip) }
            }
        }
    }

    func measurementCell(name: String, value: Double) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.fitTextSecondary)
            Spacer()
            Text(String(format: "%.1f cm", value))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.fitTextPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: Goal Section

    var goalSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "target")
                .font(.title3)
                .foregroundStyle(Theme.Colors.softOrange)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.softOrange.opacity(0.12), in: Circle())

            Text(client.goal)
                .font(.subheadline)
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: Active Packages Section

    var activePackagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                sectionHeader(title: "Gói PT đang sử dụng", icon: "ticket.fill")

                Text("\(activePurchases.count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.softOrange, in: Capsule())

                Spacer()
            }

            if activePurchases.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "ticket")
                            .font(.title2)
                            .foregroundStyle(Color.fitTextTertiary)
                        Text("Không có gói đang hoạt động")
                            .font(.subheadline)
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )
            } else {
                ForEach(activePurchases) { purchase in
                    NavigationLink(destination: PackageSessionHistoryView(purchase: purchase)) {
                        activePackageCard(purchase)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func activePackageCard(_ purchase: PackagePurchase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name row
            HStack {
                Image(systemName: "ticket.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.softOrange)

                Text(purchase.package?.name ?? "Gói PT")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.fitTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.fitTextTertiary)
            }

            // Progress bar
            ProgressView(
                value: Double(purchase.usedSessions),
                total: Double(max(purchase.totalSessions, 1))
            )
            .tint(purchase.remainingSessions > 3 ? Color.fitGreen : Color.fitCoral)

            // Sessions and expiry row
            HStack {
                Text("Còn \(purchase.remainingSessions)/\(purchase.totalSessions) buổi")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(purchase.remainingSessions > 3 ? Color.fitGreen : Color.fitCoral)

                Spacer()

                Text("HSD: \(dateFormatter.string(from: purchase.expiryDate))")
                    .font(.caption)
                    .foregroundStyle(Color.fitTextTertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Expired Packages Section

    var expiredPackagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Gói đã kết thúc", icon: "clock.badge.checkmark")

            ForEach(expiredPurchases) { purchase in
                NavigationLink(destination: PackageSessionHistoryView(purchase: purchase)) {
                    expiredPackageCard(purchase)
                }
                .buttonStyle(.plain)
                .opacity(0.5)
            }
        }
    }

    func expiredPackageCard(_ purchase: PackagePurchase) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "ticket")
                .font(.subheadline)
                .foregroundStyle(Color.fitTextTertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text(purchase.package?.name ?? "Gói PT")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.fitTextPrimary)
                Text("\(purchase.usedSessions)/\(purchase.totalSessions) buổi")
                    .font(.caption)
                    .foregroundStyle(Color.fitTextSecondary)
            }

            Spacer()

            Text(purchase.isFullyUsed ? "Đã hết buổi" : "Hết hạn")
                .font(.caption.weight(.medium))
                .foregroundStyle(purchase.isFullyUsed ? Color.fitGreen : Color.fitCoral)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    (purchase.isFullyUsed ? Color.fitGreen : Color.fitCoral)
                        .opacity(0.12),
                    in: Capsule()
                )

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: Helpers

    func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Color.fitTextPrimary)
            .padding(.top, 4)
    }

    func ptInitials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts.first!.prefix(1) + parts.last!.prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
