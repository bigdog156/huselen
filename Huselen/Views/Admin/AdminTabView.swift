import SwiftUI

struct AdminTabView: View {
    @Environment(DataSyncManager.self) private var syncManager

    var body: some View {
        VStack(spacing: 0) {
            if !syncManager.branches.isEmpty {
                BranchPickerBar()
            }

            TabView {
                AdminDashboardView()
                    .tabItem {
                        Label("Tổng quan", systemImage: "house.fill")
                    }

                ScheduleView()
                    .tabItem {
                        Label("Lịch tập", systemImage: "calendar")
                    }

                TrainerListView()
                    .tabItem {
                        Label("PT", systemImage: "figure.strengthtraining.traditional")
                    }

                ClientListView()
                    .tabItem {
                        Label("Khách hàng", systemImage: "person.2")
                    }

                AdminManagementView()
                    .tabItem {
                        Label("Quản lý", systemImage: "gearshape.2")
                    }
            }
        }
        .environment(\.appAccentColor, Theme.Colors.warmYellow)
    }
}

struct BranchPickerBar: View {
    @Environment(DataSyncManager.self) private var syncManager

    var body: some View {
        @Bindable var sync = syncManager
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BranchChip(
                    title: "Tất cả",
                    isSelected: syncManager.selectedBranchId == nil
                ) {
                    syncManager.selectedBranchId = nil
                }

                ForEach(syncManager.branches.filter(\.isActive)) { branch in
                    BranchChip(
                        title: branch.name,
                        isSelected: syncManager.selectedBranchId == branch.id
                    ) {
                        syncManager.selectedBranchId = branch.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Theme.Colors.cardBackground)
    }
}

struct BranchChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.caption())
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.Colors.skyBlue : Theme.Colors.cardBackground)
                .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Theme.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Admin Dashboard View

struct AdminDashboardView: View {
    @Environment(DataSyncManager.self) private var syncManager

    // MARK: - Computed Properties

    private var todaySessionsCount: Int {
        syncManager.sessions.filter {
            Calendar.current.isDateInToday($0.scheduledDate)
        }.count
    }

    private var totalClients: Int {
        syncManager.clients.count
    }

    private var totalTrainers: Int {
        syncManager.trainers.count
    }

    private var monthlyRevenue: Double {
        syncManager.purchases.filter {
            Calendar.current.isDate($0.purchaseDate, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.price }
    }

    private var todayDateString: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "EEEE, dd/MM/yyyy"
        return df.string(from: Date()).capitalized
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    summaryCardsRow
                    revenueCard
                    quickLinksSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.Colors.screenBackground.ignoresSafeArea())
            .navigationTitle("Tổng quan")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}

// MARK: - Subviews

private extension AdminDashboardView {

    // MARK: Header

    var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tổng quan")
                    .font(Theme.Fonts.title())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(todayDateString)
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Color.fitTextSecondary)
            }
            Spacer()
        }
    }

    // MARK: Summary Cards

    var summaryCardsRow: some View {
        HStack(spacing: 12) {
            dashboardStatCard(
                title: "Hôm nay",
                value: "\(todaySessionsCount)",
                subtitle: "buổi tập",
                icon: "calendar.badge.clock",
                color: Theme.Colors.warmYellow
            )
            dashboardStatCard(
                title: "Khách hàng",
                value: "\(totalClients)",
                subtitle: "tổng số",
                icon: "person.2.fill",
                color: .fitIndigo
            )
            dashboardStatCard(
                title: "PT",
                value: "\(totalTrainers)",
                subtitle: "tổng số",
                icon: "figure.strengthtraining.traditional",
                color: Theme.Colors.mintGreen
            )
        }
    }

    func dashboardStatCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(Theme.Fonts.title())
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            VStack(spacing: 2) {
                Text(title)
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fitTextTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: Revenue Card

    var revenueCard: some View {
        VStack(spacing: 10) {
            HStack {
                CuteIconCircle(icon: "chart.bar.fill", color: Theme.Colors.warmYellow, size: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Doanh thu tháng")
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(formatVND(monthlyRevenue))
                        .font(Theme.Fonts.title())
                        .foregroundStyle(Theme.Colors.warmYellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Quick Links

    var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Truy cập nhanh")
                .font(Theme.Fonts.headline())
                .foregroundStyle(Theme.Colors.textPrimary)

            VStack(spacing: 10) {
                quickLinkRow(
                    icon: "chart.bar.fill",
                    title: "Doanh thu",
                    subtitle: "Xem chi tiết doanh thu",
                    color: Theme.Colors.warmYellow,
                    destination: RevenueView()
                )
                quickLinkRow(
                    icon: "figure.strengthtraining.traditional",
                    title: "Danh sách PT",
                    subtitle: "Quản lý huấn luyện viên",
                    color: Theme.Colors.mintGreen,
                    destination: TrainerListView()
                )
                quickLinkRow(
                    icon: "person.2.fill",
                    title: "Khách hàng",
                    subtitle: "Quản lý khách hàng",
                    color: .fitIndigo,
                    destination: ClientListView()
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

    func quickLinkRow<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                CuteIconCircle(icon: icon, color: color, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(Color.fitCard)
            )
        }
        .buttonStyle(.plain)
    }
}
