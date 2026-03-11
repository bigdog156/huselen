import SwiftUI

struct PTScheduleView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var allSessions: [TrainingGymSession] {
        syncManager.sessions.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    @State private var selectedDate = Date()

    var todaySessions: [TrainingGymSession] {
        let calendar = Calendar.current
        return allSessions.filter { calendar.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var upcomingSessions: [TrainingGymSession] {
        allSessions.filter { !$0.isCompleted && $0.scheduledDate > Date() }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Chọn ngày", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("Lịch ngày \(selectedDate, format: .dateTime.day().month())") {
                    if todaySessions.isEmpty {
                        Text("Không có lịch")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todaySessions) { session in
                            PTSessionRow(session: session)
                        }
                    }
                }

                Section("Sắp tới") {
                    if upcomingSessions.isEmpty {
                        Text("Không có lịch sắp tới")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(upcomingSessions.prefix(10))) { session in
                            PTSessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("Lịch của tôi")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}

struct PTSessionRow: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var session: TrainingGymSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.client?.name ?? "Khách hàng")
                        .font(.headline)
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(session.scheduledDate, format: .dateTime.hour().minute()) - \(session.endDate, format: .dateTime.hour().minute())")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)

                    if !Calendar.current.isDateInToday(session.scheduledDate) {
                        Text(session.scheduledDate, format: .dateTime.weekday(.wide).day().month())
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Spacer()

                if session.isCompleted {
                    Label("Xong", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if session.isCheckedIn {
                    Label("Đang tập", systemImage: "figure.run")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if !session.isCompleted {
                HStack(spacing: 12) {
                    if !session.isCheckedIn {
                        Button(action: {
                            session.isCheckedIn = true
                            session.checkInTime = Date()
                            Task { await syncManager.updateSession(session) }
                        }) {
                            Label("Check-in", systemImage: "checkmark.shield")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            session.isCompleted = true
                            Task { await syncManager.updateSession(session) }
                        }) {
                            Label("Hoàn thành", systemImage: "checkmark.circle")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.1))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
