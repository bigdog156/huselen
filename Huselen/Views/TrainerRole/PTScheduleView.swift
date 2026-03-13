import SwiftUI

// MARK: - Package Name Helper

private func packageName(for session: TrainingGymSession) -> String? {
    guard let purchaseID = session.purchaseID else { return nil }
    return session.client?.purchases
        .first { $0.purchaseID == purchaseID }?
        .package?
        .name
}

/// For a group of sessions, return the shared package name if all are the same
private func sharedPackageName(for sessions: [TrainingGymSession]) -> String? {
    let names = sessions.compactMap { packageName(for: $0) }
    guard !names.isEmpty else { return nil }
    let unique = Set(names)
    return unique.count == 1 ? unique.first : nil
}

// MARK: - Session Group (for PT view)

private enum PTSessionGroup: Identifiable {
    case single(TrainingGymSession)
    case group(sessions: [TrainingGymSession])

    var id: UUID {
        switch self {
        case .single(let s): s.id
        case .group(let sessions): sessions.first!.id
        }
    }

    var firstSession: TrainingGymSession {
        switch self {
        case .single(let s): s
        case .group(let sessions): sessions.first!
        }
    }

    var allSessions: [TrainingGymSession] {
        switch self {
        case .single(let s): [s]
        case .group(let sessions): sessions
        }
    }

    var isGroup: Bool {
        if case .group = self { return true }
        return false
    }

    var clientNames: String {
        allSessions.compactMap { $0.client?.name }.joined(separator: ", ")
    }
}

// MARK: - PT Schedule View

struct PTScheduleView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var allSessions: [TrainingGymSession] {
        syncManager.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    @State private var selectedDate = Date()
    @State private var viewMode: ViewMode = .day
    @State private var currentMonth = Date()

    enum ViewMode: String, CaseIterable {
        case day = "Ngày"
        case month = "Tháng"
    }

    private var calendar: Calendar { Calendar.current }

