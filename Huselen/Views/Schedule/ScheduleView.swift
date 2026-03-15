import SwiftUI

// MARK: - Color palette for trainers

private let trainerColors: [Color] = [
    Theme.Colors.softOrange,
    Theme.Colors.skyBlue,
    Theme.Colors.mintGreen,
    Theme.Colors.lavender,
    Theme.Colors.softPink,
    Theme.Colors.peach,
    Theme.Colors.warmYellow,
]

private func colorForTrainer(_ trainer: Trainer?, allTrainers: [Trainer]) -> Color {
    guard let trainer else { return .gray }
    if let idx = allTrainers.firstIndex(where: { $0.id == trainer.id }) {
        return trainerColors[idx % trainerColors.count]
    }
    return trainerColors[0]
}

// MARK: - ScheduleView

struct ScheduleView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var allSessions: [TrainingGymSession] {
        syncManager.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    private var allTrainers: [Trainer] {
        syncManager.trainers.sorted { $0.name < $1.name }
    }
    @State private var selectedDate = Date()
    @State private var showingAddSession = false
    @State private var viewMode: ViewMode = .day
    @State private var selectedSession: TrainingGymSession?
    @State private var showDeleteConfirm = false
    @State private var sessionToDelete: TrainingGymSession?
    @State private var sessionToEdit: TrainingGymSession?
    @State private var selectedTrainerId: UUID?
    @State private var currentMonth = Date()

    enum ViewMode: String, CaseIterable {
        case day = "Ngày"
        case week = "Tuần"
        case month = "Tháng"
    }

    private var calendar: Calendar { Calendar.current }

    // MARK: - Filtered sessions

    private var filteredSessions: [TrainingGymSession] {
        if let trainerId = selectedTrainerId {
            return allSessions.filter { $0.trainer?.id == trainerId }
        }
        return allSessions
    }

    // MARK: - Month Calendar Helpers

    private let weekdaySymbols = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

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

    private var monthSessions: [TrainingGymSession] {
        filteredSessions.filter {
            calendar.isDate($0.scheduledDate, equalTo: currentMonth, toGranularity: .month)
        }
    }

    private func sessionDots(for date: Date) -> [Color] {
        let daySessions = filteredSessions.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
        guard !daySessions.isEmpty else { return [] }
        return daySessions.prefix(3).map { session in
            if session.isAbsent { return Theme.Colors.softPink }
            if session.isCompleted { return Theme.Colors.mintGreen }
            if session.isCheckedIn { return Theme.Colors.softOrange }
            return colorForTrainer(session.trainer, allTrainers: allTrainers)
        }
    }

