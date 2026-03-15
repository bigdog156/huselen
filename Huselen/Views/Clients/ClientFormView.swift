import SwiftUI

struct ClientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var client: Client?

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var weight: Double = 0
    @State private var bodyFat: Double = 0
    @State private var muscleMass: Double = 0
    @State private var goal = ""
    @State private var notes = ""
    @State private var selectedBranchId: UUID?
    @State private var isSaving = false

    var isEditing: Bool { client != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin cơ bản") {
                    TextField("Tên khách hàng *", text: $name)
                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Chỉ số cơ thể") {
                    HStack {
                        Text("Cân nặng (kg)")
                        Spacer()
                        TextField("0", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Tỷ lệ mỡ (%)")
                        Spacer()
                        TextField("0", value: $bodyFat, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Khối lượng cơ (kg)")
                        Spacer()
                        TextField("0", value: $muscleMass, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Mục tiêu tập luyện") {
                    TextEditor(text: $goal)
                        .frame(minHeight: 60)
                }

                if !syncManager.branches.isEmpty {
                    Section("Cơ sở") {
                        Picker("Cơ sở phòng tập", selection: $selectedBranchId) {
                            Text("Chưa chọn").tag(nil as UUID?)
                            ForEach(syncManager.branches.filter(\.isActive)) { branch in
                                Text(branch.name).tag(branch.id as UUID?)
                            }
                        }
                    }
                }

                Section("Ghi chú") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 60)
                }
            }
            .navigationTitle(isEditing ? "Sửa khách hàng" : "Thêm khách hàng")
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
                if let client {
                    name = client.name
                    phone = client.phone
                    email = client.email
                    weight = client.weight
                    bodyFat = client.bodyFat
                    muscleMass = client.muscleMass
                    goal = client.goal
                    notes = client.notes
                    selectedBranchId = client.branchId
                }
            }
        }
    }

    private func save() {
        isSaving = true
        if let client {
            client.name = name.trimmingCharacters(in: .whitespaces)
            client.phone = phone
            client.email = email
            client.weight = weight
            client.bodyFat = bodyFat
            client.muscleMass = muscleMass
            client.goal = goal
            client.notes = notes
            client.branchId = selectedBranchId
            client.branch = selectedBranchId.flatMap { bid in syncManager.branches.first { $0.id == bid } }
            Task {
                await syncManager.updateClient(client)
                isSaving = false
                dismiss()
            }
        } else {
            let newClient = Client(
                name: name.trimmingCharacters(in: .whitespaces),
                phone: phone,
                email: email,
                weight: weight,
                bodyFat: bodyFat,
                muscleMass: muscleMass,
                goal: goal,
                notes: notes
            )
            newClient.branchId = selectedBranchId
            newClient.branch = selectedBranchId.flatMap { bid in syncManager.branches.first { $0.id == bid } }
            Task {
                let success = await syncManager.createClient(newClient)
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}
