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

    // MARK: - Month Calendar Helpers

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
        return (weekday + 5) % 7 // Monday = 0
    }

    private let weekdaySymbols = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    private var monthSessions: [TrainingGymSession] {
        allSessions.filter {
            calendar.isDate($0.scheduledDate, equalTo: currentMonth, toGranularity: .month)
        }
    }

    private var monthTotalSessions: Int { monthSessions.count }
    private var monthUniqueClients: Int { Set(monthSessions.compactMap { $0.client?.id }).count }
    private var monthTotalHours: Int { monthSessions.reduce(0) { $0 + $1.duration } / 60 }
    private var monthTotalMinutes: Int { monthSessions.reduce(0) { $0 + $1.duration } }

    private func hasSessions(on date: Date) -> Bool {
        allSessions.contains { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    private func sessionDots(for date: Date) -> [Color] {
        let daySessions = sessions(for: date)
        guard !daySessions.isEmpty else { return [] }
        return daySessions.prefix(3).map { session in
            if session.isAbsent { return Theme.Colors.softPink }
            if session.isCompleted { return Theme.Colors.mintGreen }
            if session.isCheckedIn { return Theme.Colors.lavender }
            return Theme.Colors.softOrange
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Mode toggle
                    viewModePicker
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                    if viewMode == .day {
                        dayContent
                    } else {
                        monthContent
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Theme.Colors.screenBackground.ignoresSafeArea())
            .navigationTitle("Lịch tập")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: 8) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewMode == mode ? .white : Theme.Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewMode == mode ? Theme.Colors.mintGreen : Theme.Colors.cardBackground)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Day Content

    private var dayContent: some View {
        VStack(spacing: 20) {
            // Date navigation
            dateNavBar
                .padding(.horizontal, 24)

            // Stats row
            if !selectedDaySessions.isEmpty {
                statsRow
                    .padding(.horizontal, 24)
            }

            // Section header + Sessions
            VStack(alignment: .leading, spacing: 12) {
                Text("BUỔI TẬP HÔM NAY")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(0.5)
                    .padding(.horizontal, 24)

                if selectedDayGroups.isEmpty {
                    emptyDayCard
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(selectedDayGroups) { group in
                            switch group {
                            case .single(let session):
                                PTSessionCard(session: session)
                            case .group(let sessions):
                                PTGroupSessionCard(sessions: sessions)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Upcoming section
            if !upcomingGroups.isEmpty {
                upcomingSection
                    .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Month Content

    private var monthContent: some View {
        VStack(spacing: 16) {
            // Month navigation
            monthNavBar
                .padding(.horizontal, 24)

            // Calendar grid
            monthCalendarGrid
                .padding(.horizontal, 24)

            // Month stats
            monthStatsRow
                .padding(.horizontal, 24)

            // Selected date section
            VStack(alignment: .leading, spacing: 12) {
                // Section header with date + count badge
                HStack {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide)).uppercased() + ", " + selectedDate.formatted(.dateTime.day().month(.wide)).uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tracking(0.5)

                    Spacer()

                    if !selectedDaySessions.isEmpty {
                        Text("\(selectedDaySessions.count) buổi")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.mintGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.Colors.mintGreen.opacity(0.12))
                            )
                    }
                }
                .padding(.horizontal, 24)

                if selectedDayGroups.isEmpty {
                    emptyDayCard
                        .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 10) {
                        ForEach(selectedDayGroups) { group in
                            switch group {
                            case .single(let session):
                                PTSessionCard(session: session)
                            case .group(let sessions):
                                PTGroupSessionCard(sessions: sessions)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    // MARK: - Month Navigation

    private var monthNavBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Text("Tháng " + currentMonth.formatted(.dateTime.month(.defaultDigits)) + ", " + currentMonth.formatted(.dateTime.year()))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Month Calendar Grid

    private var monthCalendarGrid: some View {
        VStack(spacing: 6) {
            // Day headers
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Week rows
            let totalSlots = firstWeekdayOffset + daysInMonth.count
            let weeks = (totalSlots + 6) / 7

            ForEach(0..<weeks, id: \.self) { week in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let slot = week * 7 + dayIndex
                        let dayOffset = slot - firstWeekdayOffset

                        if dayOffset >= 0, dayOffset < daysInMonth.count {
                            let date = daysInMonth[dayOffset]
                            let isToday = calendar.isDateInToday(date)
                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                            let dots = sessionDots(for: date)

                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedDate = date
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.system(size: 14, weight: isToday ? .heavy : .semibold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.textPrimary)

                                    if !dots.isEmpty {
                                        HStack(spacing: 2) {
                                            ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                                                Circle()
                                                    .fill(color)
                                                    .frame(width: 4, height: 4)
                                            }
                                        }
                                    } else {
                                        Spacer().frame(height: 4)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isToday ? Theme.Colors.softOrange.opacity(0.35) : isSelected ? Theme.Colors.mintGreen.opacity(0.12) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.Colors.cardBackground)
        )
    }

    // MARK: - Month Stats Row

    private var monthStatsRow: some View {
        HStack(spacing: 10) {
            monthStatCard(value: "\(monthTotalSessions)", label: "Buổi tháng", color: Theme.Colors.mintGreen)
            monthStatCard(value: "\(monthUniqueClients)", label: "Học viên", color: Theme.Colors.lavender)
            let hours = monthTotalMinutes / 60
            monthStatCard(value: "\(hours)h", label: "Tổng giờ", color: Theme.Colors.softOrange)
        }
    }

    private func monthStatCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Date Navigation

    private var dateNavBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Text(selectedDate.formatted(.dateTime.weekday(.wide)) + ", " + selectedDate.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        let total = selectedDaySessions.count
        let clients = Set(selectedDaySessions.compactMap { $0.client?.id }).count
        let waiting = selectedDaySessions.filter { !$0.isCompleted && !$0.isCheckedIn && !$0.isAbsent }.count

        return HStack(spacing: 10) {
            statCard(icon: "calendar.badge.checkmark", value: "\(total)", label: "Buổi hôm nay", color: Theme.Colors.mintGreen)
            statCard(icon: "person.2.fill", value: "\(clients)", label: "Học viên", color: Theme.Colors.lavender)
            statCard(icon: "timer", value: "\(waiting)", label: "Đang chờ", color: Theme.Colors.softOrange)
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
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
                    // Client photo indicator nhỏ
                    if session.clientCheckInPhotoURL != nil {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Colors.mintGreen)
                            .padding(4)
                            .background(Circle().fill(Theme.Colors.mintGreen.opacity(0.12)))
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

// MARK: - PT Group Session Card (overlapping sessions)

struct PTGroupSessionCard: View {
    let sessions: [TrainingGymSession]

    private var firstSession: TrainingGymSession { sessions.first! }

    private var groupStatusColor: Color {
        if sessions.allSatisfy({ $0.isCompleted }) { return Theme.Colors.mintGreen }
        if sessions.contains(where: { $0.isCheckedIn }) { return Theme.Colors.lavender }
        return Theme.Colors.skyBlue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .center, spacing: 12) {
                // Time block
                VStack(spacing: 2) {
                    Text(firstSession.scheduledDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(firstSession.duration) ph")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(width: 48)

                // Colored divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(groupStatusColor)
                    .frame(width: 2, height: 40)

                // Group info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.Colors.lavender)
                        Text("Nhóm \(sessions.count) học viên")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    Text(sessions.compactMap { $0.client?.name }.joined(separator: ", "))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(14)

            // Individual client rows
            Divider().padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    PTGroupClientRow(session: session, showPackageName: true)
                    if session.id != sessions.last?.id {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

// MARK: - PT Session Card (single session)

struct PTSessionCard: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var session: TrainingGymSession
    @State private var showAbsenceSheet = false
    @State private var showMakeupSheet = false

    private var sessionPackageName: String? {
        packageName(for: session)
    }

    private var hasMakeupSession: Bool {
        syncManager.sessions.contains { $0.isMakeup && $0.originalSessionId == session.id }
    }

    private var statusColor: Color {
        if session.isAbsent { return Theme.Colors.softPink }
        if session.isCompleted { return Theme.Colors.mintGreen }
        if session.isCheckedIn { return Theme.Colors.lavender }
        if session.scheduledDate < Date() { return Theme.Colors.softOrange }
        return Theme.Colors.textSecondary
    }

    private var statusText: String {
        if session.isAbsent { return "Nghỉ" }
        if session.isCompleted { return "Đã xong" }
        if session.isCheckedIn { return "Đang tập" }
        if session.scheduledDate < Date() { return "Sắp tới" }
        return "Chờ xác nhận"
    }

    private var badgeBackground: Color {
        if session.isAbsent { return Theme.Colors.softPink.opacity(0.15) }
        if session.isCompleted { return Theme.Colors.mintGreen.opacity(0.15) }
        if session.isCheckedIn { return Theme.Colors.lavender.opacity(0.15) }
        if session.scheduledDate < Date() { return Theme.Colors.softOrange.opacity(0.15) }
        return .clear
    }

    private var hasBorder: Bool {
        !session.isAbsent && !session.isCompleted && !session.isCheckedIn && session.scheduledDate >= Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main row: time | divider | info | badge
            HStack(alignment: .center, spacing: 12) {
                // Time block
                VStack(spacing: 2) {
                    Text(session.scheduledDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(session.duration) ph")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(width: 48)

                // Colored divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(statusColor)
                    .frame(width: 2, height: 40)

                // Client info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Text("HV: \(session.client?.name ?? "Học viên")")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }

                    if let pkgName = sessionPackageName {
                        HStack(spacing: 4) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 9))
                            Text(pkgName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Theme.Colors.softOrange)
                        .lineLimit(1)
                    }
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    if hasBorder {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                    }
                    Text(statusText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(badgeBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(hasBorder ? Theme.Colors.textSecondary.opacity(0.3) : .clear, lineWidth: 1)
                )
            }

            // Absence info + makeup button
            if session.isAbsent {
                absenceInfoView(reason: session.absenceReason, photoURL: session.absencePhotoURL)

                if hasMakeupSession {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Đã có lịch dạy bù")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Theme.Colors.mintGreen)
                    .padding(.leading, 62)
                } else {
                    Button { showMakeupSheet = true } label: {
                        Label("Tạo lịch dạy bù", systemImage: "arrow.uturn.forward.circle.fill")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.Colors.lavender.gradient))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 62)
                }
            }

            // Makeup badge
            if session.isMakeup {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .font(.system(size: 11))
                    Text("Buổi dạy bù")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.Colors.lavender)
                .padding(.leading, 62)
            }

            // Check-in / Check-out times
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
                    }
                }
                .padding(.leading, 62)
            }

            // Action buttons
            if !session.isCompleted && !session.isAbsent {
                HStack(spacing: 8) {
                    if !session.isCheckedIn {
                        Button {
                            session.isCheckedIn = true
                            session.checkInTime = Date()
                            Task { await syncManager.updateSession(session) }
                        } label: {
                            Label("Check-in", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Theme.Colors.skyBlue.gradient))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            session.isCompleted = true
                            session.checkOutTime = Date()
                            Task { await syncManager.updateSession(session) }
                        } label: {
                            Label("Hoàn thành", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.Colors.mintGreen.gradient))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button { showAbsenceSheet = true } label: {
                        Label("Nghỉ", systemImage: "person.slash")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.softPink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.Colors.softPink.opacity(0.12)))
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
                .padding(.leading, 62)
            }

            // Client self-check-in photo (thông tin thêm, không ảnh hưởng PT)
            if let photoURL = session.clientCheckInPhotoURL, let url = URL(string: photoURL) {
                HStack(spacing: 8) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Học viên đã check-in")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.mintGreen)
                        if let time = session.clientCheckInTime {
                            Text(time, format: .dateTime.hour().minute())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Colors.mintGreen.opacity(0.6))
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.Colors.mintGreen.opacity(0.08))
                )
                .padding(.leading, 62)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .sheet(isPresented: $showAbsenceSheet) {
            AbsenceNoteSheet(session: session)
        }
        .sheet(isPresented: $showMakeupSheet) {
            MakeupSessionSheet(originalSession: session)
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
        HStack(alignment: .center, spacing: 12) {
            // Date block
            VStack(spacing: 2) {
                Text(session.scheduledDate, format: .dateTime.day())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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

            // Divider
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.Colors.softOrange.opacity(0.4))
                .frame(width: 2, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.client?.name ?? "Học viên")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(session.scheduledDate, format: .dateTime.hour().minute()) – \(session.endDate, format: .dateTime.hour().minute())")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    if let pkgName = sessionPackageName {
                        Text("• \(pkgName)")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(Theme.Colors.softOrange)
                            .lineLimit(1)
                    }
                }
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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
        HStack(alignment: .center, spacing: 12) {
            // Date block
            VStack(spacing: 2) {
                Text(firstSession.scheduledDate, format: .dateTime.day())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
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

            // Divider
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.Colors.lavender.opacity(0.4))
                .frame(width: 2, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.Colors.lavender)
                    Text(groupPkgName ?? "Nhóm \(sessions.count) HV")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                HStack(spacing: 6) {
                    Text("\(firstSession.scheduledDate, format: .dateTime.hour().minute()) – \(firstSession.endDate, format: .dateTime.hour().minute())")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("• \(clientNames)")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
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
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.lavender)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Theme.Colors.lavender.opacity(0.12))
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
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

// MARK: - Makeup Session Sheet

struct MakeupSessionSheet: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss
    let originalSession: TrainingGymSession

    @State private var scheduledDate = Date()
    @State private var duration: Int = 60
    @State private var notes = ""
    @State private var isProcessing = false
    @State private var showConflictWarning = false

    private var conflictingSessions: [TrainingGymSession] {
        let makeupEnd = Calendar.current.date(byAdding: .minute, value: duration, to: scheduledDate) ?? scheduledDate
        return syncManager.sessions.filter { s in
            guard s.id != originalSession.id,
                  s.trainer?.id == originalSession.trainer?.id,
                  !s.isAbsent else { return false }
            return scheduledDate < s.endDate && makeupEnd > s.scheduledDate
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.uturn.forward.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.Colors.lavender)
                            .frame(width: 70, height: 70)
                            .background(Circle().fill(Theme.Colors.lavender.opacity(0.1)))

                        Text("Tạo lịch dạy bù")
                            .font(Theme.Fonts.title3())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text(originalSession.client?.name ?? "Học viên")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 10)

                    // Original session info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Buổi gốc đã nghỉ")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        HStack(spacing: 16) {
                            HStack(spacing: 5) {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                Text(originalSession.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                                    .font(Theme.Fonts.caption())
                            }
                            HStack(spacing: 5) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text("\(originalSession.scheduledDate, format: .dateTime.hour().minute()) – \(originalSession.endDate, format: .dateTime.hour().minute())")
                                    .font(Theme.Fonts.caption())
                            }
                        }
                        .foregroundStyle(Theme.Colors.textSecondary)

                        if !originalSession.absenceReason.isEmpty {
                            HStack(spacing: 5) {
                                Image(systemName: "text.quote")
                                    .font(.caption2)
                                Text("Lý do: \(originalSession.absenceReason)")
                                    .font(Theme.Fonts.caption())
                            }
                            .foregroundStyle(Theme.Colors.softPink)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.Colors.softPink.opacity(0.06))
                    )
                    .padding(.horizontal)

                    // Date & time picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ngày giờ dạy bù")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        DatePicker("", selection: $scheduledDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.graphical)
                            .tint(Theme.Colors.lavender)
                    }
                    .padding(.horizontal)

                    // Duration
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Thời lượng (phút)")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Picker("", selection: $duration) {
                            Text("30 phút").tag(30)
                            Text("45 phút").tag(45)
                            Text("60 phút").tag(60)
                            Text("90 phút").tag(90)
                            Text("120 phút").tag(120)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ghi chú (tuỳ chọn)")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textPrimary)

                        TextField("VD: Dạy bù buổi nghỉ ngày...", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .cuteTextField()
                    }
                    .padding(.horizontal)

                    // Conflict warning
                    if !conflictingSessions.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Trùng lịch với \(conflictingSessions.count) buổi khác!")
                                .font(Theme.Fonts.caption())
                        }
                        .foregroundStyle(Theme.Colors.softOrange)
                        .padding(.horizontal)
                    }

                    // Submit
                    Button {
                        if !conflictingSessions.isEmpty {
                            showConflictWarning = true
                        } else {
                            createMakeupSession()
                        }
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Tạo buổi dạy bù", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(CuteButtonStyle(color: Theme.Colors.lavender))
                    .disabled(isProcessing)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Dạy bù")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .alert("Trùng lịch", isPresented: $showConflictWarning) {
                Button("Huỷ", role: .cancel) {}
                Button("Vẫn tạo") { createMakeupSession() }
            } message: {
                Text("Buổi dạy bù trùng với \(conflictingSessions.count) buổi khác. Bạn có muốn tiếp tục?")
            }
        }
    }

    private func createMakeupSession() {
        isProcessing = true
        Task {
            guard let trainer = originalSession.trainer,
                  let client = originalSession.client else {
                isProcessing = false
                return
            }
            let makeup = TrainingGymSession(
                trainer: trainer,
                client: client,
                scheduledDate: scheduledDate,
                duration: duration,
                purchaseID: originalSession.purchaseID
            )
            makeup.isMakeup = true
            makeup.originalSessionId = originalSession.id
            makeup.notes = notes
            await syncManager.createSession(makeup)
            isProcessing = false
            dismiss()
        }
    }
}
