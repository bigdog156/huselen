import SwiftUI

struct GymWiFiSettingsView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Environment(\.dismiss) private var dismiss
    @State private var wifiSSIDs: [String] = []
    @State private var newSSID: String = ""
    @State private var isSaving = false
    @State private var wifiChecker = WiFiChecker()
    @State private var detectedSSID: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Giới hạn WiFi chấm công")
                            .font(.headline)
                        Text("PT chỉ có thể check-in/check-out khi kết nối với một trong các WiFi phòng tập. Để trống nếu không muốn giới hạn.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Current WiFi list
                Section("Danh sách WiFi cho phép") {
                    if wifiSSIDs.isEmpty {
                        Text("Chưa có WiFi nào — PT chấm công ở bất cứ đâu")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(wifiSSIDs.enumerated()), id: \.offset) { index, ssid in
                            HStack {
                                Image(systemName: "wifi")
                                    .foregroundStyle(.blue)
                                Text(ssid)
                                    .font(.body)
                                Spacer()
                                Button {
                                    wifiSSIDs.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Add new SSID
                Section("Thêm WiFi") {
                    HStack {
                        TextField("Tên WiFi (SSID)", text: $newSSID)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Button {
                            addSSID(newSSID)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        .disabled(newSSID.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    // Detect current WiFi
                    if let detected = detectedSSID {
                        if !wifiSSIDs.contains(detected) {
                            Button {
                                addSSID(detected)
                            } label: {
                                HStack {
                                    Image(systemName: "wifi")
                                        .foregroundStyle(.green)
                                    Text("Thêm WiFi hiện tại: \(detected)")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "plus")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("WiFi hiện tại đã có trong danh sách")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            Task { await detectCurrentWiFi() }
                        } label: {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Phát hiện WiFi hiện tại")
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                // Status
                Section {
                    if !wifiSSIDs.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Đã bật giới hạn WiFi")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(wifiSSIDs.count) WiFi được phép")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.secondary)
                            Text("Không giới hạn WiFi")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !syncManager.gymWiFiSSIDs.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            wifiSSIDs = []
                            Task {
                                isSaving = true
                                await syncManager.saveGymWiFiSSIDs([])
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Xoá tất cả giới hạn WiFi")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cài đặt WiFi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        Task {
                            isSaving = true
                            await syncManager.saveGymWiFiSSIDs(wifiSSIDs)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                wifiSSIDs = syncManager.gymWiFiSSIDs
            }
        }
    }

    private func addSSID(_ ssid: String) {
        let trimmed = ssid.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !wifiSSIDs.contains(trimmed) else { return }
        wifiSSIDs.append(trimmed)
        newSSID = ""
    }

    private func detectCurrentWiFi() async {
        wifiChecker.requestLocationPermission()
        await wifiChecker.fetchCurrentSSID()
        detectedSSID = wifiChecker.currentSSID
    }
}
