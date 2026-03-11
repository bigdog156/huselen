import SwiftUI

struct PackageFormView: View {
    @Environment(\.dismiss) private var dismiss

    var packageManager: PackageManager
    var editingPackage: GymPTPackage?

    @State private var name = ""
    @State private var totalSessions = 8
    @State private var price: Double = 3000000
    @State private var durationMonths = 1
    @State private var packageDescription = ""
    @State private var isActive = true
    @State private var isSaving = false

    var isEditing: Bool { editingPackage != nil }

    let monthOptions = [1, 2, 3, 6, 12]

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin gói") {
                    TextField("Tên gói *", text: $name)
                    HStack {
                        Text("Số buổi")
                        Spacer()
                        TextField("0", value: $totalSessions, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Giá & thời hạn") {
                    HStack {
                        Text("Giá (VNĐ)")
                        Spacer()
                        TextField("0", value: $price, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                    }
                    Picker("Thời hạn", selection: $durationMonths) {
                        ForEach(monthOptions, id: \.self) { m in
                            Text("\(m) tháng").tag(m)
                        }
                    }
                }

                Section("Mô tả") {
                    TextEditor(text: $packageDescription)
                        .frame(minHeight: 60)
                }

                Section {
                    Toggle("Đang bán", isOn: $isActive)
                }
            }
            .navigationTitle(isEditing ? "Sửa gói PT" : "Thêm gói PT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onAppear {
                if let pkg = editingPackage {
                    name = pkg.name
                    totalSessions = pkg.totalSessions
                    price = pkg.price
                    durationMonths = max(1, pkg.durationDays / 30)
                    packageDescription = pkg.description
                    isActive = pkg.isActive
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        Task {
            var success = false
            if let pkg = editingPackage, let id = pkg.id {
                success = await packageManager.updatePackage(
                    id: id,
                    name: trimmedName,
                    totalSessions: totalSessions,
                    price: price,
                    durationDays: durationMonths * 30,
                    description: packageDescription,
                    isActive: isActive
                )
            } else {
                success = await packageManager.createPackage(
                    name: trimmedName,
                    totalSessions: totalSessions,
                    price: price,
                    durationDays: durationMonths * 30,
                    description: packageDescription,
                    isActive: isActive
                )
            }
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}
