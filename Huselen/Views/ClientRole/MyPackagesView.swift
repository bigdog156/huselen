import SwiftUI


struct MyPackagesView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var purchases: [PackagePurchase] {
        syncManager.purchases.sorted { $0.purchaseDate < $1.purchaseDate }
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

    private var totalUsed: Int {
        activePurchases.reduce(0) { $0 + $1.usedSessions }
    }

    private func daysUntilExpiry(_ purchase: PackagePurchase) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: Date(), to: purchase.expiryDate).day ?? 0)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                heroCard
                    .padding(.horizontal, 24)

                if activePurchases.isEmpty {
                    emptyState
                        .padding(.horizontal, 24)
                } else {
                    activePackagesSection
                        .padding(.horizontal, 24)
                }

                if !expiredPurchases.isEmpty {
                    expiredSection
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 32)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .refreshable { await syncManager.refresh() }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quản lý gói tập")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
                Text("Gói của tôi")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
            }
            Spacer()
            avatarCircle
        }
    }

    private var avatarCircle: some View {
        let name = activePurchases.first?.client?.name ?? ""
        let initials = name.split(separator: " ").compactMap { $0.first }.suffix(2).map { String($0) }.joined()
        let display = initials.isEmpty ? "NH" : initials.uppercased()
        return ZStack {
            Circle().fill(Color.fitGreen).frame(width: 44, height: 44)
            Text(display).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.fitGreen, Color.fitGreenDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 140)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 100))
                        .foregroundStyle(.white.opacity(0.07))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 20)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(totalRemaining)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("buổi tập cùng PT")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
        }
    }

    // MARK: - Active Packages

    private var activePackagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GÓI ĐANG SỬ DỤNG")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)

            ForEach(activePurchases) { purchase in
                packageCard(purchase)
                statsRow(purchase)
                ctaBanner(purchase)
            }
        }
    }

    private func packageCard(_ purchase: PackagePurchase) -> some View {
        VStack(spacing: 14) {
            // Top row: name + trainer
            HStack {
                Text(purchase.package?.name ?? "Gói PT")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fitTextPrimary)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fitOrange)
                    Text(purchase.trainer?.name ?? "N/A")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }
            }

            // Usage info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đã dùng")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                    Text("\(purchase.usedSessions) / \(purchase.totalSessions) buổi")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fitTextPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Hạn sử dụng")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                    Text(purchase.expiryDate, format: .dateTime.day().month(.abbreviated).year())
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            daysUntilExpiry(purchase) < 7 ? Color.fitCoral : Color.fitTextPrimary
                        )
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.878, green: 0.882, blue: 0.886))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.fitGreen, Color.fitGreenDark],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * min(1, Double(purchase.usedSessions) / Double(max(1, purchase.totalSessions))),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard)
        )
    }

    private func statsRow(_ purchase: PackagePurchase) -> some View {
        HStack(spacing: 10) {
            miniStat(
                icon: "checkmark.circle",
                value: "\(purchase.usedSessions)",
                label: "Đã tập",
                color: Color.fitGreen,
                bg: Color.fitCard
            )
            miniStat(
                icon: "bolt.fill",
                value: "\(purchase.remainingSessions)",
                label: "Còn lại",
                color: Color.fitOrange,
                bg: Color(red: 1.0, green: 0.969, blue: 0.929)
            )
            miniStat(
                icon: "calendar",
                value: "\(daysUntilExpiry(purchase))",
                label: "Ngày",
                color: Color.fitGreen,
                bg: Color(red: 0.941, green: 0.992, blue: 0.957)
            )
        }
    }

    private func miniStat(icon: String, value: String, label: String, color: Color, bg: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(height: 20)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(bg))
    }

    private func ctaBanner(_ purchase: PackagePurchase) -> some View {
        HStack(spacing: 12) {
            Text("🏋️")
                .font(.system(size: 22))
            Text("Bắt đầu buổi tập đầu tiên ngay!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.fitTextPrimary)
                .lineLimit(1)
            Spacer()
            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.fitGreen)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.fitCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(red: 0.851, green: 0.929, blue: 0.851), lineWidth: 1)
                )
        )
    }

    // MARK: - Expired

    private var expiredSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GÓI ĐÃ KẾT THÚC")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)

            ForEach(expiredPurchases) { purchase in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(purchase.package?.name ?? "Gói PT")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fitTextSecondary)
                        Text("Mua: \(purchase.purchaseDate, format: .dateTime.day().month().year())")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    Spacer()
                    Text(purchase.isFullyUsed ? "Hết buổi" : "Hết hạn")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(purchase.isFullyUsed ? Color.fitGreen : Color.fitCoral)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                purchase.isFullyUsed
                                    ? Color.fitGreen.opacity(0.1)
                                    : Color.fitCoral.opacity(0.1)
                            )
                        )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.fitCard)
                )
                .opacity(0.7)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.system(size: 44))
                .foregroundStyle(Color.fitTextTertiary)
            Text("Chưa mua gói PT")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.fitTextPrimary)
            Text("Liên hệ phòng gym để mua gói tập")
                .font(.system(size: 14))
                .foregroundStyle(Color.fitTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
