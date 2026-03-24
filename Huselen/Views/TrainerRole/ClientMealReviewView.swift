import SwiftUI
import Auth

// MARK: - Client Meal Review View
/// PT/Admin screen for reviewing a specific client's daily meals and leaving feedback.

struct ClientMealReviewView: View {
    let client: Client

    @Environment(DataSyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedDate = Date()
    @State private var mealLogs: [MealType: UserMealLog] = [:]
    @State private var comments: [MealComment] = []
    @State private var isLoading = false
    @State private var showMealPlanEditor = false

    // Comment input
    @State private var commentText = ""
    @State private var commentTargetMealLogId: String? = nil // nil = whole day

    // MARK: - Computed

    private var totalCalories: Int {
        mealLogs.values.compactMap(\.calories).reduce(0, +)
    }
    private var totalProtein: Double {
        mealLogs.values.compactMap(\.proteinG).reduce(0, +)
    }
    private var totalCarbs: Double {
        mealLogs.values.compactMap(\.carbsG).reduce(0, +)
    }
    private var totalFat: Double {
        mealLogs.values.compactMap(\.fatG).reduce(0, +)
    }

    private var dateLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "EEEE, dd/MM/yyyy"
        return df.string(from: selectedDate).capitalized
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    dateStripSection
                    dailySummaryCard
                    mealCardsSection
                    dayCommentsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for input bar
            }
            .background(Theme.Colors.screenBackground)

