import SwiftUI

// MARK: - Client Filter

enum ClientFilter: String, CaseIterable {
    case all     = "Tất cả"
    case active  = "Đang hoạt động"
    case warning = "Sắp hết buổi"
    case expired = "Hết buổi"

    var chipColor: Color {
        switch self {
        case .all:     Theme.Colors.mintGreen
        case .active:  .fitGreen
        case .warning: .fitOrange
        case .expired: .fitCoral
        }
    }
}

// MARK: - ClientListView

struct ClientListView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showingAddForm = false
    @State private var searchText = ""
    @State private var selectedFilter: ClientFilter = .all
    @State private var clientToDelete: Client?

    // MARK: - Filtered Data

    private var filteredClients: [Client] {
        var list = syncManager.clients
        if let branchId = syncManager.selectedBranchId {
            list = list.filter { $0.branchId == branchId }
        }
        let sorted = list.sorted { $0.name < $1.name }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func applyFilter(_ base: [Client]) -> [Client] {
        switch selectedFilter {
        case .all:     return base
        case .active:  return base.filter { $0.remainingSessions > 3 }
        case .warning: return base.filter { $0.remainingSessions > 0 && $0.remainingSessions <= 3 }
        case .expired: return base.filter { $0.remainingSessions == 0 }
        }
    }

    // MARK: - Body

    var body: some View {
        let base = filteredClients
        let displayed = applyFilter(base)
        let counts: [ClientFilter: Int] = [
            .all:     base.count,
            .active:  base.filter { $0.remainingSessions > 3 }.count,
            .warning: base.filter { $0.remainingSessions > 0 && $0.remainingSessions <= 3 }.count,
            .expired: base.filter { $0.remainingSessions == 0 }.count,
        ]

        NavigationStack {
            VStack(spacing: 0) {
                summaryBanner(clients: base)
                filterChips(counts: counts)
                clientScrollList(displayed)
            }
            .background(Theme.Colors.screenBackground)
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
            .confirmationDialog(
                "Xoá học viên \(clientToDelete?.name ?? "")?",
                isPresented: Binding(
                    get: { clientToDelete != nil },
                    set: { if !$0 { clientToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Xoá học viên", role: .destructive) {
                    if let client = clientToDelete {
                        Task { await syncManager.deleteClient(client) }
                        clientToDelete = nil
                    }
                }
                Button("Huỷ", role: .cancel) { clientToDelete = nil }
            } message: {
                Text("Hành động này không thể hoàn tác. Tất cả dữ liệu tập luyện sẽ bị xoá.")
            }
            .profileToolbar()
        }
    }
}

// MARK: - Subviews

private extension ClientListView {

    // MARK: Summary Banner

    func summaryBanner(clients: [Client]) -> some View {
        let activePackages = clients.lazy
            .flatMap(\.purchases)
            .filter { !$0.isExpired && !$0.isFullyUsed }
            .count
        let needsRenewal = clients.lazy
            .filter { $0.remainingSessions <= 2 && $0.remainingSessions > 0 }
            .count

        return HStack(spacing: 8) {
            statCard(
                icon: "person.2.fill",
                color: Theme.Colors.mintGreen,
                value: clients.count,
                label: "học viên"
            )
            statCard(
                icon: "ticket.fill",
                color: Theme.Colors.skyBlue,
                value: activePackages,
                label: "gói đang dùng"
            )
            statCard(
                icon: "exclamationmark.triangle.fill",
                color: .fitCoral,
                value: needsRenewal,
                label: "cần gia hạn",
                pulse: needsRenewal > 0
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    func statCard(
        icon: String,
        color: Color,
        value: Int,
        label: String,
        pulse: Bool = false
    ) -> some View {
        VStack(spacing: 6) {
            CuteIconCircle(icon: icon, color: color, size: 36)
                .symbolEffect(.pulse, isActive: pulse)

            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fitTextPrimary)
                .contentTransition(.numericText())

            Text(label)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Color.fitTextSecondary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .fill(color.opacity(0.10))
        )
    }

    // MARK: Filter Chips

    func filterChips(counts: [ClientFilter: Int]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClientFilter.allCases, id: \.self) { filter in
                    let isActive = selectedFilter == filter
                    let count = counts[filter] ?? 0

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: .medium, design: .rounded))

                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(isActive ? .white.opacity(0.25) : Color.fitCard)
                                    )
                                    .foregroundStyle(isActive ? .white : Color.fitTextTertiary)
                            }
                        }
                        .foregroundStyle(isActive ? .white : Color.fitTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(isActive ? filter.chipColor.gradient : Color.fitCard.gradient)
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

    func clientScrollList(_ displayed: [Client]) -> some View {
        ScrollView {
            if displayed.isEmpty {
                emptyState
                    .padding(.top, 80)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(displayed) { client in
                        NavigationLink(destination: ClientDetailView(client: client)) {
                            ClientCardView(client: client)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                clientToDelete = client
                            } label: {
                                Label("Xoá", systemImage: "trash.fill")
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: selectedFilter)
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

    // Pre-computed at init — not recalculated on every render pass
    let activePurchase: PackagePurchase?
    let accentColor: Color

    init(client: Client) {
        self.client = client
        self.activePurchase = client.purchases.first(where: { !$0.isExpired && !$0.isFullyUsed })
        let s = client.remainingSessions
        self.accentColor = s > 3 ? .fitGreen : (s > 0 ? .fitOrange : .fitCoral)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, 6)

            // Card content
            VStack(alignment: .leading, spacing: 10) {
                topRow
                if let purchase = activePurchase {
                    progressSection(purchase)
                }
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
    }
}

// MARK: - ClientCardView Subviews

private extension ClientCardView {

    var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            FitAvatarCircle(name: client.name, color: accentColor, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.name)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
                    .lineLimit(1)

                trainerAndBranchRow
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                remainingBadge
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fitTextTertiary)
            }
        }
    }

    var trainerAndBranchRow: some View {
        HStack(spacing: 6) {
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
                    .background(Capsule().fill(Color.fitCard))
                    .lineLimit(1)
            }
        }
    }

    var remainingBadge: some View {
        let s = client.remainingSessions
        let text = s > 3 ? "\(s) buổi" : (s > 0 ? "\(s) buổi!" : "Hết buổi")

        return Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(accentColor.opacity(0.12)))
    }

    func progressSection(_ purchase: PackagePurchase) -> some View {
        let used = Double(purchase.usedSessions)
        let total = Double(max(1, purchase.totalSessions))

        return HStack {
            ProgressView(value: used, total: total)
                .tint(accentColor)
                .scaleEffect(y: 1.5)
                .clipShape(Capsule())

            Spacer(minLength: 8)

            Text("\(purchase.remainingSessions)/\(purchase.totalSessions) buổi")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fitTextSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    ClientListView()
        .environment(DataSyncManager())
}
