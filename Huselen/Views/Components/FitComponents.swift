import SwiftUI

// MARK: - FitStatCard

struct FitStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                )

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fitTextPrimary)

            Text(label)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.fitCard)
        )
    }
}

// MARK: - FitProgressBar

struct FitProgressBar: View {
    let value: Double
    let total: Double
    let color: Color
    var height: CGFloat = 6

    private var progress: Double {
        total > 0 ? min(value / total, 1.0) : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: height)

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * progress, height: height)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: height)
    }
}

// MARK: - FitSectionHeader

struct FitSectionHeader: View {
    let title: String
    let icon: String
    var action: (() -> Void)? = nil
    var actionLabel: String = ""

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(Theme.Fonts.headline())
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()

            if let action, !actionLabel.isEmpty {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(Color.fitGreen)
                }
            }
        }
    }
}

// MARK: - FitEmptyState

struct FitEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.fitTextTertiary)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(Color.fitTextSecondary)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.fitTextTertiary)
                .multilineTextAlignment(.center)

            if let action, !actionLabel.isEmpty {
                Button(action: action) {
                    Text(actionLabel)
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.fitGreen)
                        )
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - FitAvatarCircle

struct FitAvatarCircle: View {
    let name: String
    var color: Color = Theme.Colors.softOrange
    var size: CGFloat = 44

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String((parts.first?.prefix(1) ?? "") + (parts.last?.prefix(1) ?? "")).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.gradient)
            )
    }
}

// MARK: - FitBadge

struct FitBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.Fonts.caption())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Previews

#Preview("FitStatCard") {
    HStack(spacing: 12) {
        FitStatCard(
            value: "24",
            label: "Khach hang",
            icon: "person.2.fill",
            color: .fitGreen
        )
        FitStatCard(
            value: "8",
            label: "Buoi hom nay",
            icon: "calendar",
            color: .fitIndigo
        )
        FitStatCard(
            value: "96%",
            label: "Hoan thanh",
            icon: "checkmark.circle.fill",
            color: .fitBlue
        )
    }
    .padding()
}

#Preview("FitProgressBar") {
    VStack(spacing: 20) {
        FitProgressBar(value: 7, total: 10, color: .fitGreen)
        FitProgressBar(value: 3, total: 10, color: .fitIndigo, height: 8)
        FitProgressBar(value: 10, total: 10, color: .fitCoral)
        FitProgressBar(value: 0, total: 10, color: .fitBlue)
    }
    .padding()
}

#Preview("FitSectionHeader") {
    VStack(spacing: 16) {
        FitSectionHeader(
            title: "Lich tap hom nay",
            icon: "calendar"
        )
        FitSectionHeader(
            title: "Khach hang",
            icon: "person.2.fill",
            action: {},
            actionLabel: "Xem tat ca"
        )
    }
    .padding()
}

#Preview("FitEmptyState") {
    VStack(spacing: 32) {
        FitEmptyState(
            icon: "calendar.badge.exclamationmark",
            title: "Chua co lich tap",
            subtitle: "Ban chua co buoi tap nao duoc len lich"
        )
        FitEmptyState(
            icon: "person.2.slash",
            title: "Chua co khach hang",
            subtitle: "Them khach hang de bat dau quan ly",
            action: {},
            actionLabel: "Them khach hang"
        )
    }
}

#Preview("FitAvatarCircle") {
    HStack(spacing: 12) {
        FitAvatarCircle(name: "Nguyen Van A")
        FitAvatarCircle(name: "Tran Thi B", color: .fitIndigo, size: 52)
        FitAvatarCircle(name: "Le C", color: .fitCoral, size: 36)
        FitAvatarCircle(name: "D", color: .fitGreen)
    }
}

#Preview("FitBadge") {
    HStack(spacing: 8) {
        FitBadge(text: "Dang hoat dong", color: .fitGreen)
        FitBadge(text: "Tam nghi", color: .fitCoral)
        FitBadge(text: "Moi", color: .fitIndigo)
    }
}
