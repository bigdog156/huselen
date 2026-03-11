import SwiftUI

struct PTStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var sessions: [TrainingGymSession] { syncManager.sessions }
    private var purchases: [PackagePurchase] { syncManager.purchases }

    var completedCount: Int {
        sessions.filter { $0.isCompleted }.count
    }

    var thisMonthCompleted: Int {
        let calendar = Calendar.current
        return sessions.filter {
            $0.isCompleted && calendar.isDate($0.scheduledDate, equalTo: Date(), toGranularity: .month)
        }.count
    }

    var thisMonthRevenue: Double {
        let calendar = Calendar.current
        return purchases.filter {
            calendar.isDate($0.purchaseDate, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.price }
    }

    var totalRevenue: Double {
        purchases.reduce(0) { $0 + $1.price }
    }

    var uniqueClientCount: Int {
        Set(purchases.compactMap { $0.client?.id }).count
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Tháng này") {
                    HStack(spacing: 16) {
                        StatCard(title: "Buổi đã dạy", value: "\(thisMonthCompleted)", color: .blue)
                        StatCard(title: "Doanh thu", value: formatVND(thisMonthRevenue), color: .green)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Tổng quan") {
                    LabeledContent("Tổng buổi đã dạy") {
                        Text("\(completedCount)")
                            .fontWeight(.semibold)
                    }
                    LabeledContent("Tổng doanh thu") {
                        Text(formatVND(totalRevenue))
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    LabeledContent("Số học viên") {
                        Text("\(uniqueClientCount)")
                            .fontWeight(.semibold)
                    }
                }

                Section("Lịch sử buổi dạy gần đây") {
                    let recent = sessions.filter { $0.isCompleted }
                        .sorted { $0.scheduledDate > $1.scheduledDate }
                        .prefix(15)

                    if recent.isEmpty {
                        Text("Chưa có buổi dạy nào")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(recent)) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.client?.name ?? "N/A")
                                        .font(.subheadline)
                                    Text(session.scheduledDate, format: .dateTime.day().month().year())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(session.duration) phút")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Thống kê")
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }
}
