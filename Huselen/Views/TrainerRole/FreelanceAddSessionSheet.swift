import SwiftUI

enum SessionCreationMode: String, CaseIterable {
    case single = "Buổi lẻ"
    case recurring = "Lịch cố định"
    case makeup = "Tập bù"
}

struct FreelanceAddSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    let selectedDate: Date

    @State private var mode: SessionCreationMode = .single
    @State private var scheduledDate: Date
    @State private var duration: Int = 60
    @State private var selectedClientId: UUID?
    @State private var notes = ""
    @State private var isSaving = false

    // Recurring schedule
    @State private var selectedDays: Set<Int> = []  // 1=CN, 2=T2, ..., 7=T7
    @State private var scheduleTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var numberOfWeeks: Int = 4

    // Makeup
    @State private var missedSessionId: UUID?

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let defaultDate = cal.date(bySettingHour: max(hour + 1, 7), minute: 0, second: 0, of: selectedDate) ?? selectedDate
        self._scheduledDate = State(initialValue: defaultDate)
    }

    private var clients: [Client] {
        syncManager.clients.sorted { $0.name < $1.name }
    }

    private var selectedClient: Client? {
        guard let id = selectedClientId else { return nil }
        return clients.first { $0.id == id }
    }

    private var missedSessions: [TrainingGymSession] {
        guard let client = selectedClient else { return [] }
        return client.sessions
            .filter { $0.isAbsent && !$0.isCompleted }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private let weekdayLabels: [(label: String, value: Int)] = [
        ("T2", 2), ("T3", 3), ("T4", 4), ("T5", 5), ("T6", 6), ("T7", 7), ("CN", 1)
    ]

    private var canSave: Bool {
        guard selectedClientId != nil else { return false }
        switch mode {
        case .single: return true
        case .recurring: return !selectedDays.isEmpty && numberOfWeeks > 0
        case .makeup: return missedSessionId != nil
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("Loại", selection: $mode) {
                        ForEach(SessionCreationMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                // Client picker
                Section("Học viên") {
                    if clients.isEmpty {
                        Text("Chưa có học viên. Thêm học viên trước.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Chọn học viên", selection: $selectedClientId) {
                            Text("Chọn...").tag(nil as UUID?)
                            ForEach(clients) { client in
                                Text(client.name).tag(client.id as UUID?)
                            }
                        }
                    }
                }

                // Mode-specific content
                switch mode {
                case .single:
                    singleSessionSection
                case .recurring:
                    recurringSection
                case .makeup:
                    makeupSection
                }

                // Notes
                Section("Ghi chú") {
                    TextField("Ghi chú buổi tập...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tạo") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    // MARK: - Single Session

    private var singleSessionSection: some View {
        Section("Thời gian") {
            DatePicker("Ngày giờ", selection: $scheduledDate)
            durationPicker
        }
    }

    // MARK: - Recurring Schedule

    private var recurringSection: some View {
        Group {
            Section("Ngày tập trong tuần") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(weekdayLabels, id: \.value) { day in
                        let isSelected = selectedDays.contains(day.value)
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if isSelected {
                                    selectedDays.remove(day.value)
                                } else {
                                    selectedDays.insert(day.value)
                                }
                            }
                        } label: {
                            Text(day.label)
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? Color.fitGreen : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Giờ tập") {
                DatePicker("Giờ bắt đầu", selection: $scheduleTime, displayedComponents: .hourAndMinute)
                durationPicker
            }

            Section {
                Stepper("Số tuần: \(numberOfWeeks)", value: $numberOfWeeks, in: 1...52)
            } header: {
                Text("Thời gian áp dụng")
            } footer: {
                let totalSessions = estimatedSessionCount
                if totalSessions > 0 {
                    Text("Sẽ tạo khoảng \(totalSessions) buổi tập trong \(numberOfWeeks) tuần, bắt đầu từ hôm nay.")
                }
            }
        }
    }

    private var estimatedSessionCount: Int {
        selectedDays.count * numberOfWeeks
    }

    // MARK: - Makeup Session

    private var makeupSection: some View {
        Group {
            Section("Buổi tập bị vắng") {
                if selectedClientId == nil {
                    Text("Chọn học viên trước")
                        .foregroundStyle(.secondary)
                } else if missedSessions.isEmpty {
                    Text("Không có buổi nào bị vắng")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(missedSessions) { session in
                        Button {
                            missedSessionId = session.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.primary)
                                    Text(session.scheduledDate, format: .dateTime.hour().minute())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !session.absenceReason.isEmpty {
                                        Text("Lý do: \(session.absenceReason)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if missedSessionId == session.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.fitGreen)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Lịch tập bù") {
                DatePicker("Ngày giờ", selection: $scheduledDate)
                durationPicker
            }
        }
    }

    // MARK: - Shared Components

    private var durationPicker: some View {
        Picker("Thời lượng", selection: $duration) {
            Text("30 phút").tag(30)
            Text("45 phút").tag(45)
            Text("60 phút").tag(60)
            Text("90 phút").tag(90)
            Text("120 phút").tag(120)
        }
    }

    // MARK: - Save

    private func save() {
        guard let client = selectedClient else { return }
        let trainer = syncManager.trainers.first ?? Trainer(name: "")
        isSaving = true

        Task {
            switch mode {
            case .single:
                let session = TrainingGymSession(
                    trainer: trainer, client: client,
                    scheduledDate: scheduledDate, duration: duration
                )
                session.notes = notes
                await syncManager.createSession(session)

            case .recurring:
                let sessions = generateRecurringSessions(trainer: trainer, client: client)
                if !sessions.isEmpty {
                    await syncManager.createSessions(sessions)
                }

            case .makeup:
                let session = TrainingGymSession(
                    trainer: trainer, client: client,
                    scheduledDate: scheduledDate, duration: duration
                )
                session.isMakeup = true
                session.originalSessionId = missedSessionId
                session.notes = notes.isEmpty ? "Buổi tập bù" : notes
                await syncManager.createSession(session)
            }

            isSaving = false
            dismiss()
        }
    }

    private func generateRecurringSessions(trainer: Trainer, client: Client) -> [TrainingGymSession] {
        guard !selectedDays.isEmpty else { return [] }

        let cal = Calendar.current
        let timeComponents = cal.dateComponents([.hour, .minute], from: scheduleTime)
        let hour = timeComponents.hour ?? 18
        let minute = timeComponents.minute ?? 0
        let maxDate = cal.date(byAdding: .weekOfYear, value: numberOfWeeks, to: Date()) ?? Date()

        var sessions: [TrainingGymSession] = []
        var currentDate = cal.startOfDay(for: Date())

        while currentDate <= maxDate {
            let weekday = cal.component(.weekday, from: currentDate)
            if selectedDays.contains(weekday) {
                var components = cal.dateComponents([.year, .month, .day], from: currentDate)
                components.hour = hour
                components.minute = minute
                if let sessionDate = cal.date(from: components), sessionDate >= Date() {
                    let session = TrainingGymSession(
                        trainer: trainer, client: client,
                        scheduledDate: sessionDate, duration: duration
                    )
                    session.notes = notes
                    sessions.append(session)
                }
            }
            currentDate = cal.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return sessions
    }
}
