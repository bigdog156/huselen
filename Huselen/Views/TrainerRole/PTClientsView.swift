import SwiftUI

struct PTClientsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var clients: [Client] {
        syncManager.clients.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if clients.isEmpty {
                    ContentUnavailableView("Chưa có học viên", systemImage: "person.2", description: Text("Học viên sẽ xuất hiện khi được admin phân bổ gói PT"))
                } else {
                    ForEach(clients) { client in
                        NavigationLink(destination: PTClientDetailView(client: client)) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(client.name)
                                        .font(.headline)
                                    if !client.goal.isEmpty {
                                        Text(client.goal)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(client.remainingSessions)")
                                        .font(.headline)
                                        .foregroundStyle(client.remainingSessions > 0 ? .green : .red)
                                    Text("buổi còn")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Học viên")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}

struct PTClientDetailView: View {
    let client: Client

    var body: some View {
        List {
            Section("Thông tin") {
                LabeledContent("Tên", value: client.name)
                if !client.phone.isEmpty {
                    LabeledContent("SĐT", value: client.phone)
                }
            }

            Section("Chỉ số cơ thể") {
                if client.weight > 0 {
                    LabeledContent("Cân nặng", value: String(format: "%.1f kg", client.weight))
                }
                if client.bodyFat > 0 {
                    LabeledContent("Tỷ lệ mỡ", value: String(format: "%.1f%%", client.bodyFat))
                }
                if client.muscleMass > 0 {
                    LabeledContent("Khối lượng cơ", value: String(format: "%.1f kg", client.muscleMass))
                }
            }

            if !client.goal.isEmpty {
                Section("Mục tiêu") {
                    Text(client.goal)
                }
            }

            Section("Gói PT đang sử dụng") {
                let activePurchases = client.purchases.filter { !$0.isExpired && !$0.isFullyUsed }
                if activePurchases.isEmpty {
                    Text("Không có gói đang hoạt động")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(activePurchases) { purchase in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(purchase.package?.name ?? "Gói PT")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            HStack {
                                Text("Còn \(purchase.remainingSessions)/\(purchase.totalSessions) buổi")
                                    .font(.caption)
                                Spacer()
                                Text("HSD: \(purchase.expiryDate, format: .dateTime.day().month().year())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(purchase.usedSessions), total: Double(purchase.totalSessions))
                                .tint(purchase.remainingSessions > 3 ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Lịch sử tập") {
                let completed = client.sessions.filter { $0.isCompleted }
                    .sorted { $0.scheduledDate > $1.scheduledDate }
                    .prefix(10)

                if completed.isEmpty {
                    Text("Chưa có buổi tập nào")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(completed)) { session in
                        HStack {
                            Text(session.scheduledDate, format: .dateTime.day().month().year())
                                .font(.subheadline)
                            Spacer()
                            Text("\(session.duration) phút")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .navigationTitle(client.name)
    }
}
