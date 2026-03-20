import SwiftUI
import Charts

// MARK: - Weekly Data Point

private struct WeeklySessionData: Identifiable {
    let id = UUID()
    let weekLabel: String
    let weekStart: Date
    let count: Int
}

// MARK: - Day-of-Week Data Point

private struct DayOfWeekData: Identifiable {
    let id = UUID()
    let dayName: String
    let dayIndex: Int
    let count: Int
}

// MARK: - Top Client Data

private struct TopClientData: Identifiable {
    let id: UUID
    let name: String
    let sessionCount: Int
    let color: Color
}

// MARK: - View

struct PTStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var myTrainer: Trainer? { syncManager.trainers.first }
    private var sessions: [TrainingGymSession] { syncManager.sessions }
    private var purchases: [PackagePurchase] { syncManager.purchases }

    // MARK: - Computed Stats

    private var completedSessions: [TrainingGymSession] {
        sessions.filter { $0.isCompleted }
    }

    private var thisMonthCompleted: Int {
        let calendar = Calendar.current
        return completedSessions.filter {
            calendar.isDate($0.scheduledDate, equalTo: Date(), toGranularity: .month)
        }.count
    }

    private var thisMonthTotal: Int {
        let calendar = Calendar.current
        return sessions.filter {
            calendar.isDate($0.scheduledDate, equalTo: Date(), toGranularity: .month)
        }.count
    }

    private var completionRate: Double {
        guard thisMonthTotal > 0 else { return 0 }
        return Double(thisMonthCompleted) / Double(thisMonthTotal) * 100
    }

    private var thisMonthRevenue: Double {
        myTrainer?.revenueInMonth(Date()) ?? 0
    }

    // MARK: - Chart Data

    private var weeklyData: [WeeklySessionData] {
        let calendar = Calendar.current
        let now = Date()
        var result: [WeeklySessionData] = []

        for weeksAgo in stride(from: 7, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else { continue }
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start ?? weekStart
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? weekStart

            let count = completedSessions.filter {
                $0.scheduledDate >= startOfWeek && $0.scheduledDate < endOfWeek
            }.count

            let day = calendar.component(.day, from: startOfWeek)
            let month = calendar.component(.month, from: startOfWeek)
            let label = "\(day)/\(month)"

            result.append(WeeklySessionData(weekLabel: label, weekStart: startOfWeek, count: count))
        }
        return result
    }

    private var dayOfWeekData: [DayOfWeekData] {
        let calendar = Calendar.current
        let dayNames = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
        var counts = [Int](repeating: 0, count: 7)

        for session in completedSessions {
            // weekday: 1 = Sunday, 2 = Monday ... 7 = Saturday
            let weekday = calendar.component(.weekday, from: session.scheduledDate)
            // Convert to Mon=0, Tue=1, ... Sun=6
            let index = (weekday + 5) % 7
            counts[index] += 1
        }

        return (0..<7).map { i in
            DayOfWeekData(dayName: dayNames[i], dayIndex: i, count: counts[i])
        }
    }

    // MARK: - Top Clients

    private var topClients: [TopClientData] {
        let clientColors: [Color] = [Theme.Colors.softOrange, .fitIndigo, .fitGreen]
        var clientSessionCounts: [UUID: (name: String, count: Int)] = [:]

        for session in completedSessions {
            guard let client = session.client else { continue }
            let existing = clientSessionCounts[client.id]
            clientSessionCounts[client.id] = (
                name: client.name,
                count: (existing?.count ?? 0) + 1
            )
        }

        let sorted = clientSessionCounts.sorted { $0.value.count > $1.value.count }
        return Array(sorted.prefix(3)).enumerated().map { index, entry in
            TopClientData(
                id: entry.key,
                name: entry.value.name,
                sessionCount: entry.value.count,
                color: clientColors[index % clientColors.count]
            )
        }
    }

    // MARK: - Recent Sessions

    private var recentSessions: [TrainingGymSession] {
        Array(
            completedSessions
                .sorted { $0.scheduledDate > $1.scheduledDate }
                .prefix(10)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCards
                    weeklyChart
                    dayOfWeekChart
                    topClientsSection
                    recentSessionsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Thống kê")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}

// MARK: - Subviews

private extension PTStatsView {

    // MARK: Hero Cards

    var heroCards: some View {
        HStack(spacing: 12) {
            heroCard(
                title: "Buổi tháng này",
                value: "\(thisMonthCompleted)",
                icon: "flame.fill",
                color: Theme.Colors.softOrange
            )
            heroCard(
                title: "Tỉ lệ HT",
                value: String(format: "%.0f%%", completionRate),
                icon: "checkmark.circle.fill",
                color: .fitGreen
            )
            heroCard(
                title: "Doanh thu",
                value: formatVND(thisMonthRevenue),
                icon: "banknote.fill",
                color: .fitIndigo
            )
        }
        .padding(.top, 8)
    }

    func heroCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(Theme.Fonts.headline())
                .foregroundStyle(Color.fitTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Color.fitTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Weekly Line Chart

    var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Buổi tập theo tuần", icon: "chart.line.uptrend.xyaxis")

            Chart(weeklyData) { item in
                LineMark(
                    x: .value("Tuần", item.weekLabel),
                    y: .value("Buổi", item.count)
                )
                .foregroundStyle(Theme.Colors.softOrange)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))

                AreaMark(
                    x: .value("Tuần", item.weekLabel),
                    y: .value("Buổi", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.Colors.softOrange.opacity(0.25), Theme.Colors.softOrange.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Tuần", item.weekLabel),
                    y: .value("Buổi", item.count)
                )
                .foregroundStyle(Theme.Colors.softOrange)
                .symbolSize(30)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel()
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextTertiary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(.systemGray4))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Day of Week Bar Chart

    var dayOfWeekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Phân bổ theo thứ", icon: "calendar")

            Chart(dayOfWeekData) { item in
                BarMark(
                    x: .value("Thứ", item.dayName),
                    y: .value("Buổi", item.count)
                )
                .foregroundStyle(
                    item.count == (dayOfWeekData.map(\.count).max() ?? 0)
                        ? Theme.Colors.softOrange
                        : Theme.Colors.softOrange.opacity(0.4)
                )
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextTertiary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color(.systemGray4))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
            .frame(height: 180)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Top Clients

    var topClientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Học viên tích cực", icon: "person.3.fill")

            if topClients.isEmpty {
                Text("Chưa có dữ liệu")
                    .font(Theme.Fonts.body())
                    .foregroundStyle(Color.fitTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(topClients) { client in
                        HStack(spacing: 14) {
                            // Avatar initials circle
                            Text(initialsFrom(client.name))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(
                                    Circle().fill(client.color)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(Theme.Fonts.subheadline())
                                    .foregroundStyle(Color.fitTextPrimary)

                                Text("\(client.sessionCount) buổi hoàn thành")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Color.fitTextSecondary)
                            }

                            Spacer()

                            Text("\(client.sessionCount)")
                                .font(Theme.Fonts.title3())
                                .foregroundStyle(client.color)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Recent Sessions

    var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Buổi dạy gần đây", icon: "clock.fill")

            if recentSessions.isEmpty {
                Text("Chưa có buổi dạy nào")
                    .font(Theme.Fonts.body())
                    .foregroundStyle(Color.fitTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentSessions.enumerated()), id: \.element.id) { index, session in
                        sessionRow(session)

                        if index < recentSessions.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    func sessionRow(_ session: TrainingGymSession) -> some View {
        HStack(spacing: 14) {
            // Client initials
            let clientName = session.client?.name ?? "N/A"
            Text(initialsFrom(clientName))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(Theme.Colors.softOrange.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(clientName)
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Color.fitTextPrimary)

                Text(session.scheduledDate, format: .dateTime.day().month().year())
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Color.fitTextTertiary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.fitTextTertiary)
                Text("\(session.duration) phút")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Color.fitTextSecondary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: Helpers

    func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.softOrange)
            Text(title)
                .font(Theme.Fonts.headline())
                .foregroundStyle(Color.fitTextPrimary)
        }
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
    PTStatsView()
        .environment(DataSyncManager())
}
