import SwiftUI

// MARK: - Freelance PT Clients View

struct FreelancePTClientsView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showAddClient = false
    @State private var searchText = ""
    @State private var clientToDelete: Client?

    private var clients: [Client] {
        let sorted = syncManager.clients.sorted { $0.name < $1.name }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty {
                    emptyStateView
                } else {
                    clientListView
                }
            }
            .navigationTitle("Học viên")
            .searchable(text: $searchText, prompt: "Tìm học viên...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddClient = true } label: {
                        Label("Thêm", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClient) {
                FreelanceAddClientSheet()
            }
            .confirmationDialog(
                "Xoá học viên \(clientToDelete?.name ?? "")?",
                isPresented: Binding(
                    get: { clientToDelete != nil },
                    set: { if !$0 { clientToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Xoá học viên", role: .destructive) {
                    if let client = clientToDelete {
                        Task { await syncManager.deleteClient(client) }
                        clientToDelete = nil
                    }
                }
                Button("Huỷ", role: .cancel) { clientToDelete = nil }
            } message: {
                Text("Hành động này không thể hoàn tác. Tất cả dữ liệu tập luyện sẽ bị xoá.")
            }
            .refreshable {
                await syncManager.refresh()
            }
        }
    }

    // MARK: - Initials

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String((parts.first?.prefix(1) ?? "") + (parts.last?.prefix(1) ?? "")).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Subviews

private extension FreelancePTClientsView {

    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.softOrange.opacity(0.6))
            Text("Chưa có học viên")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.fitTextPrimary)
            Text("Nhấn + để thêm học viên mới")
                .font(.subheadline)
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var clientListView: some View {
        List {
            ForEach(clients) { client in
                NavigationLink(destination: FreelanceClientDetailView(client: client)) {
                    clientCard(client)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        clientToDelete = client
                    } label: {
                        Label("Xoá", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }

    func clientCard(_ client: Client) -> some View {
        HStack(spacing: 14) {
            // Avatar initials circle
            Text(initials(for: client.name))
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.Colors.softOrange, Theme.Colors.softOrange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            // Center: name, goal, body stat chips
            VStack(alignment: .leading, spacing: 6) {
                Text(client.name)
                    .font(.headline)
                    .foregroundStyle(Color.fitTextPrimary)

                if !client.goal.isEmpty {
                    Text(client.goal)
                        .font(.caption)
                        .foregroundStyle(Color.fitTextSecondary)
                        .lineLimit(1)
                }

                // Body stat chips
                if client.weight > 0 || client.bodyFat > 0 {
                    HStack(spacing: 6) {
                        if client.weight > 0 {
                            statChip(
                                text: String(format: "%.1f kg", client.weight),
                                color: Color.fitIndigo
                            )
                        }
                        if client.bodyFat > 0 {
                            statChip(
                                text: String(format: "%.1f%%", client.bodyFat),
                                color: Color.fitOrange
                            )
                        }
                    }
                }
            }

            Spacer()

            // Remaining sessions badge
            Text("\(client.remainingSessions)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(client.remainingSessions > 0 ? Color.fitGreen : Color.fitCoral)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(
                            (client.remainingSessions > 0 ? Color.fitGreen : Color.fitCoral)
                                .opacity(0.12)
                        )
                )

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    func statChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Add Client Sheet (Freelance)

struct FreelanceAddClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var goal = ""
    @State private var isSaving = false

    // Optional body stats
    @State private var showBodyStats = false
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var muscleMassText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin cơ bản") {
                    TextField("Họ và tên", text: $name)
                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Mục tiêu") {
                    TextField("Mục tiêu tập luyện", text: $goal)
                }

                Section {
                    DisclosureGroup("Chỉ số ban đầu", isExpanded: $showBodyStats) {
                        HStack {
                            Text("Chiều cao")
                                .foregroundStyle(Color.fitTextSecondary)
                            Spacer()
                            TextField("cm", text: $heightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Cân nặng")
                                .foregroundStyle(Color.fitTextSecondary)
                            Spacer()
                            TextField("kg", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Tỷ lệ mỡ")
                                .foregroundStyle(Color.fitTextSecondary)
                            Spacer()
                            TextField("%", text: $bodyFatText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Khối lượng cơ")
                                .foregroundStyle(Color.fitTextSecondary)
                            Spacer()
                            TextField("kg", text: $muscleMassText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                } footer: {
                    Text("Các chỉ số này không bắt buộc")
                }
            }
            .navigationTitle("Thêm học viên")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let height = Double(heightText) ?? 0
        let weight = Double(weightText) ?? 0
        let bodyFat = Double(bodyFatText) ?? 0
        let muscleMass = Double(muscleMassText) ?? 0

        let client = Client(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            height: height,
            weight: weight,
            bodyFat: bodyFat,
            muscleMass: muscleMass
        )
        client.goal = goal

        let hasBodyStats = height > 0 || weight > 0 || bodyFat > 0 || muscleMass > 0

        Task { @MainActor in
            await syncManager.createClient(client)
            if hasBodyStats {
                await syncManager.saveBodyStatLog(from: client)
            }
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Client Detail (Freelance)

struct FreelanceClientDetailView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var client: Client

    @State private var showUpdateStats = false
    @State private var showEditSheet = false
    @State private var workoutLogSession: TrainingGymSession?

    private let softOrange = Color(red: 1.0, green: 0.557, blue: 0.176)

    private var completedSessions: Int {
        client.sessions.filter { $0.isCompleted }.count
    }

    private var absentSessions: Int {
        client.sessions.filter { $0.isAbsent }.count
    }

    private var upcomingSessions: [TrainingGymSession] {
        client.sessions
            .filter { !$0.isCompleted && !$0.isAbsent && $0.scheduledDate >= Date() }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var historySessions: [TrainingGymSession] {
        client.sessions
            .filter { $0.isCompleted || $0.isAbsent }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                trainingStatsRow
                if !upcomingSessions.isEmpty {
                    upcomingSection
                }
                if !historySessions.isEmpty {
                    historySection
                }
                if !client.notes.isEmpty {
                    notesSection
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(client.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sửa") { showEditSheet = true }
                    .foregroundStyle(softOrange)
            }
        }
        .sheet(isPresented: $showUpdateStats) {
            UpdateBodyStatsSheet(client: client)
        }
        .sheet(isPresented: $showEditSheet) {
            FreelanceEditClientSheet(client: client)
        }
        .sheet(item: $workoutLogSession) { session in
            WorkoutLogSheet(session: session, client: client)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Name and goal
            HStack(spacing: 14) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(softOrange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(client.name)
                        .font(.title2.bold())
                        .foregroundStyle(Color.fitTextPrimary)
                    if !client.goal.isEmpty {
                        Text(client.goal)
                            .font(.subheadline)
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                }

                Spacer()
            }

            // Contact info
            if !client.phone.isEmpty || !client.email.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !client.phone.isEmpty {
                        Label(client.phone, systemImage: "phone.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                    if !client.email.isEmpty {
                        Label(client.email, systemImage: "envelope.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                }
            }

            // Body stats chips
            if client.weight > 0 || client.bodyFat > 0 || client.muscleMass > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if client.weight > 0 {
                            bodyStatChip(
                                label: "Cân nặng",
                                value: String(format: "%.1f kg", client.weight),
                                color: Color.fitIndigo
                            )
                        }
                        if client.bodyFat > 0 {
                            bodyStatChip(
                                label: "Mỡ",
                                value: String(format: "%.1f%%", client.bodyFat),
                                color: Color.fitOrange
                            )
                        }
                        if client.muscleMass > 0 {
                            bodyStatChip(
                                label: "Cơ",
                                value: String(format: "%.1f kg", client.muscleMass),
                                color: Color.fitGreen
                            )
                        }
                        if client.height > 0 {
                            bodyStatChip(
                                label: "Cao",
                                value: String(format: "%.0f cm", client.height),
                                color: Color.fitBlue
                            )
                        }
                    }
                }
            }

            // Update button
            Button {
                showUpdateStats = true
            } label: {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Cập nhật chỉ số")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(softOrange)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(softOrange.opacity(0.12), in: Capsule())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    private func bodyStatChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Training Stats Row

    private var trainingStatsRow: some View {
        HStack(spacing: 12) {
            trainingStatCard(
                icon: "list.clipboard",
                value: "\(client.sessions.count)",
                label: "Tổng buổi",
                color: Color.fitIndigo
            )
            trainingStatCard(
                icon: "checkmark.circle.fill",
                value: "\(completedSessions)",
                label: "Hoàn thành",
                color: Color.fitGreen
            )
            trainingStatCard(
                icon: "clock.arrow.circlepath",
                value: "\(client.remainingSessions)",
                label: "Còn lại",
                color: softOrange
            )
        }
    }

    private func trainingStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(Color.fitTextPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.fitTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: - Upcoming Sessions

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Lịch sắp tới", icon: "calendar")

            ForEach(upcomingSessions.prefix(5)) { session in
                upcomingSessionCard(session)
            }
        }
    }

    private func upcomingSessionCard(_ session: TrainingGymSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Date column
                VStack(spacing: 2) {
                    Text(session.scheduledDate, format: .dateTime.day())
                        .font(.title3.bold())
                        .foregroundStyle(softOrange)
                    Text(session.scheduledDate, format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(Color.fitTextTertiary)
                }
                .frame(width: 44)

                // Divider
                RoundedRectangle(cornerRadius: 1)
                    .fill(softOrange.opacity(0.3))
                    .frame(width: 2, height: 36)

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.scheduledDate, format: .dateTime.weekday(.wide))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.fitTextPrimary)
                    HStack(spacing: 8) {
                        Label(
                            session.scheduledDate.formatted(.dateTime.hour().minute()),
                            systemImage: "clock"
                        )
                        Text("\(session.duration) phút")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.fitTextSecondary)
                }

                Spacer()

                // Status badge
                sessionStatusBadge(for: session)
            }

            Divider()
                .padding(.vertical, 10)

            // Workout log button
            Button {
                workoutLogSession = session
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption)
                    Text("Ghi chép bài tập")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(softOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(softOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private func sessionStatusBadge(for session: TrainingGymSession) -> some View {
        let (text, color) = sessionStatusInfo(for: session)
        return Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func sessionStatusInfo(for session: TrainingGymSession) -> (String, Color) {
        if session.isCompleted {
            return ("Hoàn thành", Color.fitGreen)
        } else if session.isAbsent {
            return ("Vắng mặt", Color.fitCoral)
        } else if session.isCheckedIn {
            return ("Đang tập", Color.fitBlue)
        } else {
            return ("Sắp tới", softOrange)
        }
    }

    // MARK: - Session History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Lịch sử tập", icon: "clock.arrow.circlepath")

            ForEach(historySessions.prefix(5)) { session in
                historySessionCard(session)
            }
        }
    }

    private func historySessionCard(_ session: TrainingGymSession) -> some View {
        HStack(spacing: 12) {
            // Status icon
            Circle()
                .fill(session.isCompleted ? Color.fitGreen.opacity(0.15) : Color.fitCoral.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: session.isCompleted ? "checkmark" : "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(session.isCompleted ? Color.fitGreen : Color.fitCoral)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.fitTextPrimary)
                Text(session.scheduledDate, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(Color.fitTextTertiary)
            }

            Spacer()

            // Status text
            Text(session.isCompleted ? "Hoàn thành" : "Vắng mặt")
                .font(.caption.weight(.medium))
                .foregroundStyle(session.isCompleted ? Color.fitGreen : Color.fitCoral)

            // Workout log button
            Button {
                workoutLogSession = session
            } label: {
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                    .foregroundStyle(softOrange)
                    .padding(7)
                    .background(softOrange.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)

            // Check-in photo thumbnail
            if let photoURL = session.clientCheckInPhotoURL, !photoURL.isEmpty {
                AsyncImage(url: URL(string: photoURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    default:
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.fitCard)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundStyle(Color.fitTextTertiary)
                            }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Ghi chú", icon: "note.text")

            Text(client.notes)
                .font(.subheadline)
                .foregroundStyle(Color.fitTextSecondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )
        }
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(Color.fitTextPrimary)
            .padding(.top, 4)
    }
}

// MARK: - Edit Client Sheet (Freelance)

struct FreelanceEditClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    let client: Client

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var goal: String = ""

    // Body stats
    @State private var heightText: String = ""
    @State private var weightText: String = ""
    @State private var bodyFatText: String = ""
    @State private var muscleMassText: String = ""

    // Measurements
    @State private var neckText: String = ""
    @State private var shoulderText: String = ""
    @State private var armText: String = ""
    @State private var chestText: String = ""
    @State private var waistText: String = ""
    @State private var hipText: String = ""
    @State private var thighText: String = ""
    @State private var calfText: String = ""
    @State private var lowerHipText: String = ""

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin cơ bản") {
                    TextField("Họ và tên", text: $name)
                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Mục tiêu", text: $goal)
                }

                Section("Chỉ số cơ thể") {
                    numericRow(label: "Chiều cao (cm)", text: $heightText)
                    numericRow(label: "Cân nặng (kg)", text: $weightText)
                    numericRow(label: "Tỷ lệ mỡ (%)", text: $bodyFatText)
                    numericRow(label: "Khối lượng cơ (kg)", text: $muscleMassText)
                }

                Section("Số đo (cm)") {
                    numericRow(label: "Cổ", text: $neckText)
                    numericRow(label: "Vai", text: $shoulderText)
                    numericRow(label: "Bắp tay", text: $armText)
                    numericRow(label: "Ngực", text: $chestText)
                    numericRow(label: "Eo", text: $waistText)
                    numericRow(label: "Hông", text: $hipText)
                    numericRow(label: "Đùi", text: $thighText)
                    numericRow(label: "Bắp chân", text: $calfText)
                    numericRow(label: "Mông", text: $lowerHipText)
                }
            }
            .navigationTitle("Sửa học viên")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear { loadClientData() }
        }
    }

    private func numericRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.fitTextSecondary)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func loadClientData() {
        name = client.name
        phone = client.phone
        email = client.email
        goal = client.goal
        heightText = client.height > 0 ? String(format: "%.1f", client.height) : ""
        weightText = client.weight > 0 ? String(format: "%.1f", client.weight) : ""
        bodyFatText = client.bodyFat > 0 ? String(format: "%.1f", client.bodyFat) : ""
        muscleMassText = client.muscleMass > 0 ? String(format: "%.1f", client.muscleMass) : ""
        neckText = client.neck > 0 ? String(format: "%.1f", client.neck) : ""
        shoulderText = client.shoulder > 0 ? String(format: "%.1f", client.shoulder) : ""
        armText = client.arm > 0 ? String(format: "%.1f", client.arm) : ""
        chestText = client.chest > 0 ? String(format: "%.1f", client.chest) : ""
        waistText = client.waist > 0 ? String(format: "%.1f", client.waist) : ""
        hipText = client.hip > 0 ? String(format: "%.1f", client.hip) : ""
        thighText = client.thigh > 0 ? String(format: "%.1f", client.thigh) : ""
        calfText = client.calf > 0 ? String(format: "%.1f", client.calf) : ""
        lowerHipText = client.lowerHip > 0 ? String(format: "%.1f", client.lowerHip) : ""
    }

    private func save() {
        isSaving = true

        client.name = name.trimmingCharacters(in: .whitespaces)
        client.phone = phone.trimmingCharacters(in: .whitespaces)
        client.email = email.trimmingCharacters(in: .whitespaces)
        client.goal = goal
        client.height = Double(heightText) ?? 0
        client.weight = Double(weightText) ?? 0
        client.bodyFat = Double(bodyFatText) ?? 0
        client.muscleMass = Double(muscleMassText) ?? 0
        client.neck = Double(neckText) ?? 0
        client.shoulder = Double(shoulderText) ?? 0
        client.arm = Double(armText) ?? 0
        client.chest = Double(chestText) ?? 0
        client.waist = Double(waistText) ?? 0
        client.hip = Double(hipText) ?? 0
        client.thigh = Double(thighText) ?? 0
        client.calf = Double(calfText) ?? 0
        client.lowerHip = Double(lowerHipText) ?? 0

        Task { @MainActor in
            await syncManager.updateClient(client)
            await syncManager.saveBodyStatLog(from: client)
            isSaving = false
            dismiss()
        }
    }
}
