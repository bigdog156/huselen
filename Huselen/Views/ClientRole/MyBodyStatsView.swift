import SwiftUI
import Charts

// MARK: - Chart Enums

enum BodyStatMetric: String, CaseIterable, Identifiable {
    case weight, waist, chest, hip
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight:     return "Cân nặng"
        case .waist:      return "Eo"
        case .chest:      return "Vòng 1"
        case .hip:        return "Hông"
        }
    }
    var unit: String {
        switch self {
        case .weight: return "kg"
        default:      return "cm"
        }
    }
    var color: Color {
        switch self {
        case .weight:     return Color.fitGreen
        case .waist:      return Color.fitCoral
        case .chest:      return Color.fitLavender
        case .hip:        return Color.fitBlue
        }
    }
    var lowerIsBetter: Bool { self == .waist || self == .hip }

    func value(from log: BodyStatLog) -> Double? {
        switch self {
        case .weight:     return log.weight
        case .waist:      return log.waist
        case .chest:      return log.chest
        case .hip:        return log.hip
        }
    }
}

enum StatRange: String, CaseIterable {
    case week = "7N"
    case month = "30N"
    case threeMonths = "3T"
    var days: Int {
        switch self {
        case .week:        return 7
        case .month:       return 30
        case .threeMonths: return 90
        }
    }
}

private extension View {
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}


