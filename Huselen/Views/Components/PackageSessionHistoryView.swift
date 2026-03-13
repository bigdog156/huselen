import SwiftUI

struct PackageSessionHistoryView: View {
    let purchase: PackagePurchase

    private var sessions: [TrainingGymSession] {
        guard let client = purchase.client else { return [] }
        return client.sessions
            .filter { $0.purchaseID == purchase.purchaseID }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private var completedSessions: [TrainingGymSession] {
        sessions.filter { $0.isCompleted }
    }

    private var absentSessions: [TrainingGymSession] {
        sessions.filter { $0.isAbsent }
    }

    private var upcomingSessions: [TrainingGymSession] {
        sessions.filter { !$0.isCompleted && !$0.isAbsent && $0.scheduledDate > Date() }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        List {
            // Package summary
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(purchase.package?.name ?? "Gói PT")
                            .font(.title3)
                            .fontWeight(.bold)
                        Spacer()
                        statusBadge
                    }

                    if let trainer = purchase.trainer {
                        LabeledContent("PT", value: trainer.name)
                            .font(.subheadline)
                    }
                    if let client = purchase.client {
                        LabeledContent("Học viên", value: client.name)
                            .font(.subheadline)
                    }

                    ProgressView(value: Double(purchase.usedSessions), total: Double(purchase.totalSessions))
                        .tint(purchase.remainingSessions > 3 ? .green : .orange)

                    HStack {
                        Text("Đã tập \(purchase.usedSessions)/\(purchase.totalSessions) buổi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("HSD: \(purchase.expiryDate, format: .dateTime.day().month().year())")
                            .font(.caption)
                            .foregroundStyle(purchase.expiryDate < Date() ? .red : .secondary)
                    }

                    if absentSessions.count > 0 {
                        Text("Vắng mặt: \(absentSessions.count) buổi")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }

            // Stats row
            Section {
                HStack(spacing: 0) {
                    statItem(value: "\(completedSessions.count)", label: "Hoàn thành", color: .green)
                    Divider().frame(height: 40)
                    statItem(value: "\(absentSessions.count)", label: "Vắng mặt", color: .orange)
                    Divider().frame(height: 40)
                    statItem(value: "\(purchase.remainingSessions)", label: "Còn lại", color: .blue)
                }
            }

            // Upcoming sessions
            if !upcomingSessions.isEmpty {
                Section("Buổi tập sắp tới (\(upcomingSessions.count))") {
                    ForEach(upcomingSessions.prefix(5)) { session in
                        sessionRow(session)
                    }
                    if upcomingSessions.count > 5 {
                        Text("và \(upcomingSessions.count - 5) buổi nữa...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Completed sessions
            Section("Lịch sử tập (\(completedSessions.count))") {
                if completedSessions.isEmpty {
                    Text("Chưa có buổi tập nào hoàn thành")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(completedSessions) { session in
                        sessionRow(session)
                    }
                }
            }

            // Absent sessions
            if !absentSessions.isEmpty {
                Section("Buổi vắng mặt (\(absentSessions.count))") {
                    ForEach(absentSessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .navigationTitle("Chi tiết gói tập")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if purchase.isFullyUsed {
            Text("Đã hết buổi")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.green.opacity(0.15))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        } else if purchase.isExpired {
            Text("Hết hạn")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.red.opacity(0.15))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        } else {
            Text("Đang hoạt động")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        }
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sessionRow(_ session: TrainingGymSession) -> some View {
        HStack(spacing: 12) {
            // Check-in photo thumbnail or status icon
            if let urlStr = session.clientCheckInPhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 36, height: 36)
                    }
                }
            } else {
                Group {
                    if session.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if session.isAbsent {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "clock.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.title3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.scheduledDate, format: .dateTime.weekday(.wide).day().month().year())
                    .font(.subheadline)

                HStack(spacing: 8) {
                    Text(session.scheduledDate, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(session.duration) phút")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if session.isAbsent && !session.absenceReason.isEmpty {
                    Text("Lý do: \(session.absenceReason)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !session.notes.isEmpty {
                    Text(session.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Check-in time info for completed sessions
            if session.isCompleted, let checkIn = session.checkInTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Check-in")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(checkIn, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