    private func sessions(for date: Date) -> [TrainingGymSession] {
        allSessions.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Groups overlapping sessions into group classes
    private func groupedSessions(for date: Date) -> [PTSessionGroup] {
        let daySessions = sessions(for: date)
        var used = Set<UUID>()
        var groups: [PTSessionGroup] = []

        for session in daySessions {
            guard !used.contains(session.id) else { continue }

            // Find all sessions that overlap with this one
            var cluster = [session]
            for other in daySessions where !used.contains(other.id) && other.id != session.id {
                if session.conflicts(with: other) {
                    cluster.append(other)
                }
            }

            for s in cluster { used.insert(s.id) }

            if cluster.count >= 2 {
                groups.append(.group(sessions: cluster.sorted { $0.scheduledDate < $1.scheduledDate }))
            } else {
                groups.append(.single(session))
            }
        }

        return groups
    }

    private var selectedDayGroups: [PTSessionGroup] {
        groupedSessions(for: selectedDate)
    }

    private var selectedDaySessions: [TrainingGymSession] {
        sessions(for: selectedDate)
    }

    private var upcomingGroups: [PTSessionGroup] {
        // Gather upcoming dates (not selected date), then group each
        let futureSessions = allSessions.filter { !$0.isCompleted && $0.scheduledDate > Date() }
        let futureDates = Set(futureSessions.map { calendar.startOfDay(for: $0.scheduledDate) })
            .sorted()
            .filter { !calendar.isDate($0, inSameDayAs: selectedDate) }

        var result: [PTSessionGroup] = []
        for date in futureDates {
            result.append(contentsOf: groupedSessions(for: date))
            if result.count >= 5 { break }
        }
        return Array(result.prefix(5))
    }

    // MARK: - Month calendar helpers

    private var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstDay) }
    }

    private var firstWeekdayOffset: Int {
        let firstDay = daysInMonth.first ?? currentMonth
        let weekday = calendar.component(.weekday, from: firstDay)
        return (weekday + 5) % 7
    }

    private let weekdaySymbols = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    viewModePicker
                        .padding(.horizontal)
                        .padding(.top, 8)

                    switch viewMode {
                    case .day:
                        dayView
                    case .month:
                        monthView
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Lịch của tôi")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(viewMode == mode ? .white : Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(viewMode == mode ? Theme.Colors.softOrange : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Day View

    private var dayView: some View {
        VStack(spacing: 16) {
            weekdayStrip
                .padding(.top, 12)

            if !selectedDaySessions.isEmpty {
                dayStatsBar
                    .padding(.horizontal)
            }

            // Grouped sessions list
            VStack(spacing: 12) {
                if selectedDayGroups.isEmpty {
                    emptyDayCard
                        .padding(.horizontal)
                } else {
                    ForEach(selectedDayGroups) { group in
                        switch group {
                        case .single(let session):
                            PTSessionCard(session: session)
                                .padding(.horizontal)
                        case .group(let sessions):
                            PTGroupSessionCard(sessions: sessions)
                                .padding(.horizontal)
                        }
                    }
                }
            }

            // Upcoming section
            if !upcomingGroups.isEmpty {
                upcomingSection
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Weekday Strip

    private var weekdayStrip: some View {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }

        return VStack(spacing: 8) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.softOrange)
                }

                Spacer()

                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(Theme.Fonts.headline())
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.softOrange)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let dayGroups = groupedSessions(for: date)
                    let hasGroup = dayGroups.contains { $0.isGroup }
                    let sessionCount = sessions(for: date).count

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(isSelected ? .white : Theme.Colors.textSecondary)

                            Text("\(calendar.component(.day, from: date))")
                                .font(Theme.Fonts.headline())
                                .foregroundStyle(isSelected ? .white : isToday ? Theme.Colors.softOrange : Theme.Colors.textPrimary)

                            // Session dots - use purple for group days
                            HStack(spacing: 3) {
                                if sessionCount > 0 {
                                    if hasGroup {
                                        // Group indicator
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 7))
                                            .foregroundStyle(isSelected ? .white : Theme.Colors.lavender)
                                    } else {
                                        ForEach(0..<min(sessionCount, 3), id: \.self) { _ in
                                            Circle()
                                                .fill(isSelected ? .white : Theme.Colors.softOrange)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                } else {
                                    Circle()
                                        .fill(.clear)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? Theme.Colors.softOrange : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Day Stats Bar

    private var dayStatsBar: some View {
        let total = selectedDaySessions.count
        let completed = selectedDaySessions.filter(\.isCompleted).count
        let groupCount = selectedDayGroups.filter(\.isGroup).count

        return HStack(spacing: 12) {
            statPill(icon: "calendar", value: "\(total)", label: "buổi", color: Theme.Colors.skyBlue)
            if groupCount > 0 {
                statPill(icon: "person.2.fill", value: "\(groupCount)", label: "lớp nhóm", color: Theme.Colors.lavender)
            }
            if completed > 0 {
                statPill(icon: "checkmark.circle", value: "\(completed)", label: "xong", color: Theme.Colors.mintGreen)
            }
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.bold())
                .foregroundStyle(color)
            Text(value)
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Empty Day

    private var emptyDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
            Text("Không có lịch tập")
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .cuteCard()
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sắp tới")
                .font(Theme.Fonts.headline())
                .foregroundStyle(Theme.Colors.textPrimary)

            ForEach(upcomingGroups) { group in
                switch group {
                case .single(let session):
                    PTSessionMiniRow(session: session)
                case .group(let sessions):
                    PTGroupMiniRow(sessions: sessions)
                }
            }
        }
    }

    // MARK: - Month View

    private var monthView: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.softOrange)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Colors.softOrange.opacity(0.1)))
                }

                Spacer()

                Text(monthTitle.capitalized)
                    .font(Theme.Fonts.title3())
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.softOrange)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.Colors.softOrange.opacity(0.1)))
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Today button
            if !calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month) {
                Button {
                    withAnimation {
                        currentMonth = Date()
                        selectedDate = Date()
                    }
                } label: {
                    Text("Hôm nay")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.softOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.Colors.softOrange.opacity(0.1)))
                }
            }

            monthCalendarGrid
                .padding(.horizontal)

            // Selected day grouped sessions
            VStack(alignment: .leading, spacing: 10) {
                Text("Ngày \(selectedDate.formatted(.dateTime.day().month()))")
                    .font(Theme.Fonts.headline())
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal)

                let dayGroups = groupedSessions(for: selectedDate)
                if dayGroups.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
                            Text("Không có lịch")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
                    ForEach(dayGroups) { group in
                        switch group {
                        case .single(let session):
                            PTSessionCard(session: session)
                                .padding(.horizontal)
                        case .group(let sessions):
                            PTGroupSessionCard(sessions: sessions)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Month Calendar Grid

    private var monthCalendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(height: 28)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<firstWeekdayOffset, id: \.self) { _ in
                    Color.clear.frame(height: 52)
                }

                ForEach(daysInMonth, id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let daySessions = sessions(for: date)
                    let dayGroups = groupedSessions(for: date)
                    let hasGroup = dayGroups.contains { $0.isGroup }
                    let completedCount = daySessions.filter(\.isCompleted).count

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedDate = date
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(isToday ? Theme.Fonts.headline() : Theme.Fonts.subheadline())
                                .foregroundStyle(
                                    isSelected ? .white :
                                    isToday ? Theme.Colors.softOrange :
                                    Theme.Colors.textPrimary
                                )

                            if !daySessions.isEmpty {
                                HStack(spacing: 2) {
                                    if hasGroup {
                                        // Group indicator dot (lavender)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(isSelected ? .white : Theme.Colors.lavender)
                                            .frame(width: 10, height: 5)
                                    }
                                    ForEach(0..<min(dayGroups.filter({ !$0.isGroup }).count, 2), id: \.self) { i in
                                        Circle()
                                            .fill(
                                                isSelected ? .white :
                                                i < completedCount ? Theme.Colors.mintGreen :
                                                Theme.Colors.softOrange
                                            )
                                            .frame(width: 5, height: 5)
                                    }
                                }
                            } else {
                                Spacer().frame(height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    isSelected ? Theme.Colors.softOrange :
                                    isToday ? Theme.Colors.softOrange.opacity(0.08) :
                                    .clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cuteCard()
    }
}

// MARK: - PT Group Session Card

struct PTGroupSessionCard: View {
    @Environment(DataSyncManager.self) private var syncManager
    let sessions: [TrainingGymSession]

    private var firstSession: TrainingGymSession { sessions.first! }
    private var allCompleted: Bool { sessions.allSatisfy(\.isCompleted) }
    private var anyCheckedIn: Bool { sessions.contains { $0.isCheckedIn } }

    /// Shared package name if all clients have the same package
    private var groupPackageName: String? {
        sharedPackageName(for: sessions)
    }

    private var groupStatusColor: Color {
        if allCompleted { return Theme.Colors.mintGreen }
        if anyCheckedIn { return Theme.Colors.softOrange }
        if firstSession.scheduledDate < Date() { return Theme.Colors.softPink }
        return Theme.Colors.lavender
    }

    private var groupStatusText: String {
        if allCompleted { return "Hoàn thành" }
        let done = sessions.filter(\.isCompleted).count
        if done > 0 { return "\(done)/\(sessions.count) xong" }
        if anyCheckedIn { return "Đang tập" }
        if firstSession.scheduledDate < Date() { return "Quá giờ" }
        return "Sắp tới"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Lavender accent bar for group
            Theme.Colors.lavender
                .frame(height: 4)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.medium, topTrailingRadius: Theme.Radius.medium))

            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Group label with package name
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.lavender)
                            if let name = groupPackageName {
                                Text(name)
                                    .font(Theme.Fonts.headline())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            } else {
                                Text("Lớp nhóm")
                                    .font(Theme.Fonts.headline())
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                            Text("(\(sessions.count) học viên)")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }

                        // Time
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(firstSession.scheduledDate, format: .dateTime.hour().minute()) – \(firstSession.endDate, format: .dateTime.hour().minute())")
                                .font(Theme.Fonts.subheadline())
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)

                        if !Calendar.current.isDateInToday(firstSession.scheduledDate) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(firstSession.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                                    .font(Theme.Fonts.caption())
                            }
                            .foregroundStyle(Theme.Colors.skyBlue)
                        }
                    }

                    Spacer()

                    // Group badge
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text(groupStatusText)
                            .font(Theme.Fonts.caption())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(groupStatusColor.gradient)
                    )
                }

                // Duration
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("\(firstSession.duration) phút")
                        .font(Theme.Fonts.caption())
                }
                .foregroundStyle(Theme.Colors.textSecondary)

                // Client list
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        PTGroupClientRow(session: session, showPackageName: groupPackageName == nil)

                        if session.id != sessions.last?.id {
                            Divider()
                                .padding(.leading, 32)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Colors.lavender.opacity(0.06))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(Theme.Colors.lavender.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Group Client Row (inside group card)

private struct PTGroupClientRow: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var session: TrainingGymSession
    var showPackageName: Bool = false
    @State private var showAbsenceSheet = false

    private var clientPackageName: String? {
        packageName(for: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                // Client avatar
                CuteIconCircle(
                    icon: session.isAbsent ? "person.slash.fill" : "person.fill",
                    color: session.isAbsent ? Theme.Colors.softPink : Theme.Colors.lavender,
                    size: 28
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.client?.name ?? "Học viên")
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(session.isAbsent ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .strikethrough(session.isAbsent)

                    if showPackageName, let pkgName = clientPackageName {
                        HStack(spacing: 3) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 8))
                            Text(pkgName)
                                .font(Theme.Fonts.caption())
                        }
                        .foregroundStyle(Theme.Colors.lavender)
                        .lineLimit(1)
                    }
                }

                Spacer()

                if session.isAbsent {
                    HStack(spacing: 3) {
                        Image(systemName: "person.slash.fill")
                            .font(.system(size: 9))
                        Text("Nghỉ")
                            .font(Theme.Fonts.caption())
                    }
                    .foregroundStyle(Theme.Colors.softPink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Colors.softPink.opacity(0.12)))
                } else if session.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(Theme.Colors.mintGreen)
                } else if session.isCheckedIn {
                    HStack(spacing: 6) {
                        Button {
                            session.isCompleted = true
                            session.checkOutTime = Date()
                            Task { await syncManager.updateSession(session) }
                        } label: {
                            Text("Xong")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Theme.Colors.mintGreen.gradient))
                        }
                        .buttonStyle(.plain)

                        Button { showAbsenceSheet = true } label: {
                            Image(systemName: "person.slash")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.softPink)
                                .padding(6)
                                .background(Circle().fill(Theme.Colors.softPink.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 6) {
                        Button {
                            session.isCheckedIn = true
                            session.checkInTime = Date()
                            Task { await syncManager.updateSession(session) }
                        } label: {
                            Text("Check-in")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Theme.Colors.skyBlue.gradient))
                        }
                        .buttonStyle(.plain)

                        Button { showAbsenceSheet = true } label: {
                            Image(systemName: "person.slash")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.softPink)
                                .padding(6)
                                .background(Circle().fill(Theme.Colors.softPink.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Show absence reason inline
            if session.isAbsent, !session.absenceReason.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 9))
                    Text(session.absenceReason)
                        .font(Theme.Fonts.caption())
                }
                .foregroundStyle(Theme.Colors.softPink)
                .padding(.leading, 38)
                .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .sheet(isPresented: $showAbsenceSheet) {
            AbsenceNoteSheet(session: session)
        }
    }
}

