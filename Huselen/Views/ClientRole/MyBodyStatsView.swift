import SwiftUI

struct MyBodyStatsView: View {
    @Environment(DataSyncManager.self) private var syncManager

    private var myProfile: Client? { syncManager.clients.first }

    private var completedSessions: Int {
        myProfile?.sessions.filter { $0.isCompleted }.count ?? 0
    }

    private var remainingSessions: Int {
        myProfile?.remainingSessions ?? 0
    }

    var body: some View {
        NavigationStack {
            if let client = myProfile {
                List {
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: "figure")
                                .font(.system(size: 40))
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if !client.goal.isEmpty {
                                    Text(client.goal)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Chỉ số cơ thể") {
                        StatsRow(icon: "scalemass", title: "Cân nặng", value: client.weight > 0 ? String(format: "%.1f kg", client.weight) : "—", color: .blue)
                        StatsRow(icon: "drop.halffull", title: "Tỷ lệ mỡ", value: client.bodyFat > 0 ? String(format: "%.1f%%", client.bodyFat) : "—", color: .orange)
                        StatsRow(icon: "figure.strengthtraining.traditional", title: "Khối lượng cơ", value: client.muscleMass > 0 ? String(format: "%.1f kg", client.muscleMass) : "—", color: .green)
                    }

                    Section("Thống kê tập luyện") {
                        LabeledContent("Tổng buổi đã tập") {
                            Text("\(completedSessions)")
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        LabeledContent("Buổi còn lại") {
                            Text("\(remainingSessions)")
                                .fontWeight(.semibold)
                                .foregroundStyle(remainingSessions > 0 ? .green : .red)
                        }
                    }

                    if !client.notes.isEmpty {
                        Section("Ghi chú") {
                            Text(client.notes)
                                .font(.body)
                        }
                    }
                }
                .navigationTitle("Chỉ số")
                .refreshable {
                    await syncManager.refresh()
                    await syncManager.fetchBodyStatLogs()
                }
            } else {
                ContentUnavailableView("Chưa có hồ sơ", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("Liên hệ phòng gym để cập nhật thông tin"))
            }
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

// MARK: - Stats Row

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
