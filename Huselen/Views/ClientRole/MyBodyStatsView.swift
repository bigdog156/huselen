import SwiftUI
import Charts

struct MyBodyStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager

    @State private var showUpdateSheet = false
    @State private var showProgressPhotos = false
    @State private var showAllHistory = false

    private var myProfile: Client? { syncManager.clients.first }

    private var completedSessions: Int {
        myProfile?.sessions.filter { $0.isCompleted }.count ?? 0
    }

    private var remainingSessions: Int {
        myProfile?.remainingSessions ?? 0
    }

    private var recentLogs: [BodyStatLog] {
        syncManager.bodyStatLogs.suffix(10).reversed()
    }

    private var last30DaysWeightLogs: [BodyStatLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return syncManager.bodyStatLogs
            .filter { $0.loggedAt >= cutoff && $0.weight != nil }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    private var last30DaysBodyFatLogs: [BodyStatLog] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        return syncManager.bodyStatLogs
            .filter { $0.loggedAt >= cutoff && $0.bodyFat != nil }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    var body: some View {
        NavigationStack {
        ScrollView {
            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                if let client = myProfile {
                    VStack(spacing: 16) {
                        profileCard(client)
                            .padding(.horizontal, 24)

                        statsGrid(client)
                            .padding(.horizontal, 24)

                        trainingStatsRow
                            .padding(.horizontal, 24)

                        updateButton
                            .padding(.horizontal, 24)

                        measurementsSection(client)
                            .padding(.horizontal, 24)

                        if !recentLogs.isEmpty {
                            weightHistorySection
                                .padding(.horizontal, 24)
                        }

                        bodyFatChartSection
                            .padding(.horizontal, 24)

                        progressPhotosSection
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                } else {
                    ContentUnavailableView(
                        "Chưa có hồ sơ",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Liên hệ phòng gym để cập nhật thông tin")
                    )
                    .padding(.top, 40)
                }
            }
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
        .navigationDestination(isPresented: $showProgressPhotos) {
            ProgressPhotosView()
        }
        .sheet(isPresented: $showAllHistory) {
            BodyStatHistorySheet(logs: syncManager.bodyStatLogs)
        }
        } // NavigationStack
    }

    // MARK: - Header

    private var headerView: some View {
        ClientHeaderView(subtitle: "Theo dõi sức khỏe", title: "Chỉ số")
    }

    // MARK: - Profile Card

    private func profileCard(_ client: Client) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.fitGreen.opacity(0.12))
                    .frame(width: 60, height: 60)

                if let urlStr = authManager.userProfile?.avatarUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            initialsView(client.name)
                        }
                    }
                } else {
                    initialsView(client.name)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
                if !client.goal.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.fitGreen)
                        Text(client.goal)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.fitTextSecondary)
                    }
                }
                if client.height > 0 {
                    Text(String(format: "Chiều cao: %.0f cm", client.height))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    private func initialsView(_ name: String) -> some View {
        let parts = name.split(separator: " ")
        let initials = parts.count >= 2
            ? String((parts.first?.prefix(1) ?? "") + (parts.last?.prefix(1) ?? "")).uppercased()
            : String(name.prefix(2)).uppercased()
        return Text(initials)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(Color.fitGreen)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ client: Client) -> some View {
        HStack(spacing: 10) {
            statCard(
                icon: "scalemass.fill",
                value: client.weight > 0 ? String(format: "%.1f", client.weight) : "—",
                unit: "kg",
                label: "Cân nặng",
                color: Color.fitIndigo
            )
            statCard(
                icon: "drop.fill",
                value: client.bodyFat > 0 ? String(format: "%.1f", client.bodyFat) : "—",
                unit: "%",
                label: "Mỡ cơ thể",
                color: Color.fitOrange
            )
            statCard(
                icon: "figure.strengthtraining.traditional",
                value: client.muscleMass > 0 ? String(format: "%.1f", client.muscleMass) : "—",
                unit: "kg",
                label: "Cơ bắp",
                color: Color.fitGreen
            )
        }
    }

    private func statCard(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(height: 22)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(value == "—" ? Color.fitTextTertiary : color)
                if value != "—" {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(color.opacity(0.7))
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Training Stats

    private var trainingStatsRow: some View {
        HStack(spacing: 10) {
            trainingStat(value: "\(completedSessions)", label: "Buổi đã tập", icon: "checkmark.circle.fill", color: Color.fitGreen)
            trainingStat(value: "\(remainingSessions)", label: "Buổi còn lại", icon: "calendar.badge.clock", color: Color.fitIndigo)
        }
    }

    private func trainingStat(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fitTextPrimary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.fitTextSecondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: - Update Button

    private var updateButton: some View {
        Button {
            showUpdateSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 15, weight: .semibold))
                Text("Cập nhật chỉ số")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color.fitGreen, Color.fitGreenDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Measurements Section

    private func measurementsSection(_ client: Client) -> some View {
        let measurements: [(String, Double, String)] = [
            ("Cổ", client.neck, "cm"),
            ("Vai", client.shoulder, "cm"),
            ("Cánh tay", client.arm, "cm"),
            ("Vòng 1", client.chest, "cm"),
            ("Eo", client.waist, "cm"),
            ("Hông", client.hip, "cm"),
            ("Đùi", client.thigh, "cm"),
            ("Bắp chân", client.calf, "cm"),
            ("Vòng 3", client.lowerHip, "cm"),
        ].filter { $0.1 > 0 }

        return Group {
            if !measurements.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Số đo cơ thể")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fitTextSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(measurements, id: \.0) { name, value, unit in
                            measurementCell(name: name, value: value, unit: unit)
                        }
                    }
                }
            }
        }
    }

    private func measurementCell(name: String, value: Double, unit: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.fitTextTertiary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitTextPrimary)
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.fitCard)
        )
    }

    // MARK: - Weight Trend Chart

    private var weightTrendChart: some View {
        Group {
            if last30DaysWeightLogs.count >= 2 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Xu hướng cân nặng (30 ngày)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fitTextTertiary)

                    Chart(last30DaysWeightLogs, id: \.id) { log in
                        if let weight = log.weight {
                            LineMark(
                                x: .value("Date", log.loggedAt),
                                y: .value("Cân nặng", weight)
                            )
                            .foregroundStyle(Color.fitIndigo)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", log.loggedAt),
                                y: .value("Cân nặng", weight)
                            )
                            .foregroundStyle(Color.fitIndigo.opacity(0.1))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", log.loggedAt),
                                y: .value("Cân nặng", weight)
                            )
                            .foregroundStyle(Color.fitIndigo)
                            .symbolSize(24)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 140)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                )
            }
        }
    }

    // MARK: - Weight History Section

    private var weightHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lịch sử cân nặng")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
                Spacer()
                Button {
                    showAllHistory = true
                } label: {
                    Text("Xem tất cả →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                }
            }

            weightTrendChart

            let logsWithWeight = recentLogs.filter { $0.weight != nil }

            if logsWithWeight.isEmpty {
                Text("Chưa có lịch sử")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fitTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.fitCard))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(logsWithWeight.prefix(5).enumerated()), id: \.element.id) { idx, log in
                        if idx > 0 { Divider().padding(.leading, 48) }
                        logRow(log)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                )
            }
        }
    }

    private func logRow(_ log: BodyStatLog) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.fitIndigo.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fitIndigo)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(log.loggedAt.formatted(.dateTime.day().month().year()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextPrimary)
                if let bf = log.bodyFat {
                    Text(String(format: "Mỡ: %.1f%%", bf))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitTextTertiary)
                }
            }
            Spacer()
            if let w = log.weight {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", w))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fitIndigo)
                    Text("kg")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fitIndigo.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Body Fat Chart Section

    private var bodyFatChartSection: some View {
        Group {
            if last30DaysBodyFatLogs.count >= 2 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Xu hướng mỡ cơ thể (30 ngày)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fitTextSecondary)

                    Chart(last30DaysBodyFatLogs, id: \.id) { log in
                        if let bodyFat = log.bodyFat {
                            LineMark(
                                x: .value("Date", log.loggedAt),
                                y: .value("Mỡ cơ thể", bodyFat)
                            )
                            .foregroundStyle(Color.fitOrange)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", log.loggedAt),
                                y: .value("Mỡ cơ thể", bodyFat)
                            )
                            .foregroundStyle(Color.fitOrange.opacity(0.1))
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", log.loggedAt),
                                y: .value("Mỡ cơ thể", bodyFat)
                            )
                            .foregroundStyle(Color.fitOrange)
                            .symbolSize(24)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 140)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                    )
                }
            }
        }
    }

    // MARK: - Progress Photos Section

    private var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ảnh tiến trình")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.fitTextSecondary)
                Spacer()
                NavigationLink(destination: ProgressPhotosView()) {
                    Text("Xem tất cả →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fitGreen)
                }
            }

            let photos = syncManager.progressPhotos.prefix(4)

            if photos.isEmpty {
                Button {
                    showProgressPhotos = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.fitGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Thêm ảnh tiến trình")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.fitTextPrimary)
                            Text("Ghi lại hành trình luyện tập của bạn")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.fitTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.fitTextTertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.fitGreenSoft)
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(photos)) { photo in
                        if let url = URL(string: photo.photoUrl) {
                            AsyncImage(url: url) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().scaledToFill()
                                } else {
                                    Color.fitCard
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    // Fill remaining slots
                    if photos.count < 4 {
                        ForEach(0..<(4 - photos.count), id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.fitCard)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Body Stat History Sheet

struct BodyStatHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let logs: [BodyStatLog]

    private var sortedLogs: [BodyStatLog] {
        logs.sorted { $0.loggedAt > $1.loggedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedLogs) { log in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(log.loggedAt.formatted(.dateTime.day().month().year()))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fitTextPrimary)

                        HStack(spacing: 16) {
                            if let w = log.weight {
                                logStat(label: "Cân nặng", value: String(format: "%.1f kg", w))
                            }
                            if let bf = log.bodyFat {
                                logStat(label: "Mỡ cơ thể", value: String(format: "%.1f%%", bf))
                            }
                            if let mm = log.muscleMass {
                                logStat(label: "Cơ bắp", value: String(format: "%.1f kg", mm))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Lịch sử chỉ số")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .overlay {
                if sortedLogs.isEmpty {
                    ContentUnavailableView("Chưa có lịch sử", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }

    private func logStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.fitTextTertiary)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.fitTextPrimary)
        }
    }
}

// MARK: - Decimal Keyboard Helper

private extension View {
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

// MARK: - Update Body Stats Sheet

struct UpdateBodyStatsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    let client: Client?

    @State private var height     = ""
    @State private var weight     = ""
    @State private var bodyFat    = ""
    @State private var muscleMass = ""
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
                    statsField(label: "Tỷ lệ mỡ", icon: "drop.fill", unit: "%", text: $bodyFat)
                    statsField(label: "Khối lượng cơ", icon: "figure.strengthtraining.traditional", unit: "kg", text: $muscleMass)
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
        bodyFat    = c.bodyFat > 0    ? String(format: "%.1f", c.bodyFat)    : ""
        muscleMass = c.muscleMass > 0 ? String(format: "%.1f", c.muscleMass) : ""
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
        if let v = Double(bodyFat)    { c.bodyFat    = v }
        if let v = Double(muscleMass) { c.muscleMass = v }
        if let v = Double(neck)       { c.neck       = v }
        if let v = Double(shoulder)   { c.shoulder   = v }
        if let v = Double(arm)        { c.arm        = v }
        if let v = Double(chest)      { c.chest      = v }
        if let v = Double(waist)      { c.waist      = v }
        if let v = Double(hip)        { c.hip        = v }
        if let v = Double(thigh)      { c.thigh      = v }
        if let v = Double(calf)       { c.calf       = v }
        if let v = Double(lowerHip)   { c.lowerHip   = v }
        Task { @MainActor in
            await syncManager.updateClient(c)
            await syncManager.saveBodyStatLog(from: c)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Stats Row (kept for backward compatibility)

struct StatsRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(value == "—" ? .secondary : color)
        }
        .padding(.vertical, 4)
    }
}
