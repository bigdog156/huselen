import SwiftUI
import Auth
internal import Combine

struct PTAttendanceView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(AuthManager.self) private var authManager
    @State private var wifiChecker = WiFiChecker()

    private var currentTrainer: Trainer? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return syncManager.trainers.first { $0.profileId == userId }
    }

    private var activeAttendance: TrainerAttendance? {
        guard let trainer = currentTrainer else { return nil }
        return syncManager.activeAttendance(for: trainer)
    }

    private var myAttendances: [TrainerAttendance] {
        guard let trainer = currentTrainer else { return [] }
        return syncManager.attendances
            .filter { $0.trainer?.id == trainer.id }
            .sorted { $0.checkInTime > $1.checkInTime }
    }

    private var todayAttendances: [TrainerAttendance] {
        let calendar = Calendar.current
        return myAttendances.filter { calendar.isDateInToday($0.checkInTime) }
    }

    private var todayTotalHours: TimeInterval {
        todayAttendances.compactMap { $0.duration }.reduce(0, +)
    }

    private var hasWiFiRestriction: Bool {
        !syncManager.gymWiFiSSIDs.isEmpty
    }

    @State private var notes = ""
    @State private var isProcessing = false
    @State private var showCheckInCamera = false
    @State private var showCheckOutCamera = false
    @State private var capturedPhotoData: Data?
    @State private var wifiStatus: WiFiStatus = .checking
    @State private var showWiFiAlert = false

    enum WiFiStatus {
        case checking, connected, notConnected, noRestriction
    }

    var body: some View {
        NavigationStack {
            List {
                // WiFi status banner
                if hasWiFiRestriction {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: wifiStatusIcon)
                                .foregroundStyle(wifiStatusColor)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wifiStatusText)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("WiFi yêu cầu: \(syncManager.gymWiFiSSIDs.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if wifiStatus != .checking {
                                Button {
                                    Task { await checkWiFi() }
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }

                // Check-in / Check-out Section
                Section {
                    if let active = activeAttendance {
                        checkedInSection(active)
                    } else {
                        notCheckedInSection
                    }
                }

                // Today summary
                Section("Hôm nay") {
                    if todayAttendances.isEmpty {
                        Text("Chưa có lần check-in nào")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label("Tổng giờ làm", systemImage: "clock")
                            Spacer()
                            Text(formatDuration(todayTotalHours))
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }

                        ForEach(todayAttendances) { attendance in
                            AttendanceRow(attendance: attendance)
                        }
                    }
                }

                // History
                Section("Lịch sử gần đây") {
                    let history = myAttendances.filter { !Calendar.current.isDateInToday($0.checkInTime) }.prefix(20)
                    if history.isEmpty {
                        Text("Chưa có lịch sử")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(history)) { attendance in
                            AttendanceRow(attendance: attendance, showDate: true)
                        }
                    }
                }
            }
            .navigationTitle("Chấm công")
            .refreshable {
                await syncManager.refresh()
                await checkWiFi()
            }
            .profileToolbar()
            .task {
                await checkWiFi()
            }
            .fullScreenCover(isPresented: $showCheckInCamera) {
                CameraCaptureView { data in
                    capturedPhotoData = data
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showCheckOutCamera) {
                CameraCaptureView { data in
                    guard let active = activeAttendance else { return }
                    Task {
                        isProcessing = true
                        await syncManager.checkOut(active, photoData: data)
                        isProcessing = false
                    }
                }
                .ignoresSafeArea()
            }
            .alert("Không đúng WiFi phòng tập", isPresented: $showWiFiAlert) {
                Button("OK") {}
            } message: {
                Text("Bạn cần kết nối WiFi của phòng tập để chấm công: \(syncManager.gymWiFiSSIDs.joined(separator: ", "))")
            }
        }
    }

    // MARK: - WiFi Status Helpers

    private var wifiStatusIcon: String {
        switch wifiStatus {
        case .checking: "wifi"
        case .connected, .noRestriction: "wifi"
        case .notConnected: "wifi.slash"
        }
    }

    private var wifiStatusColor: Color {
        switch wifiStatus {
        case .checking: .secondary
        case .connected, .noRestriction: .green
        case .notConnected: .red
        }
    }

    private var wifiStatusText: String {
        switch wifiStatus {
        case .checking: "Đang kiểm tra WiFi..."
        case .connected: "Đã kết nối WiFi phòng tập"
        case .notConnected: "Chưa kết nối WiFi phòng tập"
        case .noRestriction: "WiFi OK"
        }
    }

    private var canCheckInOut: Bool {
        !hasWiFiRestriction || wifiStatus == .connected || wifiStatus == .noRestriction
    }

    private func checkWiFi() async {
        guard hasWiFiRestriction else {
            wifiStatus = .noRestriction
            return
        }
        wifiStatus = .checking
        wifiChecker.requestLocationPermission()
        let ok = await wifiChecker.isConnectedToGymWiFi(ssids: syncManager.gymWiFiSSIDs)
        wifiStatus = ok ? .connected : .notConnected
    }

    private func verifyWiFiAndProceed(_ action: @escaping () -> Void) {
        if canCheckInOut {
            action()
        } else {
            showWiFiAlert = true
        }
    }

    // MARK: - Checked In Section

    @ViewBuilder
    private func checkedInSection(_ active: TrainerAttendance) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.checkmark.fill")
                    .font(.title)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Đang làm việc")
                        .font(Theme.Fonts.headline())
                        .foregroundStyle(.green)
                    Text("Từ \(active.checkInTime, format: .dateTime.hour().minute())")
                        .font(Theme.Fonts.subheadline())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TimeElapsedView(since: active.checkInTime)
            }

            if let urlStr = active.checkInPhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    ProgressView()
                        .frame(height: 60)
                }
            }

            Button {
                verifyWiFiAndProceed { showCheckOutCamera = true }
            } label: {
                Label("Chụp ảnh & Check-out", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CuteButtonStyle(color: .red))
            .disabled(isProcessing)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Not Checked In Section

    private var notCheckedInSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.xmark.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chưa check-in")
                        .font(Theme.Fonts.headline())
                    Text("Chụp ảnh để xác nhận check-in")
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            TextField("Ghi chú (tuỳ chọn)", text: $notes)
                .textFieldStyle(.roundedBorder)

            if let data = capturedPhotoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            capturedPhotoData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .black.opacity(0.5))
                        }
                        .padding(6)
                    }
            }

            if capturedPhotoData == nil {
                Button {
                    verifyWiFiAndProceed { showCheckInCamera = true }
                } label: {
                    Label("Chụp ảnh check-in", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CuteButtonStyle(color: .blue))
                .disabled(currentTrainer == nil)
            } else {
                Button {
                    guard let trainer = currentTrainer else { return }
                    verifyWiFiAndProceed {
                        Task {
                            isProcessing = true
                            await syncManager.checkIn(trainer: trainer, notes: notes, photoData: capturedPhotoData)
                            notes = ""
                            capturedPhotoData = nil
                            isProcessing = false
                        }
                    }
                } label: {
                    Label("Xác nhận Check-in", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CuteButtonStyle(color: .green))
                .disabled(isProcessing)
            }
        }
        .padding(.vertical, 8)
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

// MARK: - Attendance Row

struct AttendanceRow: View {
    let attendance: TrainerAttendance
    var showDate: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let urlStr = attendance.checkInPhotoURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                        .frame(width: 36, height: 36)
                }
            } else {
                Circle()
                    .fill(attendance.isCheckedOut ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if showDate {
                        Text(attendance.checkInTime, format: .dateTime.day().month().weekday(.abbreviated))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text("\(attendance.checkInTime, format: .dateTime.hour().minute())")
                        .font(.subheadline)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let out = attendance.checkOutTime {
                        Text("\(out, format: .dateTime.hour().minute())")
                            .font(.subheadline)
                    } else {
                        Text("--:--")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !attendance.notes.isEmpty {
                    Text(attendance.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(attendance.formattedDuration)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(attendance.isCheckedOut ? .green : .orange)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Time Elapsed View

struct TimeElapsedView: View {
    let since: Date
    @State private var now = Date()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let elapsed = now.timeIntervalSince(since)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        Text(String(format: "%02d:%02d", hours, minutes))
            .font(.system(.title2, design: .monospaced))
            .fontWeight(.bold)
            .foregroundStyle(.green)
            .onReceive(timer) { _ in now = Date() }
            .onAppear { now = Date() }
    }
}
