import SwiftUI

struct AdminAttendanceView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var selectedDate = Date()
    @State private var selectedTrainer: Trainer?
    @State private var displayedMonth = Date()
    @State private var showWiFiSettings = false

    private let calendar = Calendar.current
    private let weekdaySymbols = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    private var trainers: [Trainer] {
        syncManager.trainers.sorted { $0.name < $1.name }
    }

    private var filteredAttendances: [TrainerAttendance] {
        var result = syncManager.attendances
            .filter { calendar.isDate($0.checkInTime, inSameDayAs: selectedDate) }

        if let trainer = selectedTrainer {
            result = result.filter { $0.trainer?.id == trainer.id }
        }

        return result.sorted { $0.checkInTime > $1.checkInTime }
    }

    private var activeNow: [TrainerAttendance] {
        syncManager.attendances.filter { $0.checkOutTime == nil }
    }

    private var trainerSummaries: [(trainer: Trainer, totalHours: TimeInterval, count: Int)] {
        let dayAttendances = syncManager.attendances
            .filter { calendar.isDate($0.checkInTime, inSameDayAs: selectedDate) }

        return trainers.compactMap { trainer in
            let trainerRecords = dayAttendances.filter { $0.trainer?.id == trainer.id }
            guard !trainerRecords.isEmpty else { return nil }
            let total = trainerRecords.compactMap { $0.duration }.reduce(0, +)
            return (trainer: trainer, totalHours: total, count: trainerRecords.count)
        }.sorted { $0.totalHours > $1.totalHours }
    }

    // Build a set of days (start of day) that have attendance records in the displayed month
    private var attendanceDaysInMonth: Set<Date> {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let monthAttendances = syncManager.attendances.filter {
            $0.checkInTime >= monthInterval.start && $0.checkInTime < monthInterval.end
        }
        var days = Set<Date>()
        for a in monthAttendances {
            if let trainer = selectedTrainer, a.trainer?.id != trainer.id { continue }
            days.insert(calendar.startOfDay(for: a.checkInTime))
        }
        return days
    }

    // Count attendance per day for dot intensity
    private func attendanceCount(for date: Date) -> Int {
        let day = calendar.startOfDay(for: date)
        return syncManager.attendances.filter {
            calendar.startOfDay(for: $0.checkInTime) == day
            && (selectedTrainer == nil || $0.trainer?.id == selectedTrainer?.id)
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Active now banner
                    if !activeNow.isEmpty {
                        activeNowSection
                    }

                    // Trainer filter
                    trainerFilterSection

                    // Calendar
                    calendarSection

                    // Summary for selected day
                    if !trainerSummaries.isEmpty {
                        summarySection
                    }

                    // Detail records
                    detailSection
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Chấm công PT")
            .refreshable {
                await syncManager.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showWiFiSettings = true
                    } label: {
                        Image(systemName: "wifi")
                            .symbolRenderingMode(.monochrome)
                            .foregroundColor(syncManager.gymWiFiSSIDs.isEmpty ? .secondary : .blue)
                    }
                }
            }
            .profileToolbar()
            .sheet(isPresented: $showWiFiSettings) {
                GymWiFiSettingsView()
            }
        }
    }

    // MARK: - Active Now

    private var activeNowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption2)
                Text("Đang làm việc (\(activeNow.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            ForEach(activeNow) { attendance in
                HStack(spacing: 12) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .fill(.green.opacity(0.3))
                                .frame(width: 20, height: 20)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(attendance.trainer?.name ?? "PT")
                            .font(.headline)
                        Text("Check-in lúc \(attendance.checkInTime, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    TimeElapsedView(since: attendance.checkInTime)
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 10)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Trainer Filter

    private var trainerFilterSection: some View {
        Picker("PT", selection: $selectedTrainer) {
            Text("Tất cả PT").tag(nil as Trainer?)
            ForEach(trainers) { trainer in
                Text(trainer.name).tag(trainer as Trainer?)
            }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    withAnimation { changeMonth(by: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation { changeMonth(by: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 4)

            // Weekday headers
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(days, id: \.self) { day in
                    if let day {
                        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                        let isToday = calendar.isDateInToday(day)
                        let dayStart = calendar.startOfDay(for: day)
                        let hasAttendance = attendanceDaysInMonth.contains(dayStart)
                        let count = hasAttendance ? attendanceCount(for: day) : 0

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = day
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.subheadline)
                                    .fontWeight(isToday ? .bold : .regular)
                                    .foregroundStyle(
                                        isSelected ? .white :
                                        isToday ? .blue :
                                        hasAttendance ? .primary : .secondary
                                    )

                                // Attendance dots
                                HStack(spacing: 2) {
                                    if count > 0 {
                                        ForEach(0..<min(count, 3), id: \.self) { _ in
                                            Circle()
                                                .fill(isSelected ? .white : .orange)
                                                .frame(width: 4, height: 4)
                                        }
                                    } else {
                                        Circle()
                                            .fill(.clear)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                isSelected ? Color.blue :
                                isToday ? Color.blue.opacity(0.1) :
                                Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tổng hợp ngày \(selectedDate, format: .dateTime.day().month())")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(trainerSummaries, id: \.trainer.id) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.trainer.name)
                            .font(.headline)
                        Text("\(item.count) lần check-in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatDuration(item.totalHours))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Detail

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chi tiết (\(filteredAttendances.count))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if filteredAttendances.isEmpty {
                Text("Không có dữ liệu")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(filteredAttendances) { attendance in
                    AdminAttendanceRow(attendance: attendance)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    if attendance.id != filteredAttendances.last?.id {
                        Divider().padding(.horizontal, 12)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        // Convert Sunday=1 to Monday-based: Mon=0, Tue=1, ..., Sun=6
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        for day in monthRange {
            if let date = calendar.date(bySetting: .day, value: day, of: monthInterval.start) {
                days.append(date)
            }
        }

        return days
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) phút"
    }
}

struct AdminAttendanceRow: View {
    let attendance: TrainerAttendance
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.orange)
                Text(attendance.trainer?.name ?? "PT")
                    .font(.headline)
                Spacer()
                StatusBadge(isCheckedOut: attendance.isCheckedOut)
            }

            HStack(spacing: 16) {
                Label(attendance.checkInTime.formatted(.dateTime.hour().minute()), systemImage: "arrow.right.circle")
                    .font(.subheadline)
                    .foregroundStyle(.green)

                if let out = attendance.checkOutTime {
                    Label(out.formatted(.dateTime.hour().minute()), systemImage: "arrow.left.circle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Spacer()

                Text(attendance.formattedDuration)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(attendance.isCheckedOut ? .blue : .orange)
            }

            // Attendance photos
            let hasCheckInPhoto = attendance.checkInPhotoURL != nil
            let hasCheckOutPhoto = attendance.checkOutPhotoURL != nil
            if hasCheckInPhoto || hasCheckOutPhoto {
                HStack(spacing: 8) {
                    if let urlStr = attendance.checkInPhotoURL, let url = URL(string: urlStr) {
                        VStack(spacing: 2) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.quaternary)
                                    .frame(width: 60, height: 60)
                            }
                            Text("Vào")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                    if let urlStr = attendance.checkOutPhotoURL, let url = URL(string: urlStr) {
                        VStack(spacing: 2) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.quaternary)
                                    .frame(width: 60, height: 60)
                            }
                            Text("Ra")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                }
            }

            if !attendance.notes.isEmpty {
                Text(attendance.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Sửa giờ", systemImage: "pencil.circle.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if !attendance.isCheckedOut {
                    Button {
                        Task { await syncManager.checkOut(attendance) }
                    } label: {
                        Label("Check-out", systemImage: "arrow.left.circle.fill")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showEditSheet) {
            EditAttendanceSheet(attendance: attendance)
        }
    }
}

struct EditAttendanceSheet: View {
    let attendance: TrainerAttendance
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss

    @State private var checkInTime: Date
    @State private var checkOutTime: Date
    @State private var hasCheckOut: Bool
    @State private var notes: String
    @State private var isSaving = false

    init(attendance: TrainerAttendance) {
        self.attendance = attendance
        _checkInTime = State(initialValue: attendance.checkInTime)
        _checkOutTime = State(initialValue: attendance.checkOutTime ?? Date())
        _hasCheckOut = State(initialValue: attendance.checkOutTime != nil)
        _notes = State(initialValue: attendance.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundStyle(.orange)
                        Text(attendance.trainer?.name ?? "PT")
                            .font(.headline)
                    }
                }

                Section("Giờ check-in") {
                    DatePicker("Check-in", selection: $checkInTime)
                        .datePickerStyle(.compact)
                }

                Section("Giờ check-out") {
                    Toggle("Đã check-out", isOn: $hasCheckOut)

                    if hasCheckOut {
                        DatePicker("Check-out", selection: $checkOutTime)
                            .datePickerStyle(.compact)
                    }
                }

                Section("Ghi chú") {
                    TextField("Ghi chú", text: $notes)
                }

                if hasCheckOut && checkOutTime > checkInTime {
                    Section("Thời gian làm việc") {
                        let duration = checkOutTime.timeIntervalSince(checkInTime)
                        let hours = Int(duration) / 3600
                        let minutes = (Int(duration) % 3600) / 60
                        Text(hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) phút")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .navigationTitle("Chỉnh sửa chấm công")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        Task {
                            isSaving = true
                            attendance.checkInTime = checkInTime
                            attendance.checkOutTime = hasCheckOut ? checkOutTime : nil
                            attendance.notes = notes
                            await syncManager.updateAttendance(attendance)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving || (hasCheckOut && checkOutTime <= checkInTime))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct StatusBadge: View {
    let isCheckedOut: Bool

    var body: some View {
        Text(isCheckedOut ? "Đã ra" : "Đang làm")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isCheckedOut ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(isCheckedOut ? .green : .orange)
            .clipShape(Capsule())
    }
}
