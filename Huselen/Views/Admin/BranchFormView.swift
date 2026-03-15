import SwiftUI

struct BranchFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var branch: GymBranch?

    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var isActive = true
    @State private var isSaving = false

    var isEditing: Bool { branch != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin cơ sở") {
                    TextField("Tên cơ sở *", text: $name)
                    TextField("Địa chỉ", text: $address)
                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section {
                    Toggle("Đang hoạt động", isOn: $isActive)
                }
            }
            .navigationTitle(isEditing ? "Sửa cơ sở" : "Thêm cơ sở mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .overlay {
                            if isSaving { ProgressView().tint(.accentColor) }
                        }
                }
            }
            .onAppear {
                if let branch {
                    name = branch.name
                    address = branch.address
                    phone = branch.phone
                    isActive = branch.isActive
                }
            }
        }
    }

    private func save() {
        isSaving = true
        if let branch {
            branch.name = name.trimmingCharacters(in: .whitespaces)
            branch.address = address
            branch.phone = phone
            branch.isActive = isActive
            Task {
                await syncManager.updateBranch(branch)
                isSaving = false
                dismiss()
            }
        } else {
            let newBranch = GymBranch(
                name: name.trimmingCharacters(in: .whitespaces),
                address: address,
                phone: phone,
                isActive: isActive
            )
            Task {
                let success = await syncManager.createBranch(newBranch)
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}
