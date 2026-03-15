import SwiftUI

struct ClientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    var client: Client?

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var height: Double = 0
    @State private var weight: Double = 0
    @State private var bodyFat: Double = 0
    @State private var muscleMass: Double = 0
    @State private var neck: Double = 0
    @State private var shoulder: Double = 0
    @State private var arm: Double = 0
    @State private var chest: Double = 0
    @State private var waist: Double = 0
    @State private var hip: Double = 0
    @State private var thigh: Double = 0
    @State private var calf: Double = 0
    @State private var lowerHip: Double = 0
    @State private var calorieGoal: Int = 2200
    @State private var proteinGoal: Double = 150
    @State private var carbsGoal: Double = 280
    @State private var fatGoal: Double = 70
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
                    bodyField("Chiều cao (cm)", value: $height)
                    bodyField("Cân nặng (kg)", value: $weight)
                    bodyField("Tỷ lệ mỡ (%)", value: $bodyFat)
                    bodyField("Khối lượng cơ (kg)", value: $muscleMass)
                }

                Section("Số đo cơ thể (cm)") {
                    bodyField("Cổ", value: $neck)
                    bodyField("Vai", value: $shoulder)
                    bodyField("Cánh tay", value: $arm)
                    bodyField("Vòng 1", value: $chest)
                    bodyField("Eo", value: $waist)
                    bodyField("Hông", value: $hip)
                    bodyField("Đùi", value: $thigh)
                    bodyField("Bắp chân", value: $calf)
                    bodyField("Vòng 3", value: $lowerHip)
                }

                Section("Mục tiêu dinh dưỡng") {
                    HStack {
                        Text("Calo (kcal)")
                        Spacer()
                        TextField("2200", value: $calorieGoal, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    bodyField("Protein (g)", value: $proteinGoal)
                    bodyField("Carbs (g)", value: $carbsGoal)
                    bodyField("Fat (g)", value: $fatGoal)
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
                    height = client.height
                    weight = client.weight
                    bodyFat = client.bodyFat
                    muscleMass = client.muscleMass
                    neck = client.neck
                    shoulder = client.shoulder
                    arm = client.arm
                    chest = client.chest
                    waist = client.waist
                    hip = client.hip
                    thigh = client.thigh
                    calf = client.calf
                    lowerHip = client.lowerHip
                    calorieGoal = client.calorieGoal
                    proteinGoal = client.proteinGoal
                    carbsGoal = client.carbsGoal
                    fatGoal = client.fatGoal
                    goal = client.goal
                    notes = client.notes
                    selectedBranchId = client.branchId
                }
            }
        }
    }

    private func bodyField(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        isSaving = true
        if let client {
            client.name = name.trimmingCharacters(in: .whitespaces)
            client.phone = phone
            client.email = email
            client.height = height
            client.weight = weight
            client.bodyFat = bodyFat
            client.muscleMass = muscleMass
            client.neck = neck
            client.shoulder = shoulder
            client.arm = arm
            client.chest = chest
            client.waist = waist
            client.hip = hip
            client.thigh = thigh
            client.calf = calf
            client.lowerHip = lowerHip
            client.calorieGoal = calorieGoal
            client.proteinGoal = proteinGoal
            client.carbsGoal = carbsGoal
            client.fatGoal = fatGoal
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
                height: height,
                weight: weight,
                bodyFat: bodyFat,
                muscleMass: muscleMass,
                neck: neck,
                shoulder: shoulder,
                arm: arm,
                chest: chest,
                waist: waist,
                hip: hip,
                thigh: thigh,
                calf: calf,
                lowerHip: lowerHip,
                calorieGoal: calorieGoal,
                proteinGoal: proteinGoal,
                carbsGoal: carbsGoal,
                fatGoal: fatGoal,
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