struct MyBodyStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @State private var showUpdateSheet = false
    @State private var selectedMetric: BodyStatMetric = .weight
    @State private var selectedRange: StatRange = .month
    @State private var showingProfile = false
    @State private var showProgressPhotos = false

    private var myProfile: Client? { syncManager.clients.first }

    // MARK: - Stats

    private var completedSessions: Int {
        myProfile?.sessions.filter { $0.isCompleted }.count ?? 0
    }

    private var remainingSessions: Int {
        myProfile?.remainingSessions ?? 0
    }

    private var streakDays: Int {
        let cal = Calendar.current
        let sessions = myProfile?.sessions ?? []
        var streak = 0
        var checkDate = Date()
        for _ in 0..<60 {
            let hit = sessions.contains {
                cal.isDate($0.scheduledDate, inSameDayAs: checkDate) && $0.isCompleted
            }
            guard hit else { break }
            streak += 1
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    private var heroMessage: String {
        if completedSessions == 0 { return "Mới bắt đầu tập luyện" }
        if completedSessions < 10 { return "Đang tiến bộ tốt! 💪" }
        if completedSessions < 30 { return "Vận động viên nghiệp dư 🔥" }
        return "Chiến binh phòng gym! 🏆"
    }

    private var heroColors: [Color] {
        if completedSessions == 0 {
            return [Color(red: 0.439, green: 0.396, blue: 0.914), Color(red: 0.337, green: 0.341, blue: 0.831)]
        }
        if completedSessions < 10 {
            return [Color.fitGreen, Color.fitGreenDark]
        }
        return [Color(red: 0.851, green: 0.467, blue: 0.024), Color(red: 0.706, green: 0.322, blue: 0.008)]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                heroCard
                    .padding(.horizontal, 24)

                progressChartsSection
                    .padding(.horizontal, 24)

                bodyStatsSection
                    .padding(.horizontal, 24)

                progressPhotosSection
                    .padding(.horizontal, 24)

                trainingStatsSection
                    .padding(.horizontal, 24)

                ctaBanner
                    .padding(.horizontal, 24)

                Spacer(minLength: 32)
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .refreshable {
            await syncManager.refresh()
            await syncManager.fetchBodyStatLogs()
            await syncManager.fetchProgressPhotos()
        }
        .task {
            await syncManager.fetchBodyStatLogs()
            await syncManager.fetchProgressPhotos()
        }
        .sheet(isPresented: $showUpdateSheet) {
            UpdateBodyStatsSheet(client: myProfile)
        }
        .sheet(isPresented: $showProgressPhotos) {
            ProgressPhotosView()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Theo dõi tiến trình")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
                Text("Chỉ số")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
            }
            Spacer()
            avatarCircle
        }
    }

    private var avatarCircle: some View {
        let name = authManager.userProfile?.fullName ?? myProfile?.name ?? ""
        let initials = name.split(separator: " ").compactMap { $0.first }.suffix(2).map { String($0) }.joined()
        let display = initials.isEmpty ? "NH" : initials.uppercased()
        return Button { showingProfile = true } label: {
            if let urlStr = authManager.userProfile?.avatarUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    } else {
                        initialsCircle(display)
                    }
                }
            } else {
                initialsCircle(display)
            }
        }
        .sheet(isPresented: $showingProfile) { ProfileView() }
    }

    private func initialsCircle(_ text: String) -> some View {
        ZStack {
            Circle().fill(Color.fitGreen).frame(width: 44, height: 44)
            Text(text).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: heroColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    Image(systemName: "figure.run.circle")
                        .font(.system(size: 90))
                        .foregroundStyle(.white.opacity(0.07))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 20)
                )

            VStack(alignment: .leading, spacing: 4) {
                if let name = myProfile?.name, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Text(heroMessage)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(20)
        }
    }

    // MARK: - Progress Charts

    private var chartData: [BodyStatLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return syncManager.bodyStatLogs.filter {
            $0.loggedAt >= cutoff && selectedMetric.value(from: $0) != nil
        }
    }

    private func diffColor(_ diff: Double) -> Color {
        selectedMetric.lowerIsBetter
            ? (diff < 0 ? Color.fitGreen : Color.fitCoral)
            : (diff > 0 ? Color.fitGreen : Color.fitCoral)
    }

    private var progressChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LỊCH SỬ TIẾN TRÌNH")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)

            VStack(spacing: 14) {
                // Range picker
                HStack(spacing: 0) {
                    ForEach(StatRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedRange = range }
                        } label: {
                            Text(range.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(selectedRange == range ? .white : Color.fitTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedRange == range ? Color.fitGreen : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(.systemGray6)))

                // Metric chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BodyStatMetric.allCases) { metric in
                            let selected = selectedMetric == metric
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { selectedMetric = metric }
                            } label: {
                                Text(metric.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selected ? metric.color : Color.fitTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selected ? metric.color.opacity(0.13) : Color(.systemGray6))
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(selected ? metric.color.opacity(0.45) : Color.clear, lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                // Chart or empty state
                if chartData.count < 2 {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 34))
                            .foregroundStyle(Color.fitTextTertiary.opacity(0.5))
                        Text("Chưa đủ dữ liệu\nCập nhật chỉ số mỗi ngày để xem biểu đồ!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.fitTextTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    let latestVal = chartData.last.flatMap { selectedMetric.value(from: $0) } ?? 0
                    let firstVal  = chartData.first.flatMap { selectedMetric.value(from: $0) } ?? 0
                    let diff = latestVal - firstVal

                    // Summary row
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f %@", latestVal, selectedMetric.unit))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedMetric.color)
                            Text("Hiện tại")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.fitTextTertiary)
                        }
                        Spacer()
                        if abs(diff) > 0.01 {
                            HStack(spacing: 4) {
                                Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 10, weight: .bold))
                                Text(String(format: "%+.1f %@", diff, selectedMetric.unit))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(diffColor(diff))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(diffColor(diff).opacity(0.12)))
                        }
                    }

                    // Line + Area chart
                    Chart(chartData) { log in
                        if let val = selectedMetric.value(from: log) {
                            AreaMark(
                                x: .value("Ngày", log.loggedAt),
                                y: .value(selectedMetric.displayName, val)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [selectedMetric.color.opacity(0.22), selectedMetric.color.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Ngày", log.loggedAt),
                                y: .value(selectedMetric.displayName, val)
                            )
                            .foregroundStyle(selectedMetric.color)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            PointMark(
                                x: .value("Ngày", log.loggedAt),
                                y: .value(selectedMetric.displayName, val)
                            )
                            .foregroundStyle(selectedMetric.color)
                            .symbolSize(25)
                        }
                    }
                    .frame(height: 150)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date, format: .dateTime.day().month())
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.fitTextTertiary)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                                .foregroundStyle(Color.fitTextTertiary.opacity(0.25))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(String(format: "%.0f", v))
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.fitTextTertiary)
                                }
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                                .foregroundStyle(Color.fitTextTertiary.opacity(0.25))
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard))
        }
    }

    // MARK: - Body Stats

    private var bodyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHỈ SỐ CƠ THỂ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)

            VStack(spacing: 0) {
                statRow(
                    icon: "ruler.fill",
                    iconColor: Color.fitIndigo,
                    iconBg: Color(red: 0.937, green: 0.937, blue: 0.988),
                    title: "Chiều cao",
                    value: myProfile.flatMap { $0.height > 0 ? String(format: "%.1f cm", $0.height) : nil }
                )
                Divider().padding(.leading, 54)
                statRow(
                    icon: "scalemass.fill",
                    iconColor: Color.fitGreen,
                    iconBg: Color(red: 0.941, green: 0.992, blue: 0.957),
                    title: "Cân nặng",
                    value: myProfile.flatMap { $0.weight > 0 ? String(format: "%.1f kg", $0.weight) : nil }
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard)
            )

            Text("SỐ ĐO CƠ THỂ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)
                .padding(.top, 8)

            VStack(spacing: 0) {
                measurementRow(title: "Cổ", value: myProfile?.neck, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Vai", value: myProfile?.shoulder, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Cánh tay", value: myProfile?.arm, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Vòng 1", value: myProfile?.chest, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Eo", value: myProfile?.waist, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Hông", value: myProfile?.hip, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Đùi", value: myProfile?.thigh, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Bắp chân", value: myProfile?.calf, unit: "cm")
                Divider().padding(.leading, 54)
                measurementRow(title: "Vòng 3", value: myProfile?.lowerHip, unit: "cm")
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.fitCard)
            )
        }
    }

    private func measurementRow(title: String, value: Double?, unit: String) -> some View {
        let display = value.flatMap { $0 > 0 ? String(format: "%.1f %@", $0, unit) : nil }
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.941, green: 0.957, blue: 0.992))
                    .frame(width: 36, height: 36)
                Image(systemName: "lines.measurement.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.fitIndigo)
            }

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()

            Text(display ?? "Chưa cập nhật")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(display != nil ? Color.fitTextPrimary : Color.fitTextTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { showUpdateSheet = true }
    }

    private func statRow(icon: String, iconColor: Color, iconBg: Color,
                         title: String, value: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.fitTextPrimary)

            Spacer()

            Text(value ?? "Chưa cập nhật")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(value != nil ? Color.fitTextPrimary : Color.fitTextTertiary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { showUpdateSheet = true }
    }

    // MARK: - Progress Photos Section

    private var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ẢNH TIẾN TRÌNH")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.fitTextTertiary)
                    .tracking(1)
                Spacer()
                Button {
                    showProgressPhotos = true
                } label: {
                    Text("Xem tất cả →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                }
            }

            if syncManager.progressPhotos.isEmpty {
                Button { showProgressPhotos = true } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 30))
                            .foregroundStyle(Color.fitTextTertiary.opacity(0.5))
                        Text("Chụp ảnh tiến trình đầu tiên!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.fitCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.fitTextTertiary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6]))
                            )
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button { showProgressPhotos = true } label: {
                    HStack(spacing: 8) {
                        ForEach(Array(syncManager.progressPhotos.prefix(4))) { photo in
                            AsyncImage(url: URL(string: photo.photoUrl)) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFill()
                                } else {
                                    Color(.systemGray5)
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        if syncManager.progressPhotos.count > 4 {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 72, height: 72)
                                Text("+\(syncManager.progressPhotos.count - 4)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.fitTextSecondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.fitCard))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Training Stats

    private var trainingStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THỐNG KÊ TẬP LUYỆN")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.fitTextTertiary)
                .tracking(1)

            HStack(spacing: 10) {
                trainingStat(
                    icon: "checkmark.circle",
                    value: "\(completedSessions)",
                    label: "Đã tập",
                    color: Color.fitCoral,
                    bg: Color(red: 1.0, green: 0.945, blue: 0.945)
                )
                trainingStat(
                    icon: "bolt.fill",
                    value: "\(remainingSessions)",
                    label: "Còn lại",
                    color: Color.fitGreen,
                    bg: Color(red: 0.941, green: 0.992, blue: 0.957)
                )
                trainingStat(
                    emoji: "🔥",
                    value: "\(streakDays)",
                    label: "Streak",
                    color: Color.fitOrange,
                    bg: Color(red: 1.0, green: 0.969, blue: 0.929)
                )
            }
        }
    }

    private func trainingStat(icon: String? = nil, emoji: String? = nil,
                               value: String, label: String,
                               color: Color, bg: Color) -> some View {
        VStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(height: 20)
            } else if let emoji {
                Text(emoji).font(.system(size: 18)).frame(height: 20)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(bg))
    }

    // MARK: - CTA Banner

    private var ctaBanner: some View {
        Button { showUpdateSheet = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.fitIndigo)
                Text("Cập nhật chỉ số để theo dõi tiến trình!")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.fitGreen)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.fitCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color(red: 0.851, green: 0.929, blue: 0.851), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Update Body Stats Sheet

struct UpdateBodyStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    let client: Client?

    @State private var height     = ""
    @State private var weight     = ""
    @State private var neck       = ""
    @State private var shoulder   = ""
    @State private var arm        = ""
    @State private var chest      = ""
    @State private var waist      = ""
    @State private var hip        = ""
    @State private var thigh      = ""
    @State private var calf       = ""
    @State private var lowerHip   = ""
    @State private var isSaving   = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Chỉ số cơ thể") {
                    statsField(label: "Chiều cao", icon: "ruler.fill", unit: "cm", text: $height)
                    statsField(label: "Cân nặng", icon: "scalemass.fill", unit: "kg", text: $weight)
                }

                Section("Số đo cơ thể (cm)") {
                    statsField(label: "Cổ", icon: "lines.measurement.horizontal", unit: "cm", text: $neck)
                    statsField(label: "Vai", icon: "lines.measurement.horizontal", unit: "cm", text: $shoulder)
                    statsField(label: "Cánh tay", icon: "lines.measurement.horizontal", unit: "cm", text: $arm)
                    statsField(label: "Vòng 1", icon: "lines.measurement.horizontal", unit: "cm", text: $chest)
                    statsField(label: "Eo", icon: "lines.measurement.horizontal", unit: "cm", text: $waist)
                    statsField(label: "Hông", icon: "lines.measurement.horizontal", unit: "cm", text: $hip)
                    statsField(label: "Đùi", icon: "lines.measurement.horizontal", unit: "cm", text: $thigh)
                    statsField(label: "Bắp chân", icon: "lines.measurement.horizontal", unit: "cm", text: $calf)
                    statsField(label: "Vòng 3", icon: "lines.measurement.horizontal", unit: "cm", text: $lowerHip)
                }
            }
            .navigationTitle("Cập nhật chỉ số")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .font(.system(size: 15, weight: .semibold))
                        .disabled(isSaving)
                }
            }
            .onAppear { loadValues() }
        }
        .presentationDetents([.large])
    }

    private func statsField(label: String, icon: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            TextField(unit, text: text)
                .decimalKeyboard()
                .multilineTextAlignment(.trailing)
        }
    }

    private func loadValues() {
        guard let c = client else { return }
        height     = c.height > 0     ? String(format: "%.1f", c.height)     : ""
        weight     = c.weight > 0     ? String(format: "%.1f", c.weight)     : ""
        neck       = c.neck > 0       ? String(format: "%.1f", c.neck)       : ""
        shoulder   = c.shoulder > 0   ? String(format: "%.1f", c.shoulder)   : ""
        arm        = c.arm > 0        ? String(format: "%.1f", c.arm)        : ""
        chest      = c.chest > 0      ? String(format: "%.1f", c.chest)      : ""
        waist      = c.waist > 0      ? String(format: "%.1f", c.waist)      : ""
        hip        = c.hip > 0        ? String(format: "%.1f", c.hip)        : ""
        thigh      = c.thigh > 0      ? String(format: "%.1f", c.thigh)      : ""
        calf       = c.calf > 0       ? String(format: "%.1f", c.calf)       : ""
        lowerHip   = c.lowerHip > 0   ? String(format: "%.1f", c.lowerHip)   : ""
    }

    private func save() {
        guard let c = client else { return }
        isSaving = true
        if let v = Double(height)     { c.height     = v }
        if let v = Double(weight)     { c.weight     = v }
        if let v = Double(neck)       { c.neck       = v }
        if let v = Double(shoulder)   { c.shoulder   = v }
        if let v = Double(arm)        { c.arm        = v }
        if let v = Double(chest)      { c.chest      = v }
        if let v = Double(waist)      { c.waist      = v }
        if let v = Double(hip)        { c.hip        = v }
        if let v = Double(thigh)      { c.thigh      = v }
        if let v = Double(calf)       { c.calf       = v }
        if let v = Double(lowerHip)   { c.lowerHip   = v }
        Task {
            await syncManager.updateClient(c)
            await syncManager.saveBodyStatLog(from: c)
            isSaving = false
            dismiss()
        }
    }
}