// MARK: - PT Session Card (single session)

struct PTSessionCard: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var session: TrainingGymSession
    @State private var showAbsenceSheet = false

    private var sessionPackageName: String? {
        packageName(for: session)
    }

    private var statusColor: Color {
        if session.isAbsent { return Theme.Colors.softPink }
        if session.isCompleted { return Theme.Colors.mintGreen }
        if session.isCheckedIn { return Theme.Colors.softOrange }
        if session.scheduledDate < Date() { return Theme.Colors.softPink }
        return Theme.Colors.skyBlue
    }

    private var statusText: String {
        if session.isAbsent { return "Nghỉ" }
        if session.isCompleted { return "Hoàn thành" }
        if session.isCheckedIn { return "Đang tập" }
        if session.scheduledDate < Date() { return "Quá giờ" }
        return "Sắp tới"
    }

    private var statusIcon: String {
        if session.isAbsent { return "person.slash.fill" }
        if session.isCompleted { return "checkmark.circle.fill" }
        if session.isCheckedIn { return "figure.run" }
        if session.scheduledDate < Date() { return "clock.badge.exclamationmark" }
        return "clock"
    }

    var body: some View {
        VStack(spacing: 0) {
            statusColor
                .frame(height: 4)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.medium, topTrailingRadius: Theme.Radius.medium))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.skyBlue)
                            Text(session.client?.name ?? "Khách hàng")
                                .font(Theme.Fonts.headline())
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }

                        // Package name
                        if let pkgName = sessionPackageName {
                            HStack(spacing: 4) {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 9))
                                Text(pkgName)
                                    .font(Theme.Fonts.caption())
                            }
                            .foregroundStyle(Theme.Colors.softOrange)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(session.scheduledDate, format: .dateTime.hour().minute()) – \(session.endDate, format: .dateTime.hour().minute())")
                                .font(Theme.Fonts.subheadline())
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)

                        if !Calendar.current.isDateInToday(session.scheduledDate) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(session.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                                    .font(Theme.Fonts.caption())
                            }
                            .foregroundStyle(Theme.Colors.skyBlue)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                        Text(statusText)
                            .font(Theme.Fonts.caption())
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(statusColor.opacity(0.12))
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("\(session.duration) phút")
                        .font(Theme.Fonts.caption())
                }
                .foregroundStyle(Theme.Colors.textSecondary)

                if !session.notes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.caption2)
                        Text(session.notes)
                            .font(Theme.Fonts.caption())
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
                }

                // Absence info display
                if session.isAbsent {
                    absenceInfoView(reason: session.absenceReason, photoURL: session.absencePhotoURL)
                }

                // Check-in / Check-out times for completed sessions
                if session.isCompleted, let checkIn = session.checkInTime {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.skyBlue)
                            Text("Vào: \(checkIn, format: .dateTime.hour().minute())")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        if let checkOut = session.checkOutTime {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.mintGreen)
                                Text("Ra: \(checkOut, format: .dateTime.hour().minute())")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }

                            let duration = checkOut.timeIntervalSince(checkIn)
                            let mins = Int(duration) / 60
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                Text(mins >= 60 ? "\(mins / 60)h\(mins % 60)p" : "\(mins) phút")
                                    .font(Theme.Fonts.caption())
                            }
                            .foregroundStyle(Theme.Colors.mintGreen)
                        }
                    }
                }

                // Action buttons
                if !session.isCompleted && !session.isAbsent {
                    HStack(spacing: 10) {
                        if !session.isCheckedIn {
                            Button {
                                session.isCheckedIn = true
                                session.checkInTime = Date()
                                Task { await syncManager.updateSession(session) }
                            } label: {
                                Label("Check-in", systemImage: "checkmark.shield.fill")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(Theme.Colors.skyBlue.gradient)
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                session.isCompleted = true
                                session.checkOutTime = Date()
                                Task { await syncManager.updateSession(session) }
                            } label: {
                                Label("Hoàn thành", systemImage: "checkmark.circle.fill")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(Theme.Colors.mintGreen.gradient)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        // Absence button
                        Button { showAbsenceSheet = true } label: {
                            Label("Nghỉ", systemImage: "person.slash")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Theme.Colors.softPink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(Theme.Colors.softPink.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)

                        if session.isCheckedIn, let checkIn = session.checkInTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text("Từ \(checkIn, format: .dateTime.hour().minute())")
                                    .font(Theme.Fonts.caption())
                            }
                            .foregroundStyle(Theme.Colors.softOrange)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
        .sheet(isPresented: $showAbsenceSheet) {
            AbsenceNoteSheet(session: session)
        }
    }
}

// MARK: - PT Session Mini Row (single, for upcoming)

struct PTSessionMiniRow: View {
    let session: TrainingGymSession

    private var sessionPackageName: String? {
        packageName(for: session)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(session.scheduledDate, format: .dateTime.day())
                    .font(Theme.Fonts.headline())
                    .foregroundStyle(Theme.Colors.softOrange)
                Text(session.scheduledDate, format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Colors.softOrange.opacity(0.1))
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(session.client?.name ?? "Khách hàng")
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let pkgName = sessionPackageName {
                    HStack(spacing: 3) {
                        Image(systemName: "bag.fill")
                            .font(.system(size: 8))
                        Text(pkgName)
                    }
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.softOrange)
                    .lineLimit(1)
                }
                Text("\(session.scheduledDate, format: .dateTime.hour().minute()) – \(session.endDate, format: .dateTime.hour().minute())")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.mintGreen)
                    .font(.body)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - PT Group Mini Row (group, for upcoming)

private struct PTGroupMiniRow: View {
    let sessions: [TrainingGymSession]

    private var firstSession: TrainingGymSession { sessions.first! }
    private var clientNames: String {
        sessions.compactMap { $0.client?.name }.joined(separator: ", ")
    }
    private var groupPkgName: String? {
        sharedPackageName(for: sessions)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(firstSession.scheduledDate, format: .dateTime.day())
                    .font(Theme.Fonts.headline())
                    .foregroundStyle(Theme.Colors.lavender)
                Text(firstSession.scheduledDate, format: .dateTime.weekday(.abbreviated))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Colors.lavender.opacity(0.1))
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.Colors.lavender)
                    Text(groupPkgName ?? "Lớp nhóm")
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("(\(sessions.count))")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Text(clientNames)
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                Text("\(firstSession.scheduledDate, format: .dateTime.hour().minute()) – \(firstSession.endDate, format: .dateTime.hour().minute())")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            if sessions.allSatisfy(\.isCompleted) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.mintGreen)
                    .font(.body)
            } else {
                let done = sessions.filter(\.isCompleted).count
                if done > 0 {
                    Text("\(done)/\(sessions.count)")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.lavender)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .strokeBorder(Theme.Colors.lavender.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Absence Info View (reusable)

private func absenceInfoView(reason: String, photoURL: String?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
            Image(systemName: "person.slash.fill")
                .font(.caption)
                .foregroundStyle(Theme.Colors.softPink)
            Text("Khách nghỉ tập")
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.softPink)
        }

        if !reason.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "text.quote")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 2)
                Text(reason)
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }

        if let urlStr = photoURL, let url = URL(string: urlStr) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .frame(height: 60)
                    .overlay { ProgressView() }
            }
        }
    }
    .padding(12)
    .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Theme.Colors.softPink.opacity(0.06))
    )
}

