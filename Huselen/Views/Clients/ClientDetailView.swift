import SwiftUI

// MARK: - ClientDetailView

struct ClientDetailView: View {
    var client: Client
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditForm = false
    @State private var showingPurchaseForm = false
    @State private var editingPurchase: PackagePurchase?
    @State private var showDeleteConfirm = false

    private var activePurchases: [PackagePurchase] {
        client.purchases.filter { !$0.isExpired && !$0.isFullyUsed }
    }

    private var expiredPurchases: [PackagePurchase] {
        client.purchases.filter { $0.isExpired || $0.isFullyUsed }
    }

    private var completedSessionsCount: Int {
        client.sessions.filter { $0.isCompleted }.count
    }

    private var hasBodyStats: Bool {
        client.height > 0 || client.weight > 0 || client.bodyFat > 0 || client.muscleMass > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeaderCard
                trainingStatsRow
                if !client.goal.isEmpty { goalCard }
                if hasBodyStats { bodyStatsSection }
                activePackagesSection
                if !expiredPurchases.isEmpty { expiredPackagesSection }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Theme.Colors.screenBackground)
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Button("Sửa") { showingEditForm = true }
                        .foregroundStyle(Theme.Colors.softOrange)
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.fitCoral)
                    }
                }
            }
        }
        .confirmationDialog(
            "Xoá học viên \(client.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Xoá học viên", role: .destructive) {
                Task {
                    await syncManager.deleteClient(client)
                    dismiss()
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Hành động này không thể hoàn tác. Tất cả dữ liệu tập luyện sẽ bị xoá.")
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

// MARK: - Subviews

private extension ClientDetailView {

    // MARK: Profile Header Card

    var profileHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                FitAvatarCircle(
                    name: client.name,
                    color: Theme.Colors.mintGreen,
                    size: 56
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)

                    if !client.goal.isEmpty {
                        Text(client.goal)
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(Color.fitTextSecondary)
                            .lineLimit(1)
                    }

                    if !client.phone.isEmpty {
                        Label(client.phone, systemImage: "phone.fill")
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(Color.fitTextTertiary)
                    }

                    if !client.email.isEmpty {
                        Label(client.email, systemImage: "envelope.fill")
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                }

                Spacer()
            }

            // Body stat chips (only non-zero values)
            let chips = bodyStatChips
            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips, id: \.label) { chip in
                            HStack(spacing: 4) {
                                Text(chip.label)
                                    .foregroundStyle(Color.fitTextTertiary)
                                Text(chip.value)
                                    .foregroundStyle(Color.fitTextPrimary)
                            }
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.fitCard)
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.fitCard)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Training Stats Row

    var trainingStatsRow: some View {
        HStack(spacing: 10) {
            miniStatCard(
                title: "Tổng buổi",
                value: "\(client.sessions.count)",
                color: Color.fitIndigo
            )
            miniStatCard(
                title: "Hoàn thành",
                value: "\(completedSessionsCount)",
                color: Color.fitGreen
            )
            miniStatCard(
                title: "Còn lại",
                value: "\(client.remainingSessions)",
                color: Theme.Colors.mintGreen
            )
        }
    }

    func miniStatCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.fitCard)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Goal Card

    var goalCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "target")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.Colors.warmYellow)
            Text(client.goal)
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Color.fitTextPrimary)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.Colors.warmYellow.opacity(0.08))
        )
    }

    // MARK: Body Stats Section

    var bodyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FitSectionHeader(title: "Chỉ số cơ thể", icon: "figure.stand")

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                if client.height > 0 {
                    bodyStatCell(label: "Chiều cao", value: String(format: "%.1f cm", client.height))
                }
                if client.weight > 0 {
                    bodyStatCell(label: "Cân nặng", value: String(format: "%.1f kg", client.weight))
                }
                if client.bodyFat > 0 {
                    bodyStatCell(label: "Tỷ lệ mỡ", value: String(format: "%.1f%%", client.bodyFat))
                }
                if client.muscleMass > 0 {
                    bodyStatCell(label: "Cơ bắp", value: String(format: "%.1f kg", client.muscleMass))
                }
            }
        }
    }

    func bodyStatCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fitTextTertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fitTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: Active Packages Section

    var activePackagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("Gói PT đang sử dụng")
                        .font(Theme.Fonts.headline())
                        .foregroundStyle(Color.fitTextPrimary)

                    if !activePurchases.isEmpty {
                        Text("\(activePurchases.count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Theme.Colors.mintGreen)
                            )
                    }
                }

                Spacer()

                Button(action: { showingPurchaseForm = true }) {
                    Text("Mua gói")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(Theme.Colors.mintGreen.gradient)
                        )
                }
            }

            if activePurchases.isEmpty {
                FitEmptyState(
                    icon: "ticket",
                    title: "Chưa có gói PT",
                    subtitle: "Mua gói để bắt đầu tập luyện"
                )
            } else {
                ForEach(activePurchases) { purchase in
                    NavigationLink(destination: PackageSessionHistoryView(purchase: purchase)) {
                        activePurchaseCard(purchase: purchase)
                    }
                    .buttonStyle(.plain)
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
    }

    func activePurchaseCard(purchase: PackagePurchase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: package name + price
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.mintGreen)
                    Text(purchase.package?.name ?? "Gói PT")
                        .font(Theme.Fonts.subheadline())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.fitTextPrimary)
                }
                Spacer()
                Text(formatVND(purchase.price))
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Color.fitGreen)
            }

            // Row 2: trainer + remaining badge
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fitTextTertiary)
                    Text("PT: \(purchase.trainer?.name ?? "N/A")")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextSecondary)
                }
                Spacer()
                Text("Còn \(purchase.remainingSessions)/\(purchase.totalSessions) buổi")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(
                        purchase.remainingSessions > 0 ? Color.fitGreen : Color.fitCoral
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                (purchase.remainingSessions > 0 ? Color.fitGreen : Color.fitCoral)
                                    .opacity(0.1)
                            )
                    )
            }

            // Progress bar
            FitProgressBar(
                value: Double(purchase.usedSessions),
                total: Double(purchase.totalSessions),
                color: purchase.remainingSessions > 3 ? Color.fitGreen : Color.fitCoral
            )

            // Expiry date
            Text("HSD: \(purchase.expiryDate, format: .dateTime.day().month().year())")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.fitCard)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Expired Packages Section

    var expiredPackagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FitSectionHeader(title: "Gói đã kết thúc", icon: "clock.arrow.circlepath")

            ForEach(expiredPurchases) { purchase in
                NavigationLink(destination: PackageSessionHistoryView(purchase: purchase)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(purchase.package?.name ?? "Gói PT")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Color.fitTextPrimary)
                            Text("Mua: \(purchase.purchaseDate, format: .dateTime.day().month().year())")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.fitTextTertiary)
                        }
                        Spacer()
                        if purchase.isFullyUsed {
                            FitBadge(text: "Đã hết buổi", color: Color.fitGreen)
                        } else {
                            FitBadge(text: "Hết hạn", color: Color.fitCoral)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.fitCard)
                    )
                }
                .buttonStyle(.plain)
                .opacity(0.5)
            }
        }
    }

    // MARK: Helpers

    struct BodyChip: Hashable {
        let label: String
        let value: String
    }

    var bodyStatChips: [BodyChip] {
        var chips: [BodyChip] = []
        if client.weight > 0 {
            chips.append(BodyChip(label: "CN:", value: String(format: "%.0f kg", client.weight)))
        }
        if client.bodyFat > 0 {
            chips.append(BodyChip(label: "Mỡ:", value: String(format: "%.0f%%", client.bodyFat)))
        }
        if client.muscleMass > 0 {
            chips.append(BodyChip(label: "Cơ:", value: String(format: "%.0f kg", client.muscleMass)))
        }
        return chips
    }
}
