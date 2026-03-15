import SwiftUI

struct GymSetupView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var gymName = ""
    @State private var gymAddress = ""
    @State private var gymPhone = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.warmYellow.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Theme.Colors.warmYellow)
                        }
                        Text("Tạo phòng tập")
                            .font(Theme.Fonts.title())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Thiết lập phòng tập của bạn để bắt đầu 🏋️")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Form
                    VStack(spacing: 16) {
                        FormField(title: "Tên phòng tập", placeholder: "VD: Huselen Fitness", text: $gymName)
                        FormField(title: "Địa chỉ", placeholder: "VD: 123 Nguyễn Huệ, Q1", text: $gymAddress)
                        FormField(title: "Số điện thoại", placeholder: "VD: 0901234567", text: $gymPhone, keyboardType: .phonePad)

                        if let error = authManager.errorMessage {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(error)
                            }
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(Theme.Colors.softPink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .cuteCard()
                    .padding(.horizontal)

                    // Create button
                    Button(action: createGym) {
                        if isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Tạo phòng tập 🚀")
                        }
                    }
                    .buttonStyle(CuteButtonStyle(
                        color: isFormValid ? Theme.Colors.warmYellow : .gray.opacity(0.4)
                    ))
                    .disabled(!isFormValid || isCreating)
                    .padding(.horizontal)

                    // Sign out option
                    Button {
                        Task { await authManager.signOut() }
                    } label: {
                        Text("Đăng xuất")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Thiết lập")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var isFormValid: Bool {
        !gymName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func createGym() {
        isCreating = true
        Task {
            _ = await authManager.createGym(
                name: gymName.trimmingCharacters(in: .whitespaces),
                address: gymAddress.trimmingCharacters(in: .whitespaces),
                phone: gymPhone.trimmingCharacters(in: .whitespaces)
            )
            isCreating = false
        }
    }
}
