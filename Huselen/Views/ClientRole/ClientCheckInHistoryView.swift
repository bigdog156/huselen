import SwiftUI

struct ClientCheckInHistoryView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSession: TrainingGymSession?

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "d"
        return df
    }()

    private static let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = "MMM"
        return df
    }()

    private var allCheckIns: [TrainingGymSession] {
        syncManager.sessions
            .filter { $0.clientCheckInPhotoURL != nil || $0.isCompleted }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if allCheckIns.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.fitTextTertiary)
                        Text("Chưa có lịch sử check-in")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        // Stats row
                        HStack(spacing: 10) {
                            statsCard(value: "\(allCheckIns.count)", label: "Tổng check-in", color: Color.fitGreen)
                            statsCard(value: "\(allCheckIns.filter { $0.clientCheckInPhotoURL != nil }.count)", label: "Có ảnh", color: Color.fitIndigo)
                            statsCard(value: "\(allCheckIns.filter { $0.isCompleted }.count)", label: "Hoàn thành", color: Color.fitOrange)
                        }
                        .padding(.horizontal, 16)

                        // Photo grid
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(allCheckIns) { session in
                                Button { selectedSession = session } label: {
                                    checkInCellContent(session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Theme.Colors.screenBackground)
            .navigationTitle("Lịch sử check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .sheet(item: $selectedSession) { s in
                checkInDetail(s)
            }
        }
    }

    // MARK: - Cell Content (no sheet here)

    private func checkInCellContent(_ session: TrainingGymSession) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { geo in
                Group {
                    if let urlStr = session.clientCheckInPhotoURL, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                photoCellPlaceholder
                            }
                        }
                    } else {
                        photoCellPlaceholder
                    }
                }
                .frame(width: geo.size.width, height: geo.size.width)
                .clipped()
            }
            .aspectRatio(1, contentMode: .fit)

            // Date overlay
            VStack(alignment: .leading, spacing: 1) {
                Text(dateDayLabel(session.scheduledDate))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text(dateMonthLabel(session.scheduledDate))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(maxHeight: .infinity, alignment: .bottom)
            )

            // Completed badge
            if session.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.fitGreen)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .accessibilityLabel("Check-in ngày \(session.scheduledDate.formatted(.dateTime.day().month()))")
        .accessibilityHint("Nhấn để xem chi tiết")
    }

    private var photoCellPlaceholder: some View {
        ZStack {
            Color.fitCard
            Image(systemName: "camera.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color.fitTextTertiary.opacity(0.5))
        }
    }

    // MARK: - Detail Sheet

    private func checkInDetail(_ session: TrainingGymSession) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.fitTextTertiary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            if let urlStr = session.clientCheckInPhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        ProgressView()
                    }
                }
                .padding(.horizontal, 16)
            }

            VStack(spacing: 8) {
                Text(session.scheduledDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.fitTextPrimary)
                    .multilineTextAlignment(.center)

                Text("\(session.scheduledDate.formatted(date: .omitted, time: .shortened)) – \(session.endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)

                if let t = session.clientCheckInTime {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fitIndigo)
                        Text("Check-in lúc \(t.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.fitIndigo)
                    }
                }

                if session.isCompleted {
                    Label("Buổi tập hoàn thành", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                }

                Text("PT: \(session.trainer?.name ?? "N/A")")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.fitTextTertiary)
            }
            .padding(20)

            Spacer()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Stats Card

    private func statsCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Date Helpers (static formatters — no alloc per render)

    private func dateDayLabel(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func dateMonthLabel(_ date: Date) -> String {
        Self.monthFormatter.string(from: date)
    }
}
