import SwiftUI

struct MyBodyStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var clients: [Client] { syncManager.clients }

    var myProfile: Client? {
        clients.first
    }

    var body: some View {
        NavigationStack {
            if let client = myProfile {
                List {
                    Section {
                        HStack(spacing: 16) {
                            CuteIconCircle(icon: "figure", color: Theme.Colors.lavender, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(Theme.Fonts.title())
                                if !client.goal.isEmpty {
                                    Text(client.goal)
                                        .font(Theme.Fonts.subheadline())
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Chỉ số cơ thể") {
                        StatsRow(icon: "scalemass", title: "Cân nặng", value: client.weight > 0 ? String(format: "%.1f kg", client.weight) : "—", color: Theme.Colors.skyBlue)
                        StatsRow(icon: "drop.halffull", title: "Tỷ lệ mỡ", value: client.bodyFat > 0 ? String(format: "%.1f%%", client.bodyFat) : "—", color: Theme.Colors.softOrange)
                        StatsRow(icon: "figure.strengthtraining.traditional", title: "Khối lượng cơ", value: client.muscleMass > 0 ? String(format: "%.1f kg", client.muscleMass) : "—", color: Theme.Colors.mintGreen)
                    }

                    Section("Thống kê tập luyện") {
                        let completed = client.sessions.filter { $0.isCompleted }.count
                        let remaining = client.remainingSessions

                        LabeledContent("Tổng buổi đã tập") {
                            Text("\(completed)")
                                .font(Theme.Fonts.headline())
                                .foregroundStyle(Theme.Colors.lavender)
                        }
                        LabeledContent("Buổi còn lại") {
                            Text("\(remaining)")
                                .font(Theme.Fonts.headline())
                                .foregroundStyle(remaining > 0 ? Theme.Colors.mintGreen : Theme.Colors.softPink)
                        }
                    }

                    if !client.notes.isEmpty {
                        Section("Ghi chú") {
                            Text(client.notes)
                                .font(Theme.Fonts.body())
                        }
                    }
                }
                .navigationTitle("Chỉ số")
                .profileToolbar()
            } else {
                ContentUnavailableView("Chưa có hồ sơ", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Liên hệ phòng gym để cập nhật thông tin"))
                    .navigationTitle("Chỉ số")
                    .profileToolbar()
            }
        }
    }
}

struct StatsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            CuteIconCircle(icon: icon, color: color, size: 36)

            Text(title)
                .font(Theme.Fonts.body())

            Spacer()

            Text(value)
                .font(Theme.Fonts.title3())
                .foregroundStyle(value == "—" ? Theme.Colors.textSecondary : color)
        }
        .padding(.vertical, 4)
    }
}
