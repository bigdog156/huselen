import SwiftUI


struct MySessionsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedSession: TrainingGymSession?

    private let cal = Calendar.current

    // MARK: - Data

    private var allSessions: [TrainingGymSession] {
        syncManager.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func sessions(for date: Date) -> [TrainingGymSession] {
        allSessions.filter { cal.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    private var selectedDaySessions: [TrainingGymSession] {
        sessions(for: selectedDate)
    }

    private var sessionsThisMonth: Int {
        allSessions.filter {
            cal.isDate($0.scheduledDate, equalTo: currentMonth, toGranularity: .month)
        }.count
    }

    private var streakDays: Int {
        StreakCalculator.trainingStreak(from: allSessions)
    }

    private var monthLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: currentMonth).capitalized
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                calendarSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                if streakDays > 0 {
                    streakBanner
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }

                sessionListSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .background(Theme.Colors.screenBackground)
        .refreshable { await syncManager.refresh() }
        .sheet(item: $selectedSession) { session in
            ClientSessionDetailSheet(session: session)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ClientHeaderView(subtitle: monthLabel, title: "Lịch tập")
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = cal.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fitTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.fitCard))
                }

                Spacer()

                Text(monthLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = cal.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.fitTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.fitCard))
                }
            }
            .padding(.horizontal, 8)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["CN", "T2", "T3", "T4", "T5", "T6", "T7"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.fitTextTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(generateMonthDays(), id: \.self) { date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday    = cal.isDateInToday(date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let isCurrentM = cal.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let daySess    = sessions(for: date)
        let hasSession = !daySess.isEmpty
        let photoURL   = daySess.compactMap { $0.clientCheckInPhotoURL }.first.flatMap { URL(string: $0) }
        let hasPhoto   = photoURL != nil

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedDate = date
            }
        } label: {
            ZStack {
                // Photo background
                if let url = photoURL {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .clipShape(Circle())
                        } else {
                            Circle().fill(Color.fitIndigo.opacity(0.15))
                        }
                    }
                    .overlay(Color.black.opacity(isSelected ? 0.15 : 0.3).clipShape(Circle()))
                } else if isToday || isSelected {
                    Circle().fill(Color.fitGreen)
                } else if hasSession {
                    Circle().fill(Color.fitGreen.opacity(0.1))
                }

                // Selection ring
                if isSelected {
                    Circle()
                        .strokeBorder(hasPhoto ? .white : Color.fitGreen, lineWidth: 2.5)
                }

                // Day number
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 13, weight: isToday || isSelected || hasPhoto ? .bold : .medium))
                    .foregroundStyle(
                        hasPhoto ? .white :
                        isToday || isSelected ? .white :
                        hasSession ? Color.fitGreen :
                        !isCurrentM ? Color.fitTextTertiary.opacity(0.4) :
                        Color.fitTextPrimary
                    )
                    .shadow(color: hasPhoto ? .black.opacity(0.5) : .clear, radius: 1, y: 1)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: 8) {
            Text("🔥")
                .font(.system(size: 16))
            Text("Streak: \(streakDays) ngày liên tiếp")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.fitOrange)
            Spacer()
            Text("🌟")
                .font(.system(size: 16))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Colors.warmYellow.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.Colors.warmYellow.opacity(0.6), lineWidth: 1)
                )
        )
    }

    // MARK: - Session List

    private var sessionListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack(spacing: 6) {
                Text(selectedDate, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                if !selectedDaySessions.isEmpty {
                    Text("· \(selectedDaySessions.count) buổi")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }
            }

            if selectedDaySessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.fitTextTertiary)
                        Text("Không có buổi tập")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.fitCard))
            } else {
                ForEach(selectedDaySessions) { session in
                    sessionCard(session)
                }
            }

            // Monthly total
            HStack {
                Text("Tổng buổi tháng này: ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
                Text("\(sessionsThisMonth)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.fitGreen)
            }
            .padding(.top, 4)
        }
    }

    private func sessionCard(_ session: TrainingGymSession) -> some View {
        let start = session.scheduledDate.formatted(date: .omitted, time: .shortened)
        let end   = session.endDate.formatted(date: .omitted, time: .shortened)
        let accentColor = session.isCompleted ? Color.fitGreen : (session.isCheckedIn ? Color.orange : (session.clientCheckInPhotoURL != nil ? Color.fitIndigo : Color.fitGreen))

        return Button { selectedSession = session } label: {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("\(start) – \(end)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.fitTextPrimary)
                            Spacer()
                            sessionBadge(session)
                        }
                        HStack(spacing: 6) {
                            Text("PT: \(session.trainer?.name ?? "N/A")")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.fitTextSecondary)

                            if session.clientCheckInTime != nil {
                                HStack(spacing: 3) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 9))
                                    Text(session.clientCheckInTime!, format: .dateTime.hour().minute())
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(Color.fitIndigo)
                            }
                        }
                    }

                    // Check-in photo thumbnail
                    if let urlStr = session.clientCheckInPhotoURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Color.fitCard
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.fitTextTertiary.opacity(0.5))
                                    )
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.fitCard)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sessionBadge(_ session: TrainingGymSession) -> some View {
        if session.isCompleted {
            Text("Hoàn thành")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.fitGreen))
        } else if session.isCheckedIn {
            Text("Đang tập")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.orange))
        } else if session.clientCheckInPhotoURL != nil {
            Text("Đã gửi ảnh")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.fitIndigo))
        } else {
            Text("Sắp tới")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.fitCard.opacity(1.5)))
                .overlay(Capsule().strokeBorder(Color.fitTextTertiary.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Generate month days

    private func generateMonthDays() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: currentMonth) else { return [] }
        let first = interval.start
        let firstWeekday = cal.component(.weekday, from: first)
        let daysInMonth  = cal.range(of: .day, in: .month, for: currentMonth)?.count ?? 30

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for i in 0..<daysInMonth {
            days.append(cal.date(byAdding: .day, value: i, to: first))
        }
        return days
    }
}