            commentInputBar
        }
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showMealPlanEditor = true
                } label: {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.softOrange)
                }
            }
        }
        .sheet(isPresented: $showMealPlanEditor) {
            NavigationStack {
                MealPlanEditorView(client: client)
            }
        }
        .task { await loadData() }
        .onChange(of: selectedDate) { _, _ in
            Task { await loadData() }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        guard let profileId = client.profileId?.uuidString else {
            isLoading = false
            return
        }
        async let logsTask = syncManager.fetchClientMealLogs(profileId: profileId, date: selectedDate)
        async let commentsTask = syncManager.fetchMealComments(clientId: client.id.uuidString, date: selectedDate)
        let (logs, fetchedComments) = await (logsTask, commentsTask)
        mealLogs = logs
        comments = fetchedComments
        isLoading = false
    }

    private func sendComment() async {
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let authorId = authManager.currentUser?.id.uuidString ?? ""
        let authorName = authManager.userProfile?.fullName ?? "HLV"
        let authorRole: MealComment.AuthorRole = authManager.userRole == .owner ? .admin : .pt

        let comment = MealComment(
            mealLogId: commentTargetMealLogId,
            clientId: client.id.uuidString,
            commentDate: selectedDate,
            authorId: authorId,
            authorName: authorName,
            authorRole: authorRole,
            message: text
        )
        commentText = ""
        commentTargetMealLogId = nil
        if await syncManager.saveMealComment(comment) {
            comments = await syncManager.fetchMealComments(clientId: client.id.uuidString, date: selectedDate)
        }
    }

    // MARK: - Date Horizontal Strip

    private var dateStripSection: some View {
        VStack(spacing: 8) {
            // Current date label
            Text(dateLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.fitTextSecondary)

            // Scrollable 7-day strip
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(-3..<4, id: \.self) { offset in
                            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                            let day = Calendar.current.component(.day, from: date)
                            let weekday = vietWeekdayShort(date)

                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedDate = date
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(weekday)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.fitTextTertiary)
                                    Text("\(day)")
                                        .font(.system(size: 18, weight: isSelected ? .bold : .semibold, design: .rounded))
                                        .foregroundStyle(isSelected ? .white : Color.fitTextPrimary)
                                }
                                .frame(width: 44, height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(isSelected ? Color.fitGreen : Color.fitCard)
                                        .shadow(color: isSelected ? Color.fitGreen.opacity(0.3) : .clear, radius: 8, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                            .id(offset)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    proxy.scrollTo(0, anchor: .center)
                }
            }
        }
    }

    // MARK: - Daily Summary Card

    private var dailySummaryCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.fitGreen, Color.fitGreenDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Decorative circle
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 100, height: 100)
                .offset(x: 260, y: -10)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tong quan ngay")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    // Compliance badge
                    let pct = client.calorieGoal > 0
                        ? Int(Double(totalCalories) / Double(client.calorieGoal) * 100)
                        : 0
                    Text("\(pct)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(totalCalories)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(client.calorieGoal) kcal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25)).frame(height: 6)
                        Capsule()
                            .fill(Color.white)
                            .frame(
                                width: geo.size.width * min(1, Double(totalCalories) / Double(max(1, client.calorieGoal))),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                // Macro row
                HStack(spacing: 16) {
                    macroLabel("Dam", value: totalProtein, goal: client.proteinGoal)
                    macroLabel("Carbs", value: totalCarbs, goal: client.carbsGoal)
                    macroLabel("Beo", value: totalFat, goal: client.fatGoal)
                }
            }
            .padding(20)
        }
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func macroLabel(_ name: String, value: Double, goal: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            Text("\(Int(value))g / \(Int(goal))g")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: - Meal Cards Section

    private var mealCardsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("BUA AN TRONG NGAY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .tracking(0.8)
                Spacer()
                Text("\(mealLogs.values.filter { $0.hasContent }.count)/4 bua")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
            }

            if isLoading {
                ProgressView()
                    .padding(.vertical, 40)
            } else {
                ForEach(MealType.allCases.sorted(by: { $0.order < $1.order }), id: \.self) { mealType in
                    let mealLog = mealLogs[mealType]
                    let mealComments = comments.filter { $0.mealLogId == mealLog?.id }
                    MealReviewCard(
                        mealType: mealType,
                        mealLog: mealLog,
                        comments: mealComments,
                        onTapComment: {
                            commentTargetMealLogId = mealLog?.id
                        }
                    )
                }
            }
        }
    }

    // MARK: - Day-level Comments

    private var dayCommentsSection: some View {
        let dayComments = comments.filter { $0.mealLogId == nil }

        return VStack(alignment: .leading, spacing: 10) {
            if !dayComments.isEmpty {
                HStack {
                    Text("NHAN XET CHUNG")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.fitTextTertiary)
                        .tracking(0.8)
                    Spacer()
                }

                ForEach(dayComments) { comment in
                    CommentBubble(comment: comment)
                }
            }
        }
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider()

            // Target indicator
            if let targetId = commentTargetMealLogId,
               let mealLog = mealLogs.values.first(where: { $0.id == targetId }) {
                HStack(spacing: 6) {
                    Image(systemName: mealLog.mealType.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(mealLog.mealType.color)
                    Text("Nhan xet ve \(mealLog.mealType.displayName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextSecondary)
                    Spacer()
                    Button {
                        commentTargetMealLogId = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                TextField("Nhan xet cho hoc vien...", text: $commentText)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(UIColor.systemGray6))
                    )

                Button {
                    Task { await sendComment() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.fitTextTertiary
                                : Color.fitGreen
                        )
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func vietWeekdayShort(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        let map = [1: "CN", 2: "T2", 3: "T3", 4: "T4", 5: "T5", 6: "T6", 7: "T7"]
        return map[weekday] ?? ""
    }
}

// MARK: - Meal Review Card
/// Shows the meal photo (4:3 hero), name, calories, macro overlay, and inline comments.

struct MealReviewCard: View {
    let mealType: MealType
    let mealLog: UserMealLog?
    let comments: [MealComment]
    let onTapComment: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row: icon + meal name + time + calories badge
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(mealType.color.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: mealType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(mealType.color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(mealType.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    if let time = mealLog?.formattedTime, !time.isEmpty {
                        Text(time)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                }

                Spacer()

                if let cal = mealLog?.calories {
                    Text("\(cal) kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(mealType.color)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(mealType.color.opacity(0.12)))
                } else {
                    Text("Chua ghi")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Photo hero (4:3 aspect)
            if let photoUrl = mealLog?.photoUrl, !photoUrl.isEmpty {
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: photoUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(4/3, contentMode: .fill)
                                .clipped()
                        case .failure:
                            photoPlaceholder
                        case .empty:
                            ZStack {
                                Color.fitCard
                                ProgressView()
                            }
                            .aspectRatio(4/3, contentMode: .fill)
                        @unknown default:
                            photoPlaceholder
                        }
                    }

                    // Macro overlay gradient
                    if let log = mealLog, (log.proteinG ?? 0) > 0 {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)

                        HStack(spacing: 12) {
                            macroChip("P", value: log.proteinG ?? 0, color: .fitIndigo)
                            macroChip("C", value: log.carbsG ?? 0, color: .fitOrange)
                            macroChip("F", value: log.fatG ?? 0, color: .fitCoral)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 0))
            } else {
                // Empty state for no photo
                VStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.fitTextTertiary.opacity(0.4))
                    Text("Hoc vien chua chup anh")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color.fitCard.opacity(0.5))
            }

            // Note from client
            if let note = mealLog?.note, !note.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fitTextTertiary)
                    Text(note)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.fitTextSecondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // Feeling badge
            if let feeling = mealLog?.feeling {
                HStack(spacing: 4) {
                    Image(systemName: feeling.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(feeling.color)
                    Text(feeling.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(feeling.color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(feeling.color.opacity(0.12)))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Inline comments for this meal
            if !comments.isEmpty {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 6) {
                    ForEach(comments) { comment in
                        CommentBubble(comment: comment, compact: true)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }

            // "Add comment" tap target
            Button(action: onTapComment) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 11))
                    Text("Nhan xet")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.fitGreen)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .background(Color.fitCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    private var photoPlaceholder: some View {
        ZStack {
            Color.fitCard
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundStyle(Color.fitTextTertiary.opacity(0.3))
        }
        .aspectRatio(4/3, contentMode: .fill)
    }

    private func macroChip(_ label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text("\(Int(value))g")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Comment Bubble

struct CommentBubble: View {
    let comment: MealComment
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Author avatar
            ZStack {
                Circle()
                    .fill(comment.authorRole == .pt ? Theme.Colors.softOrange : Theme.Colors.warmYellow)
                    .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)
                Text(initials(comment.authorName))
                    .font(.system(size: compact ? 9 : 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)

                    Text(comment.authorRole.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(comment.authorRole == .pt ? Theme.Colors.softOrange : Theme.Colors.warmYellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill((comment.authorRole == .pt ? Theme.Colors.softOrange : Theme.Colors.warmYellow).opacity(0.12))
                        )

                    Spacer()

                    Text(comment.timeAgo)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }

                Text(comment.message)
                    .font(.system(size: compact ? 12 : 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.fitTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ")
            .compactMap { $0.first }
            .suffix(2)
            .map { String($0) }
            .joined()
            .uppercased()
    }
}
