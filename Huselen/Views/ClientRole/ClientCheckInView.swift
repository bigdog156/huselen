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
                historySection
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
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
                valueColor: Color(red: 0.918, green: 0.345, blue: 0.047),
                bg: Color(red: 1.0, green: 0.969, blue: 0.929)
            )
            statCard(
                icon: "figure.run",
                value: "\(sessionsThisWeek)",
                label: "Tuần này",
                valueColor: Color.fitGreen,
                bg: Color(red: 0.941, green: 0.992, blue: 0.957)
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