// MARK: - Absence Note Sheet

struct AbsenceNoteSheet: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: TrainingGymSession

    @State private var reason = ""
    @State private var capturedPhotoData: Data?
    @State private var showCamera = false
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.slash.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.Colors.softPink)
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(Theme.Colors.softPink.opacity(0.1)))

                        Text("Ghi nhận nghỉ tập")
                            .font(Theme.Fonts.title3())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(session.client?.name ?? "Học viên")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 10)

                    // Session info
                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(session.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                                .font(Theme.Fonts.caption())
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)

                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(session.scheduledDate, format: .dateTime.hour().minute()) – \(session.endDate, format: .dateTime.hour().minute())")
                                .font(Theme.Fonts.caption())
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    // Reason input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lý do nghỉ")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        TextField("VD: Bận công việc, bệnh, đi công tác...", text: $reason, axis: .vertical)
                            .lineLimit(3...6)
                            .cuteTextField()
                    }
                    .padding(.horizontal)

                    // Photo evidence
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ảnh minh chứng (tuỳ chọn)")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if let data = capturedPhotoData, let uiImage = UIImage(data: data) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))

                                Button {
                                    capturedPhotoData = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white, .black.opacity(0.5))
                                }
                                .padding(8)
                            }
                        } else {
                            Button { showCamera = true } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundStyle(Theme.Colors.softPink)
                                    Text("Chụp ảnh")
                                        .font(Theme.Fonts.caption())
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                        .fill(Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                                .foregroundStyle(Color(.systemGray4))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    // Submit
                    Button {
                        isProcessing = true
                        Task {
                            await syncManager.markAbsent(session, reason: reason, photoData: capturedPhotoData)
                            isProcessing = false
                            dismiss()
                        }
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Xác nhận nghỉ tập", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.Colors.softPink))
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Ghi nhận nghỉ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { data in
                    capturedPhotoData = data
                }
                .ignoresSafeArea()
            }
        }
    }
}
