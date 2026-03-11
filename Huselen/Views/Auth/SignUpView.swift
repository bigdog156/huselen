import SwiftUI

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .owner
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.softPink.opacity(0.15))
                                .frame(width: 100, height: 100)
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Theme.Colors.softPink)
                        }
                        Text("Tạo tài khoản")
                            .font(Theme.Fonts.title())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Đăng ký để bắt đầu sử dụng Huselen 🎉")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 20)

                    // Form
                    VStack(spacing: 16) {
                        FormField(title: "Họ và tên", placeholder: "Nguyễn Văn A", text: $fullName)

                        FormField(title: "Email", placeholder: "your@email.com", text: $email, keyboardType: .emailAddress)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bạn là")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Picker("Vai trò", selection: $selectedRole) {
                                Label("Chủ phòng gym / Quản lý", systemImage: "building.2").tag(UserRole.owner)
                                Label("Personal Trainer", systemImage: "figure.strengthtraining.traditional").tag(UserRole.trainer)
                                Label("Khách hàng", systemImage: "person").tag(UserRole.client)
                            }
                            .pickerStyle(.menu)
                            .cuteTextField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mật khẩu")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                            SecureField("Ít nhất 6 ký tự", text: $password)
                                .cuteTextField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Xác nhận mật khẩu")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                            SecureField("Nhập lại mật khẩu", text: $confirmPassword)
                                .cuteTextField()

                            if !confirmPassword.isEmpty && password != confirmPassword {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text("Mật khẩu không khớp")
                                }
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Theme.Colors.softPink)
                            }
                        }

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

                    // Sign up button
                    Button(action: signUp) {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Đăng ký 🚀")
                        }
                    }
                    .buttonStyle(CuteButtonStyle(
                        color: isFormValid ? Theme.Colors.softPink : .gray.opacity(0.4)
                    ))
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .navigationTitle("Đăng ký")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
            }
            .alert("Đăng ký thành công! 🎊", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Vui lòng kiểm tra email để xác nhận tài khoản trước khi đăng nhập.")
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuth in
                if isAuth { dismiss() }
            }
        }
    }

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6 &&
        password == confirmPassword
    }

    private func signUp() {
        Task {
            await authManager.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                role: selectedRole
            )
            if authManager.errorMessage == nil && !authManager.isAuthenticated {
                showSuccess = true
            }
        }
    }
}

struct FormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled(keyboardType == .emailAddress)
                .cuteTextField()
        }
    }
}