// MARK: - Session Detail Sheet

struct ClientSessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: TrainingGymSession

    private var statusColor: Color {
        if session.isCompleted { return Color.fitGreen }
        if session.isCheckedIn { return Color.fitOrange }
        if session.clientCheckInPhotoURL != nil { return Color.fitIndigo }
        return Color.fitIndigo
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Colored header
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.5))
                            .frame(width: 40, height: 5)
                            .padding(.top, 12)

                        Text(session.scheduledDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))

                        Text("\(session.scheduledDate.formatted(date: .omitted, time: .shortened)) – \(session.endDate.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("\(session.duration) phút")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))

                        detailStatusBadge.padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(statusColor.gradient)

                    VStack(spacing: 16) {
                        // PT info
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.softOrange.opacity(0.12))
                                    .frame(width: 42, height: 42)
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.Colors.softOrange)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Personal Trainer")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.fitTextSecondary)
                                Text(session.trainer?.name ?? "Chưa gán PT")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.fitTextPrimary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.fitCard)
                                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                        )

                        // Check-in photo
                        if let urlStr = session.clientCheckInPhotoURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                        .frame(maxWidth: .infinity).frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                default:
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.fitCard).frame(height: 200)
                                        .overlay(ProgressView())
                                }
                            }
                        }

                        // Client self check-in
                        if let t = session.clientCheckInTime {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .foregroundStyle(Color.fitIndigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Bạn đã check-in")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("lúc \(t.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.fitTextSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.fitIndigo.opacity(0.08))
                            )
                        }

                        // PT check-in
                        if session.isCheckedIn, let t = session.checkInTime {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(Color.fitGreen)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PT đã xác nhận")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("lúc \(t.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.fitTextSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.fitGreen.opacity(0.08))
                            )
                        }

                        if !session.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Ghi chú", systemImage: "note.text")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.fitTextSecondary)
                                Text(session.notes)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.fitTextSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.fitCard)
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
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var detailStatusBadge: some View {
        Group {
            if session.isCompleted {
                Label("Hoàn thành", systemImage: "checkmark.circle.fill")
            } else if session.isCheckedIn {
                Label("Đang tập", systemImage: "figure.run")
            } else if session.clientCheckInPhotoURL != nil {
                Label("Đã gửi ảnh", systemImage: "camera.fill")
            } else {
                Label("Chờ check-in", systemImage: "clock.fill")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.22)))
    }
}
