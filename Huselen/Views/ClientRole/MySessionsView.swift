import SwiftUI

struct MySessionsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var sessions: [TrainingGymSession] {
        syncManager.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    @State private var selectedDate = Date()
    @State private var selectedSession: TrainingGymSession?
    @State private var currentMonth = Date()

    private var calendar: Calendar { Calendar.current }

    // Sessions for the selected day
    private func sessions(for date: Date) -> [TrainingGymSession] {
        sessions.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    // Dates in current month that have sessions
    private var datesWithSessions: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(sessions.map { formatter.string(from: $0.scheduledDate) })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar
                calendarHeader
                calendarGrid
                    .padding(.bottom, 4)

                Divider()
                    .padding(.horizontal, 16)

                // Sessions for selected day
                selectedDaySessions
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Lịch tập")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
            .sheet(item: $selectedSession) { session in
                ClientSessionDetailSheet(session: session)
            }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Chưa có lịch tập",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Liên hệ phòng gym để đặt lịch")
                    )
                }
            }
        }
    }

    // MARK: - Calendar Header (Month navigation)

    private var calendarHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let daysOfWeek = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"]
        let days = generateMonthDays()

        return VStack(spacing: 6) {
            // Day-of-week header
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            // Day cells grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let daySessions = sessions(for: date)
        let hasSession = !daySessions.isEmpty
        let completedAll = hasSession && daySessions.allSatisfy(\.isCompleted)
        let hasIncomplete = hasSession && daySessions.contains(where: { !$0.isCompleted })
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(
                        isSelected ? .white :
                        !isCurrentMonth ? Theme.Colors.textSecondary.opacity(0.4) :
                        isToday ? Theme.Colors.mintGreen :
                        Theme.Colors.textPrimary
                    )

                // Session indicator dots
                HStack(spacing: 2) {
                    if completedAll {
                        Circle()
                            .fill(isSelected ? .white.opacity(0.8) : Theme.Colors.mintGreen)
                            .frame(width: 5, height: 5)
                    } else if hasIncomplete {
                        Circle()
                            .fill(isSelected ? .white.opacity(0.8) : Theme.Colors.softOrange)
                            .frame(width: 5, height: 5)
                    } else {
                        Circle()
                            .fill(.clear)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Theme.Colors.mintGreen.gradient : Color.clear.gradient)
                    .shadow(color: isSelected ? Theme.Colors.mintGreen.opacity(0.3) : .clear, radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isToday && !isSelected ? Theme.Colors.mintGreen.opacity(0.5) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Selected Day Sessions

    private var selectedDaySessions: some View {
        let daySessions = sessions(for: selectedDate)

        return Group {
            // Selected date label
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)

                if !daySessions.isEmpty {
                    Text("• \(daySessions.count) buổi")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            if daySessions.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.3))
                    Text("Không có buổi tập")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(daySessions) { session in
                            ClientSessionCard(session: session) {
                                selectedSession = session
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Generate Month Days

    private func generateMonthDays() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: currentMonth)!
        let firstDay = interval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)

        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count

        var days: [Date?] = []

        // Leading blanks (weekday is 1-based, Sunday=1)
        for _ in 0..<(firstWeekday - 1) {
            days.append(nil)
        }

        // Actual days
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstDay) {
                days.append(date)
            }
        }

        return days
    }
}

// MARK: - Client Session Card

private struct ClientSessionCard: View {
    let session: TrainingGymSession
    let onTap: () -> Void

    private var timeText: String {
        let start = session.scheduledDate.formatted(date: .omitted, time: .shortened)
        let end = session.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Color bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(statusColor.gradient)
                    .frame(width: 5)
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 5) {
                    // Time
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(statusColor)
                        Text(timeText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Spacer()

                        statusBadge
                    }

                    // Trainer
                    HStack(spacing: 5) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.softOrange)
                        Text("PT: \(session.trainer?.name ?? "N/A")")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
                .padding(.trailing, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.background)
                    .shadow(color: statusColor.opacity(0.08), radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(statusColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if session.isCompleted { return Theme.Colors.mintGreen }
        if session.isCheckedIn { return Theme.Colors.softOrange }
        return Theme.Colors.skyBlue
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
            Label("Sắp tới", systemImage: "clock")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color(.systemGray5)))
        }
    }
}

// MARK: - Client Session Detail Sheet

private struct ClientSessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: TrainingGymSession

    private var statusColor: Color {
        if session.isCompleted { return Theme.Colors.mintGreen }
        if session.isCheckedIn { return Theme.Colors.softOrange }
        return Theme.Colors.skyBlue
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Colored header
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 12)

                        Text(session.scheduledDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("\(session.scheduledDate.formatted(date: .omitted, time: .shortened)) – \(session.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(session.duration) phút")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        detailStatusBadge
                            .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(statusColor.gradient)

                    VStack(spacing: 16) {
                        // PT info
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.Colors.softOrange)
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(Theme.Colors.softOrange.opacity(0.12)))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Personal Trainer")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                Text(session.trainer?.name ?? "Chưa gán PT")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }

                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.background)
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                        )

                        // Check-in action (if not completed)
                        if !session.isCompleted && session.isCheckedIn {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(Theme.Colors.mintGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Đã check-in")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    if let checkInTime = session.checkInTime {
                                        Text("lúc \(checkInTime.formatted(date: .omitted, time: .shortened))")
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.Colors.mintGreen.opacity(0.08))
                            )
                        }

                        // Notes
                        if !session.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 5) {
                                    Image(systemName: "note.text")
                                        .foregroundStyle(Theme.Colors.lavender)
                                    Text("Ghi chú")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                Text(session.notes)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.background)
                                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
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

    @ViewBuilder
    private var detailStatusBadge: some View {
        HStack(spacing: 6) {
            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                Text("Hoàn thành")
            } else if session.isCheckedIn {
                Image(systemName: "figure.run")
                Text("Đang tập")
            } else {
                Image(systemName: "clock.fill")
                Text("Chờ check-in")
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.22)))
    }
}
