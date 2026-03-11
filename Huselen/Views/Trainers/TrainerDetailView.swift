import SwiftUI

struct TrainerDetailView: View {
    var trainer: Trainer
    @State private var showingEditForm = false

    var body: some View {
        List {
            Section("Thông tin cá nhân") {
                LabeledContent("Tên", value: trainer.name)
                if !trainer.phone.isEmpty {
                    LabeledContent("Số điện thoại", value: trainer.phone)
                }
                if !trainer.specialization.isEmpty {
                    LabeledContent("Chuyên môn", value: trainer.specialization)
                }
                LabeledContent("Kinh nghiệm", value: "\(trainer.experienceYears) năm")
                LabeledContent("Trạng thái", value: trainer.isActive ? "Đang hoạt động" : "Nghỉ")
            }

            if !trainer.bio.isEmpty {
                Section("Giới thiệu") {
                    Text(trainer.bio)
                        .font(.body)
                }
            }

            Section("Thống kê") {
                LabeledContent("Tổng buổi đã dạy", value: "\(trainer.completedSessionsCount)")
                LabeledContent("Tổng doanh thu") {
                    Text(formatVND(trainer.totalRevenue))
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }
                LabeledContent("Số khách hàng") {
                    let clientCount = Set(trainer.purchases.compactMap { $0.client?.id }).count
                    Text("\(clientCount)")
                }
            }

            Section("Lịch dạy sắp tới") {
                let upcoming = trainer.sessions
                    .filter { !$0.isCompleted && $0.scheduledDate > Date() }
                    .sorted { $0.scheduledDate < $1.scheduledDate }
                    .prefix(5)

                if upcoming.isEmpty {
                    Text("Không có lịch sắp tới")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(upcoming)) { session in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.client?.name ?? "N/A")
                                    .font(.headline)
                                Text(session.scheduledDate, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(session.scheduledDate, style: .time)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(trainer.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sửa") {
                    showingEditForm = true
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            TrainerFormView(trainer: trainer)
        }
    }
}

func formatVND(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "VND"
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))đ"
}
