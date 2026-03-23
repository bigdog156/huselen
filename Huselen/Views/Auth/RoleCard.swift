import SwiftUI

struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.opacity(0.12)))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : color)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.headline())
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(subtitle)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? color : Theme.Colors.textTertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            .strokeBorder(
                                isSelected ? color.opacity(0.5) : Color.clear,
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isSelected ? color.opacity(0.15) : .black.opacity(0.04),
                        radius: isSelected ? 12 : 6,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.0 : 0.98)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        RoleCard(
            icon: "building.2.fill",
            title: "Chủ phòng gym",
            subtitle: "Quản lý phòng tập, nhân viên và hội viên",
            color: Theme.Colors.warmYellow,
            isSelected: true,
            action: {}
        )
        RoleCard(
            icon: "figure.strengthtraining.traditional",
            title: "Personal Trainer",
            subtitle: "Quản lý lịch tập và học viên của bạn",
            color: Theme.Colors.softOrange,
            isSelected: false,
            action: {}
        )
    }
    .padding()
    .background(Theme.Colors.cream)
}
