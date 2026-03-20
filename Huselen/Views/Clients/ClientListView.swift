import SwiftUI

// MARK: - Client Filter

enum ClientFilter: String, CaseIterable {
    case all = "Tất cả"
    case active = "Đang hoạt động"
    case warning = "Sắp hết buổi"
    case expired = "Hết buổi"
}

// MARK: - ClientListView

struct ClientListView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showingAddForm = false
    @State private var searchText = ""
    @State private var selectedFilter: ClientFilter = .all

    // MARK: - Filtered Data

    private var filteredClients: [Client] {
        var list = syncManager.clients
        if let branchId = syncManager.selectedBranchId {
            list = list.filter { $0.branchId == branchId }
        }
        let sorted = list.sorted { $0.name < $1.name }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var displayedClients: [Client] {
        let base = filteredClients
        switch selectedFilter {
        case .all: return base
        case .active: return base.filter { $0.remainingSessions > 3 }
        case .warning: return base.filter { $0.remainingSessions > 0 && $0.remainingSessions <= 3 }
        case .expired: return base.filter { $0.remainingSessions == 0 }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                summaryBanner
                filterChips
                clientScrollList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Học viên")
            .searchable(text: $searchText, prompt: "Tìm học viên...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddForm = true }) {
                        Label("Thêm", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                SearchClientView()
            }
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}

// MARK: - Subviews

private extension ClientListView {

    // MARK: Summary Banner

    var summaryBanner: some View {
        let activePackages = filteredClients.flatMap(\.purchases)
            .filter { !$0.isExpired && !$0.isFullyUsed }
            .count
        let needsRenewal = filteredClients
            .filter { $0.remainingSessions <= 2 && $0.remainingSessions > 0 }
            .count

        return HStack(spacing: 0) {
            bannerStat(
                icon: "person.2.fill",
                value: "\(filteredClients.count)",
                label: "học viên"
            )
            bannerStat(
                icon: "ticket.fill",
                value: "\(activePackages)",
                label: "gói đang dùng"
            )
            bannerStat(
                icon: "exclamationmark.circle",
                value: "\(needsRenewal)",
                label: "cần gia hạn"
            )
        }
        .padding(.vertical, 12)
        .background(Theme.Colors.mintGreen.opacity(0.08))
    }

    func bannerStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.mintGreen)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fitTextPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Filter Chips

    var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClientFilter.allCases, id: \.self) { filter in
                    let isActive = selectedFilter == filter
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(isActive ? .white : Color.fitTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(isActive ? Theme.Colors.mintGreen : Color.fitCard)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: Client Scroll List

    var clientScrollList: some View {
        ScrollView {
            if displayedClients.isEmpty {
                emptyState
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(displayedClients) { client in
                        NavigationLink(destination: ClientDetailView(client: client)) {
                            ClientCardView(client: client)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                Task { await syncManager.deleteClient(client) }
                            } label: {
                                Label("Xoá", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Empty State

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: syncManager.selectedBranchId != nil
                  ? "building.2.slash"
                  : "person.crop.circle.badge.plus")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.fitTextTertiary)
            Text("Chưa có học viên")
                .font(Theme.Fonts.title3())
                .foregroundStyle(Color.fitTextPrimary)
            Text(syncManager.selectedBranchId != nil
                 ? "Không có học viên ở cơ sở này"
                 : "Nhấn + để thêm học viên mới")
                .font(Theme.Fonts.caption())
                .foregroundStyle(Color.fitTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ClientCardView

struct ClientCardView: View {
    let client: Client

    private var accentColor: Color {
        if client.remainingSessions > 3 {
            return .fitGreen
        } else if client.remainingSessions > 0 {
            return .fitOrange
        } else {
            return .fitCoral
        }
    }

    private var activePurchase: PackagePurchase? {
        client.purchases.first(where: { !$0.isExpired && !$0.isFullyUsed })
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 6)

            // Card content
            VStack(alignment: .leading, spacing: 10) {
                topRow
                if let purchase = activePurchase {
                    packageSection(purchase)
                }
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        )
    }
}

// MARK: - ClientCardView Subviews

private extension ClientCardView {

    var topRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                FitAvatarCircle(
                    name: client.name,
                    color: accentColor,
                    size: 50
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

                    trainerAndBranchRow
                }

                Spacer(minLength: 4)

                remainingBadge
            }
        }
    }

    var trainerAndBranchRow: some View {
        HStack(spacing: 8) {
            if let trainerName = activePurchase?.trainer?.name {
                Label("PT: \(trainerName)", systemImage: "figure.strengthtraining.traditional")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fitTextTertiary)
                    .lineLimit(1)
            }

            if let branch = client.branch {
                Text(branch.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fitTextSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.fitCard)
                    )
                    .lineLimit(1)
            }
        }
    }

    var remainingBadge: some View {
        Group {
            if client.remainingSessions > 3 {
                badgeCapsule(
                    text: "\(client.remainingSessions) buổi",
                    color: .fitGreen
                )
            } else if client.remainingSessions > 0 {
                badgeCapsule(
                    text: "\(client.remainingSessions) buổi",
                    color: .fitOrange
                )
            } else {
                badgeCapsule(
                    text: "Hết buổi",
                    color: .fitCoral
                )
            }
        }
    }

    func badgeCapsule(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }

    func packageSection(_ purchase: PackagePurchase) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.mintGreen)
                Text(purchase.package?.name ?? "Gói PT")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
                    .lineLimit(1)
                Spacer()
                Text("\(purchase.remainingSessions)/\(purchase.totalSessions) buổi")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(purchase.remainingSessions > 3 ? Color.fitGreen : Color.fitCoral)
            }

            ProgressView(
                value: Double(purchase.usedSessions),
                total: Double(max(1, purchase.totalSessions))
            )
            .tint(purchase.remainingSessions > 3 ? Color.fitGreen : Color.fitCoral)

            HStack {
                Label(
                    purchase.expiryDate.formatted(.dateTime.day().month().year()),
                    systemImage: "clock.fill"
                )
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Color.fitTextTertiary)
                Spacer()
            }
        }
        .padding(10)
        .background(Color.fitCard, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    ClientListView()
        .environment(DataSyncManager())
}
