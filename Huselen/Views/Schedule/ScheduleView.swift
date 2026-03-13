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

    enum ViewMode: String, CaseIterable {
        case day = "Ngày"
        case week = "Tuần"
    }

    private var calendar: Calendar { Calendar.current }

    private var weekDates: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func sessions(for date: Date) -> [TrainingGymSession] {
        allSessions.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
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
                    onDelete: {
                        selectedSession = nil
                        sessionToDelete = session
                        showDeleteConfirm = true
                    }
                )
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

            // Week day selector (day mode)
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
        }
    }

    private func moveDate(by value: Int) {
        switch viewMode {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: value, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDate) ?? selectedDate
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
                daySessionList(daySessions)
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

    private func daySessionList(_ daySessions: [TrainingGymSession]) -> some View {
        let groups = groupedSessions(for: selectedDate)
        return ScrollView {
            LazyVStack(spacing: 10) {
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
        if session.isCompleted {
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

                        // Action buttons
                        if !session.isCompleted {
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
        if session.isCompleted {
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

