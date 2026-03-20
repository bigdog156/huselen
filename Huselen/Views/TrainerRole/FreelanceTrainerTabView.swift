import SwiftUI

struct FreelanceTrainerTabView: View {
    var body: some View {
        TabView {
            PTScheduleView()
                .tabItem {
                    Label("Lịch của tôi", systemImage: "calendar")
                }

            FreelancePTClientsView()
                .tabItem {
                    Label("Học viên", systemImage: "person.2")
                }

            FreelanceStatsView()
                .tabItem {
                    Label("Thống kê", systemImage: "chart.bar")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.softOrange)
    }
}

// MARK: - Freelance Stats View

struct FreelanceStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var totalClients: Int { syncManager.clients.count }

    private var sessionsThisMonth: Int {
        syncManager.sessions.filter {
            $0.isCompleted && Calendar.current.isDate($0.scheduledDate, equalTo: Date(), toGranularity: .month)
        }.count
    }

    private var completionRate: Double {
        let total = syncManager.sessions.count
        guard total > 0 else { return 0 }
        return Double(syncManager.sessions.filter { $0.isCompleted }.count) / Double(total) * 100
    }

    private var recentCompleted: [TrainingGymSession] {
        syncManager.sessions
            .filter { $0.isCompleted }
            .sorted { $0.scheduledDate > $1.scheduledDate }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsCardsRow
                    recentActivitySection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Thống kê")
            .profileToolbar()
            .refreshable {
                await syncManager.refresh()
            }
        }
    }
}

// MARK: - Subviews

private extension FreelanceStatsView {

    // MARK: - Stats Cards Row

    var statsCardsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "person.2.fill",
                value: "\(totalClients)",
                label: "Học viên",
                color: Color.fitIndigo
            )
            statCard(
                icon: "checkmark.circle.fill",
                value: "\(sessionsThisMonth)",
                label: "Buổi tháng này",
                color: Color.fitGreen
            )
            statCard(
                icon: "chart.line.uptrend.xyaxis",
                value: String(format: "%.0f%%", completionRate),
                label: "Hoàn thành",
                color: Theme.Colors.softOrange
            )
        }
    }

    func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color.fitTextPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.fitTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: - Recent Activity

    var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hoạt động gần đây", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(Color.fitTextPrimary)

            if recentCompleted.isEmpty {
                emptyActivityView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentCompleted.enumerated()), id: \.element.id) { index, session in
                        recentSessionRow(session)

                        if index < recentCompleted.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                )
            }
        }
    }

    var emptyActivityView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(Color.fitTextTertiary)
            Text("Chưa có buổi tập hoàn thành")
                .font(.subheadline)
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    func recentSessionRow(_ session: TrainingGymSession) -> some View {
        HStack(spacing: 12) {
            // Date circle
            VStack(spacing: 2) {
                Text(session.scheduledDate, format: .dateTime.day())
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.Colors.softOrange)
                Text(session.scheduledDate, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(Color.fitTextTertiary)
            }
            .frame(width: 40)

            // Session info
            VStack(alignment: .leading, spacing: 3) {
                Text(session.client?.name ?? "Học viên")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.fitTextPrimary)
                HStack(spacing: 6) {
                    Text(session.scheduledDate, format: .dateTime.hour().minute())
                    Text("\(session.duration) phút")
                }
                .font(.caption)
                .foregroundStyle(Color.fitTextTertiary)
            }

            Spacer()

            // Completed badge
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.fitGreen)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
