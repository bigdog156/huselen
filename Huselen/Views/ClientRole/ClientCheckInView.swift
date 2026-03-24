import SwiftUI


struct ClientCheckInView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager

    @State private var showCamera = false
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var checkedInSession: TrainingGymSession?
    @State private var pendingSession: TrainingGymSession?
    @State private var showHistory = false

    // MARK: - Schedule state
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedSession: TrainingGymSession?
    private let cal = Calendar.current
    // MARK: - Session helpers

    private var todaySessions: [TrainingGymSession] {
        let cal = Calendar.current
        return syncManager.sessions
            .filter { cal.isDateInToday($0.scheduledDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Session chưa có ảnh check-in của client và chưa hoàn thành
    private var nextSession: TrainingGymSession? {
        todaySessions.first { !$0.isCompleted && $0.clientCheckInPhotoURL == nil && !$0.isAbsent }
    }

    /// Sessions mà client đã gửi ảnh check-in hoặc PT đã xác nhận
    private var checkedInSessions: [TrainingGymSession] {
        todaySessions.filter { $0.clientCheckInPhotoURL != nil || $0.isCompleted }
    }

    // MARK: - Stats

    private var sessionsThisMonth: Int {
        StreakCalculator.sessionsThisMonth(from: syncManager.sessions)
    }

    private var streakDays: Int {
        StreakCalculator.trainingStreak(from: syncManager.sessions)
    }

    private var sessionsThisWeek: Int {
        StreakCalculator.sessionsThisWeek(from: syncManager.sessions)
    }

    // MARK: - Schedule helpers

    private var allSessions: [TrainingGymSession] {
        syncManager.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private func sessions(for date: Date) -> [TrainingGymSession] {
        allSessions.filter { cal.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    private var selectedDaySessions: [TrainingGymSession] {
        sessions(for: selectedDate)
    }

    private var scheduleMonthLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "MMMM yyyy"
        return df.string(from: currentMonth).capitalized
    }

    private var recentCheckIns: [TrainingGymSession] {
        syncManager.sessions
            .filter { $0.clientCheckInPhotoURL != nil || $0.isCompleted }
            .sorted { $0.scheduledDate > $1.scheduledDate }
            .prefix(4)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                heroCardView

                if let session = nextSession {
                    nextSessionCard(session)
                    ctaButton(session)
                } else if !checkedInSessions.isEmpty {
                    allDoneCard
                } else {
                    noSessionCard
                }

                statsRowView
                scheduleCalendarSection
                scheduleSessionList
                milestoneBadgesSection
                historySection
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Theme.Colors.screenBackground)
        .task { await syncManager.refresh() }
        .refreshable { await syncManager.refresh() }
        .fullScreenCover(isPresented: $showCamera) {
            LocketCameraView { data in
                guard let session = pendingSession else { return }
                checkedInSession = session
                showCamera = false
                Task {
                    isProcessing = true
                    let success = await syncManager.clientCheckIn(session: session, photoData: data)
                    isProcessing = false
                    if success {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showSuccess = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showSuccess = false }
                        }
                    }
                }
            }
        }
        .overlay { if showSuccess { successOverlay } }
        .overlay { if isProcessing { processingOverlay } }
        .sheet(isPresented: $showHistory) {
            ClientCheckInHistoryView()
        }
        .sheet(item: $selectedSession) { session in
            ClientSessionDetailSheet(session: session)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        ClientHeaderView(subtitle: greetingText, title: "Check-in")
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Chào buổi sáng!" }
        if hour < 18 { return "Chào buổi chiều!" }
        return "Chào buổi tối!"
    }

    // MARK: - Hero Card

    private var heroCardView: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.102, green: 0.153, blue: 0.267),
                                     Color(red: 0.059, green: 0.239, blue: 0.180)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 160)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 110))
                            .foregroundStyle(.white.opacity(0.05))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                    )
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(motivationalText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(20)
            }

            if streakDays > 0 {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 13))
                    Text("\(streakDays) ngày")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.55)))
                .padding(12)
            }
        }
    }

    private var motivationalText: String {
        let msgs = [
            "Hôm nay là ngày tuyệt vời để tập!",
            "Mỗi buổi tập là một bước tiến!",
            "Kiên trì là chìa khóa thành công!",
            "Bạn đang làm rất tốt, tiếp tục nào!",
            "Sức mạnh đến từ ý chí của bạn!"
        ]
        return msgs[Calendar.current.component(.day, from: Date()) % msgs.count]
    }

    // MARK: - Next Session Card

    private func nextSessionCard(_ session: TrainingGymSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Buổi tập tiếp theo")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)

            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.fitGreen)
                    .frame(width: 4, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.scheduledDate, format: .dateTime.hour().minute())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    Text("PT: \(session.trainer?.name ?? "N/A")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                }

                Spacer()

                Text("\(session.duration) phút")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.fitCoral))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: - CTA Button

    private func ctaButton(_ session: TrainingGymSession) -> some View {
        Button {
            pendingSession = session
            showCamera = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Chụp ảnh Check-in")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.fitGreen, Color.fitGreenDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }

    // MARK: - All Done / No Session

    private var allDoneCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.fitGreen)
            Text("Tuyệt vời! Đã check-in hôm nay")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fitTextPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard))
    }

    private var noSessionCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.fitTextTertiary)
            Text("Hôm nay không có buổi tập")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fitTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard))
    }

    // MARK: - Stats Row

    private var statsRowView: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "calendar.badge.checkmark",
                value: "\(sessionsThisMonth)",
                label: "Buổi tháng",
                valueColor: Color.fitIndigo,
                bg: Color.fitCard
            )
            statCard(
                emoji: "🔥",
                value: "\(streakDays)",
                label: "Ngày streak",
                valueColor: Color.fitOrange,
                bg: Theme.Colors.warmYellow.opacity(0.15)
            )
            statCard(
                icon: "figure.run",
                value: "\(sessionsThisWeek)",
                label: "Tuần này",
                valueColor: Color.fitGreen,
                bg: Color.fitGreenSoft
            )
        }
    }

    private func statCard(icon: String? = nil, emoji: String? = nil,
                          value: String, label: String,
                          valueColor: Color, bg: Color) -> some View {
        VStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .frame(height: 20)
            } else if let emoji {
                Text(emoji).font(.system(size: 18)).frame(height: 20)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(valueColor.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(bg))
    }

    // MARK: - Schedule Calendar

    private var scheduleCalendarSection: some View {
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

                Text(scheduleMonthLabel)
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
                        scheduleDayCell(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.fitCard)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    private func scheduleDayCell(_ date: Date) -> some View {
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

                if isSelected {
                    Circle()
                        .strokeBorder(hasPhoto ? .white : Color.fitGreen, lineWidth: 2.5)
                }

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

    // MARK: - Schedule Session List

    private var scheduleSessionList: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    scheduleSessionCard(session)
                }
            }
        }
    }

    private func scheduleSessionCard(_ session: TrainingGymSession) -> some View {
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
                            scheduleSessionBadge(session)
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
    private func scheduleSessionBadge(_ session: TrainingGymSession) -> some View {
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

    // MARK: - Milestone Badges

    private var milestoneBadgesSection: some View {
        let milestones: [(Int, String)] = [
            (7, "🏅 7 ngày liên tiếp!"),
            (30, "🥈 30 ngày liên tiếp!"),
            (100, "🥇 100 ngày liên tiếp!")
        ]
        let achieved = milestones.filter { streakDays >= $0.0 }

        return Group {
            if !achieved.isEmpty {
                HStack(spacing: 8) {
                    ForEach(achieved, id: \.0) { _, label in
                        Text(label)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.fitTextPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.fitGreenSoft)
                            )
                    }
                }
            }
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lịch sử check-in")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                Spacer()
                Button {
                    showHistory = true
                } label: {
                    Text("Xem tất cả →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                }
            }

            if recentCheckIns.isEmpty {
                Text("Chưa có lịch sử check-in")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fitTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.fitCard))
            } else {
                HStack(spacing: 10) {
                    ForEach(recentCheckIns) { session in
                        checkInThumb(session)
                    }
                    if recentCheckIns.count < 4 {
                        ForEach(0..<(4 - recentCheckIns.count), id: \.self) { _ in
                            emptyThumb
                        }
                    }
                }
            }
        }
    }

    private func checkInThumb(_ session: TrainingGymSession) -> some View {
        VStack(spacing: 6) {
            Group {
                if let urlStr = session.clientCheckInPhotoURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            thumbPlaceholderContent
                        }
                    }
                } else {
                    thumbPlaceholderContent
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.fitTextTertiary.opacity(0.2), lineWidth: 1)
            )

            Text(thumbDateLabel(session.scheduledDate))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var thumbPlaceholderContent: some View {
        ZStack {
            Color.fitCard
            Image(systemName: "camera.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.fitTextTertiary.opacity(0.4))
        }
    }

    private var emptyThumb: some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.fitCard)
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.fitTextTertiary.opacity(0.1), lineWidth: 1)
                )
            Color.clear.frame(height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func thumbDateLabel(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "d MMM"
        return df.string(from: date)
    }

    // MARK: - Overlays

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.3).tint(.white)
                Text("Đang gửi...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
            )
        }
    }

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.fitGreen)
                    .symbolEffect(.bounce, value: showSuccess)
                Text("Check-in thành công!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let session = checkedInSession {
                    Text("Buổi tập lúc \(session.scheduledDate.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.ultraThinMaterial)
            )
            .transition(.scale.combined(with: .opacity))
        }
        .onTapGesture { withAnimation { showSuccess = false } }
    }
}