    private var weekDates: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func sessions(for date: Date) -> [TrainingGymSession] {
        filteredSessions.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Groups sessions by trainer + overlapping time. Returns either `.single` or `.group`.
    private func groupedSessions(for date: Date) -> [SessionGroup] {
        let daySessions = sessions(for: date)
        var used = Set<UUID>()
        var groups: [SessionGroup] = []

        for session in daySessions {
            guard !used.contains(session.id) else { continue }
            guard let trainer = session.trainer else {
                used.insert(session.id)
                groups.append(.single(session))
                continue
            }

            // Find all sessions with the same trainer that overlap with this session's time
            var cluster = [session]
            for other in daySessions where !used.contains(other.id) {
                guard other.id != session.id,
                      other.trainer?.id == trainer.id,
                      session.conflicts(with: other) else { continue }
                cluster.append(other)
            }

            for s in cluster { used.insert(s.id) }

            if cluster.count >= 2 {
                groups.append(.group(trainer: trainer, sessions: cluster.sorted { $0.scheduledDate < $1.scheduledDate }))
            } else {
                groups.append(.single(session))
            }
        }

        return groups
    }

    /// Count groups as 1 session each
    private func groupCount(for date: Date) -> Int {
        groupedSessions(for: date).count
    }

    private func completedGroupCount(for date: Date) -> Int {
        groupedSessions(for: date).filter { group in
            switch group {
            case .single(let s): return s.isCompleted
            case .group(_, let sessions): return sessions.allSatisfy(\.isCompleted)
            }
        }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBar

                switch viewMode {
                case .day:
                    dayView
                case .week:
                    weekView
                case .month:
                    monthView
                }
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Lịch tập")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedDate = Date()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Theme.Colors.warmYellow)
                                .frame(width: 7, height: 7)
                            Text("Hôm nay")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.Colors.warmYellow.opacity(0.15))
                        .foregroundStyle(Theme.Colors.warmYellow)
                        .clipShape(Capsule())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddSession = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Theme.Colors.warmYellow)
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                SessionFormView(preselectedDate: selectedDate)
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailSheet(
                    session: session,
                    allTrainers: allTrainers,
                    onEdit: {
                        selectedSession = nil
                        sessionToEdit = session
                    },
                    onDelete: {
                        selectedSession = nil
                        sessionToDelete = session
                        showDeleteConfirm = true
                    }
                )
            }
            .sheet(item: $sessionToEdit) { session in
                SessionFormView(editingSession: session)
            }
            .confirmationDialog("Xoá buổi tập này?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Xoá", role: .destructive) {
                    if let session = sessionToDelete {
                        Task { await syncManager.deleteSession(session) }
                    }
                    sessionToDelete = nil
                }
            } message: {
                Text("Bạn không thể hoàn tác hành động này.")
            }
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 0) {
            // View mode toggle
            HStack(spacing: 0) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(viewMode == mode ? .white : Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(viewMode == mode ? Theme.Colors.warmYellow : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Navigation arrows + date
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { moveDate(by: -1) }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(headerTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    if viewMode == .day {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { moveDate(by: 1) }
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Week day selector (day mode only)
            if viewMode == .day {
                weekDayStrip
                    .padding(.top, 8)
            }

            // Summary bar
            if viewMode == .day {
                let total = groupCount(for: selectedDate)
                let completed = completedGroupCount(for: selectedDate)
                if total > 0 {
                    HStack(spacing: 16) {
                        Label("\(total) buổi", systemImage: "calendar")
                        Label("\(completed) xong", systemImage: "checkmark.circle")
                            .foregroundStyle(Theme.Colors.mintGreen)
                        Label("\(total - completed) còn lại", systemImage: "clock")
                            .foregroundStyle(Theme.Colors.softOrange)
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6).opacity(0.5))
                }
            }

            // Trainer filter pills
            if allTrainers.count > 1 {
                trainerFilterPills
            }
        }
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
    }

    private var headerTitle: String {
        switch viewMode {
        case .day:
            return selectedDate.formatted(.dateTime.day().month(.wide))
        case .week:
            let start = weekDates.first ?? selectedDate
            let end = weekDates.last ?? selectedDate
            if calendar.component(.month, from: start) == calendar.component(.month, from: end) {
                return "\(start.formatted(.dateTime.day())) - \(end.formatted(.dateTime.day().month(.wide)))"
            }
            return "\(start.formatted(.dateTime.day().month(.abbreviated))) - \(end.formatted(.dateTime.day().month(.abbreviated)))"
        case .month:
            return "Tháng " + currentMonth.formatted(.dateTime.month(.defaultDigits)) + ", " + currentMonth.formatted(.dateTime.year())
        }
    }

    private func moveDate(by value: Int) {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDate) ?? selectedDate
        case .month:
            currentMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) ?? currentMonth
        }
    }

    private var weekDayStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(date)
                let dayCount = groupCount(for: date)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 5) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(isSelected ? .white.opacity(0.8) : Theme.Colors.textSecondary)

                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 16, weight: isSelected ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : isToday ? Theme.Colors.warmYellow : Theme.Colors.textPrimary)

                        // Session count dots
                        HStack(spacing: 2) {
                            ForEach(0..<min(dayCount, 3), id: \.self) { _ in
                                Circle()
                                    .fill(isSelected ? .white.opacity(0.7) : Theme.Colors.softOrange)
                                    .frame(width: 4, height: 4)
                            }
                            if dayCount > 3 {
                                Text("+")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected ? .white.opacity(0.7) : Theme.Colors.softOrange)
                            }
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Theme.Colors.warmYellow.gradient : Color.clear.gradient)
                            .shadow(color: isSelected ? Theme.Colors.warmYellow.opacity(0.3) : .clear, radius: 6, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(isToday && !isSelected ? Theme.Colors.warmYellow.opacity(0.4) : .clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Day View

    private var dayView: some View {
        let daySessions = sessions(for: selectedDate)

        return Group {
            if daySessions.isEmpty {
                emptyDayView
            } else {
                ScrollView {
                    daySessionList(daySessions)
                }
            }
        }
    }

    private var emptyDayView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "figure.cooldown")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.4))
            Text("Không có buổi tập")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Nhấn + để thêm lịch tập mới")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trainer Filter Pills

    private var trainerFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" pill
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTrainerId = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 10))
                        Text("Tất cả")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selectedTrainerId == nil ? .white : Theme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(selectedTrainerId == nil ? Theme.Colors.warmYellow.gradient : Color(.systemGray6).gradient)
                    )
                }
                .buttonStyle(.plain)

                ForEach(allTrainers) { trainer in
                    let color = colorForTrainer(trainer, allTrainers: allTrainers)
                    let isSelected = selectedTrainerId == trainer.id
                    let trainerSessionCount = allSessions.filter { $0.trainer?.id == trainer.id }.count

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTrainerId = isSelected ? nil : trainer.id
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isSelected ? .white : color)
                                .frame(width: 7, height: 7)
                            Text(trainer.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            Text("\(trainerSessionCount)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? .white.opacity(0.3) : color.opacity(0.15))
                                )
                        }
                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(isSelected ? color.gradient : Color(.systemGray6).gradient)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Month View

    private var monthView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month calendar grid
                monthCalendarGrid
                    .padding(.horizontal, 16)

                // Month stats
                monthStatsRow
                    .padding(.horizontal, 16)

                // Selected day sessions
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)).uppercased() + ", " + selectedDate.formatted(.dateTime.day().month(.wide)).uppercased())
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .tracking(0.5)

                        Spacer()

                        let dayCount = groupCount(for: selectedDate)
                        if dayCount > 0 {
                            Text("\(dayCount) buổi")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.warmYellow)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.Colors.warmYellow.opacity(0.12))
                                )
                        }
                    }
                    .padding(.horizontal, 16)

                    let daySessions = sessions(for: selectedDate)
                    if daySessions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                            Text("Không có buổi tập")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 16)
                    } else {
                        daySessionList(daySessions)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
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
                                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)

                                    if !dots.isEmpty {
                                        HStack(spacing: 2) {
                                            ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                                                Circle()
                                                    .fill(isSelected ? .white.opacity(0.8) : color)
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
                                        .fill(isSelected ? Theme.Colors.warmYellow : isToday ? Theme.Colors.warmYellow.opacity(0.15) : .clear)
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
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - Month Stats Row

    private var monthStatsRow: some View {
        let totalSessions = monthSessions.count
        let completedSessions = monthSessions.filter { $0.isCompleted }.count
        let absentSessions = monthSessions.filter { $0.isAbsent }.count
        let uniqueClients = Set(monthSessions.compactMap { $0.client?.id }).count
        let totalMinutes = monthSessions.reduce(0) { $0 + $1.duration }
        let totalHours = totalMinutes / 60

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                monthStatCard(value: "\(totalSessions)", label: "Tổng buổi", color: Theme.Colors.warmYellow)
                monthStatCard(value: "\(completedSessions)", label: "Hoàn thành", color: Theme.Colors.mintGreen)
                monthStatCard(value: "\(absentSessions)", label: "Nghỉ", color: Theme.Colors.softPink)
            }
            HStack(spacing: 8) {
                monthStatCard(value: "\(uniqueClients)", label: "Học viên", color: Theme.Colors.lavender)
                monthStatCard(value: "\(totalHours)h", label: "Tổng giờ", color: Theme.Colors.softOrange)
                if selectedTrainerId == nil {
                    let activeTrainers = Set(monthSessions.compactMap { $0.trainer?.id }).count
                    monthStatCard(value: "\(activeTrainers)", label: "PT hoạt động", color: Theme.Colors.skyBlue)
                } else {
                    let remaining = totalSessions - completedSessions - absentSessions
                    monthStatCard(value: "\(remaining)", label: "Còn lại", color: Theme.Colors.skyBlue)
                }
            }
        }
    }

    private func monthStatCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }

    private func daySessionList(_ daySessions: [TrainingGymSession]) -> some View {
        let groups = groupedSessions(for: selectedDate)
        return LazyVStack(spacing: 10) {
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                switch group {
                case .single(let session):
                    SessionCard(
                        session: session,
                        color: colorForTrainer(session.trainer, allTrainers: allTrainers),
                        onTap: { selectedSession = session }
                    )
                case .group(let trainer, let sessions):
                    GroupSessionDayCard(
                        trainer: trainer,
                        sessions: sessions,
                        color: colorForTrainer(trainer, allTrainers: allTrainers),
                        onTapSession: { selectedSession = $0 }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Week View

    private var weekView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let isToday = calendar.isDateInToday(date)
                    let daySessions = sessions(for: date)

                    VStack(alignment: .leading, spacing: 8) {
                        // Day header row
                        HStack(spacing: 10) {
                            VStack(spacing: 2) {
                                Text(date.formatted(.dateTime.weekday(.short)).uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isToday ? .white : Theme.Colors.textSecondary)
                                Text(date.formatted(.dateTime.day()))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(isToday ? .white : Theme.Colors.textPrimary)
                            }
                            .frame(width: 44, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isToday ? Theme.Colors.warmYellow.gradient : Color(.systemGray6).gradient)
                            )

                            if daySessions.isEmpty {
                                Text("Không có buổi tập")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
                            } else {
                                let count = groupCount(for: date)
                                Text("\(count) buổi")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color(.systemGray5)))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        // Session cards for the day
                        if !daySessions.isEmpty {
                            let groups = groupedSessions(for: date)
                            VStack(spacing: 6) {
                                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                                    switch group {
                                    case .single(let session):
                                        WeekSessionCard(
                                            session: session,
                                            color: colorForTrainer(session.trainer, allTrainers: allTrainers),
                                            onTap: { selectedSession = session }
                                        )
                                    case .group(let trainer, let sessions):
                                        WeekGroupCard(
                                            trainer: trainer,
                                            sessions: sessions,
                                            color: colorForTrainer(trainer, allTrainers: allTrainers),
                                            onTapSession: { selectedSession = $0 }
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)

                    if date != weekDates.last {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Session Group Model

private enum SessionGroup {
    case single(TrainingGymSession)
    case group(trainer: Trainer, sessions: [TrainingGymSession])
}

// MARK: - Group Session Card (Day View)

private struct GroupSessionDayCard: View {
    let trainer: Trainer
    let sessions: [TrainingGymSession]
    let color: Color
    let onTapSession: (TrainingGymSession) -> Void

    private var timeText: String {
        guard let first = sessions.first else { return "" }
        let start = first.scheduledDate.formatted(date: .omitted, time: .shortened)
        let end = first.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.gradient)
                    .frame(width: 5)
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(color)
                        Text(timeText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Spacer()

                        Label("Nhóm \(sessions.count)", systemImage: "person.2.fill")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(color.gradient))
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 10))
                            .foregroundStyle(color)
                        Text(trainer.name)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
                .padding(.trailing, 14)
            }

            // Client rows
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    Button { onTapSession(session) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.mintGreen)
                            Text(session.client?.name ?? "KH")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if session.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.mintGreen)
                            } else if session.isCheckedIn {
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.softOrange)
                            } else {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    if session.id != sessions.last?.id {
                        Divider().padding(.leading, 18)
                    }
                }
            }
            .background(color.opacity(0.04))
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(color.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Week Group Card

private struct WeekGroupCard: View {
    let trainer: Trainer
    let sessions: [TrainingGymSession]
    let color: Color
    let onTapSession: (TrainingGymSession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.gradient)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 10) {
                    // Time
                    VStack(spacing: 2) {
                        Text(sessions.first?.scheduledDate.formatted(date: .omitted, time: .shortened) ?? "")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        Text("\(sessions.first?.duration ?? 60)p")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(width: 52)

                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 0.5, height: 28)

                    // Trainer + group badge
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 9))
                                .foregroundStyle(color)
                            Text(trainer.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(color)
                            Text("Nhóm \(sessions.count) người")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(color)
                        }
                    }

                    Spacer()
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 8)
            }

            // Client mini-rows
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    Button { onTapSession(session) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.Colors.mintGreen)
                            Text(session.client?.name ?? "KH")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if session.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.Colors.mintGreen)
                            } else if session.isCheckedIn {
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.Colors.softOrange)
                            } else {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    if session.id != sessions.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(color.opacity(0.04))
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.background)
                .shadow(color: color.opacity(0.08), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Session Card (Day View)

private struct SessionCard: View {
    let session: TrainingGymSession
    let color: Color
    let onTap: () -> Void

    private var timeText: String {
        let start = session.scheduledDate.formatted(date: .omitted, time: .shortened)
        let end = session.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private var packageName: String {
        guard let purchaseID = session.purchaseID,
              let client = session.client else { return "" }
        let purchase = client.purchases.first { $0.purchaseID == purchaseID }
        return purchase?.package?.name ?? ""
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Color accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.gradient)
                    .frame(width: 5)
                    .padding(.vertical, 6)

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Time row
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(color)
                        Text(timeText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Spacer()

                        statusBadge
                    }

                    // People row
                    HStack(spacing: 12) {
                        HStack(spacing: 5) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 10))
                                .foregroundStyle(color)
                            Text(session.trainer?.name ?? "PT")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 5) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.Colors.mintGreen)
                            Text(session.client?.name ?? "KH")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Package row
                    if !packageName.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(color.opacity(0.7))
                            Text(packageName)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(color)
                                .lineLimit(1)
                        }
                    }

                    // Absent reason
                    if session.isAbsent && !session.absenceReason.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.softPink)
                            Text(session.absenceReason)
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(Theme.Colors.softPink)
                                .lineLimit(1)
                        }
                    }

                    // Makeup badge
                    if session.isMakeup {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.uturn.forward.circle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.lavender)
                            Text("Buổi dạy bù")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.lavender)
                        }
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 12)
                .padding(.trailing, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background)
                    .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if session.isAbsent {
            Label("Nghỉ", systemImage: "person.slash.fill")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Colors.softPink.gradient))
        } else if session.isMakeup {
            Label("Dạy bù", systemImage: "arrow.uturn.forward.circle.fill")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Colors.lavender.gradient))
        } else if session.isCompleted {
            Label("Xong", systemImage: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Colors.mintGreen.gradient))
        } else if session.isCheckedIn {
            Label("Đang tập", systemImage: "figure.run")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Theme.Colors.softOrange.gradient))
        } else {
            Label("Chờ", systemImage: "clock")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(.systemGray5)))
        }
    }
}

// MARK: - Week Session Card

private struct WeekSessionCard: View {
    let session: TrainingGymSession
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Color accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.gradient)
                    .frame(width: 4)
                    .padding(.vertical, 6)

                HStack(spacing: 10) {
                    // Time
                    VStack(spacing: 2) {
                        Text(session.scheduledDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                        Text("\(session.duration)p")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(width: 52)

                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 0.5, height: 28)

                    // People
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 9))
                                .foregroundStyle(color)
                            Text(session.trainer?.name ?? "PT")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.Colors.mintGreen)
                            Text(session.client?.name ?? "KH")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Status indicator
                    if session.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.mintGreen)
                    } else if session.isCheckedIn {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.Colors.softOrange)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.background)
                    .shadow(color: color.opacity(0.08), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(color.opacity(0.12), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Detail Sheet

private struct SessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var session: TrainingGymSession
    let allTrainers: [Trainer]
    var onEdit: () -> Void
    var onDelete: () -> Void

    private var color: Color {
        colorForTrainer(session.trainer, allTrainers: allTrainers)
    }

    private var purchaseInfo: PackagePurchase? {
        guard let purchaseID = session.purchaseID, let client = session.client else { return nil }
        return client.purchases.first { $0.purchaseID == purchaseID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Top colored header
                    VStack(spacing: 12) {
                        // Pill handle
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 12)

                        // Date
                        Text(session.scheduledDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))

                        // Time
                        Text("\(session.scheduledDate.formatted(date: .omitted, time: .shortened)) – \(session.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        // Duration
                        Text("\(session.duration) phút")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        // Status
                        statusBadge
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 0)
                            .fill(color.gradient)
                    )

                    VStack(spacing: 16) {
                        // PT + Client info
                        HStack(spacing: 12) {
                            infoCard(
                                icon: "figure.strengthtraining.traditional",
                                iconColor: color,
                                label: "Personal Trainer",
                                value: session.trainer?.name ?? "Chưa gán"
                            )
                            infoCard(
                                icon: "person.fill",
                                iconColor: Theme.Colors.mintGreen,
                                label: "Khách hàng",
                                value: session.client?.name ?? "Chưa gán"
                            )
                        }

                        // Package info
                        if let purchase = purchaseInfo {
                            VStack(spacing: 10) {
                                HStack {
                                    Image(systemName: "ticket.fill")
                                        .foregroundStyle(color)
                                    Text(purchase.package?.name ?? "Gói PT")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    Spacer()
                                }

                                HStack(spacing: 16) {
                                    miniStat(value: "\(purchase.usedSessions)", label: "Đã dùng", color: Theme.Colors.softOrange)
                                    miniStat(value: "\(purchase.remainingSessions)", label: "Còn lại", color: Theme.Colors.mintGreen)
                                    miniStat(value: "\(purchase.totalSessions)", label: "Tổng", color: Theme.Colors.skyBlue)
                                }

                                // Progress bar
                                GeometryReader { geo in
                                    let progress = purchase.totalSessions > 0
                                        ? CGFloat(purchase.usedSessions) / CGFloat(purchase.totalSessions)
                                        : 0
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color.gradient)
                                            .frame(width: geo.size.width * min(progress, 1.0))
                                    }
                                }
                                .frame(height: 6)

                                if purchase.isExpired {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(Theme.Colors.softPink)
                                        Text("Gói đã hết hạn")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.Colors.softPink)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.background)
                                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                            )
                        }

                        // Absent info
                        if session.isAbsent {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.slash.fill")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.softPink)
                                    Text("Khách nghỉ tập")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.softPink)
                                }
                                if !session.absenceReason.isEmpty {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "text.quote")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                            .padding(.top, 2)
                                        Text(session.absenceReason)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                }
                                if let urlStr = session.absencePhotoURL, let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFill()
                                            .frame(maxWidth: .infinity).frame(height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.systemGray6)).frame(height: 60)
                                            .overlay { ProgressView() }
                                    }
                                }
                                // Show linked makeup session if exists
                                if let makeupSession = syncManager.sessions.first(where: { $0.isMakeup && $0.originalSessionId == session.id }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.uturn.forward.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.lavender)
                                        Text("Dạy bù: \(makeupSession.scheduledDate.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.Colors.lavender)
                                    }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.Colors.softPink.opacity(0.06))
                            )
                        }

                        // Makeup info
                        if session.isMakeup {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.uturn.forward.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Colors.lavender)
                                    Text("Buổi dạy bù")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.Colors.lavender)
                                }
                                if let originalSession = syncManager.sessions.first(where: { $0.id == session.originalSessionId }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .font(.caption2)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                        Text("Bù cho buổi: \(originalSession.scheduledDate.formatted(.dateTime.weekday(.abbreviated).day().month()))")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.Colors.lavender.opacity(0.06))
                            )
                        }

                        // Action buttons
                        if !session.isCompleted && !session.isAbsent {
                            VStack(spacing: 10) {
                                if !session.isCheckedIn {
                                    Button {
                                        withAnimation(.spring(response: 0.35)) {
                                            session.isCheckedIn = true
                                            session.checkInTime = Date()
                                        }
                                        Task { await syncManager.updateSession(session) }
                                    } label: {
                                        Label("Check-in ngay", systemImage: "checkmark.shield.fill")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Theme.Colors.skyBlue.gradient)
                                                    .shadow(color: Theme.Colors.skyBlue.opacity(0.3), radius: 8, y: 4)
                                            )
                                    }
                                } else {
                                    Button {
                                        withAnimation(.spring(response: 0.35)) {
                                            session.isCompleted = true
                                            session.checkOutTime = Date()
                                        }
                                        Task { await syncManager.updateSession(session) }
                                    } label: {
                                        Label("Hoàn thành buổi tập", systemImage: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(Theme.Colors.mintGreen.gradient)
                                                    .shadow(color: Theme.Colors.mintGreen.opacity(0.3), radius: 8, y: 4)
                                            )
                                    }
                                }
                            }
                        }

                        // Edit button
                        if !session.isCompleted {
                            Button {
                                onEdit()
                            } label: {
                                Label("Chỉnh sửa lịch tập", systemImage: "pencil")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Theme.Colors.lavender.gradient)
                                            .shadow(color: Theme.Colors.lavender.opacity(0.3), radius: 8, y: 4)
                                    )
                            }
                        }

                        // Delete button
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Xoá buổi tập", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.Colors.softPink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.Colors.softPink.opacity(0.1))
                                )
                        }
                    }
                    .padding(16)
                }
            }
            .background(Theme.Colors.screenBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private func infoCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 42, height: 42)
                .background(
                    Circle().fill(iconColor.opacity(0.12))
                )
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
    }

    private func miniStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if session.isAbsent {
            HStack(spacing: 6) {
                Image(systemName: "person.slash.fill")
                Text("Nghỉ tập")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.25)))
        } else if session.isMakeup {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.forward.circle.fill")
                Text("Dạy bù")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.25)))
        } else if session.isCompleted {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("Hoàn thành")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.25)))
        } else if session.isCheckedIn {
            HStack(spacing: 6) {
                Image(systemName: "figure.run")
                Text("Đang tập")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.25)))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                Text("Chờ check-in")
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.2)))
        }
    }
}

