import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingResetPassword = false

    var body: some View {
        @Bindable var auth = authManager

        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Logo - cute circle background
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.warmYellow.opacity(0.15))
                                .frame(width: 120, height: 120)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(Theme.Colors.warmYellow)
                        }
                        Text("Huselen")
                            .font(Theme.Fonts.largeTitle())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Quản lý PT chuyên nghiệp 💪")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(.top, 50)

                    // Form - cute card
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                            TextField("your@email.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .cuteTextField()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mật khẩu")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.textSecondary)
                            SecureField("Nhập mật khẩu", text: $password)
                                .cuteTextField()
                        }

                        if let error = authManager.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: error.contains("Đã gửi") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                Text(error)
                            }
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(error.contains("Đã gửi") ? Theme.Colors.mintGreen : Theme.Colors.softPink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: {
                            showingResetPassword = true
                        }) {
                            Text("Quên mật khẩu?")
                                .font(Theme.Fonts.subheadline())
                                .foregroundStyle(Theme.Colors.warmYellow)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .cuteCard()
                    .padding(.horizontal)

                    // Buttons
                    VStack(spacing: 16) {
                        Button(action: signIn) {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Đăng nhập ✨")
                            }
                        }
                        .buttonStyle(CuteButtonStyle(
                            color: isFormValid ? Theme.Colors.warmYellow : .gray.opacity(0.4)
                        ))
                        .disabled(!isFormValid || authManager.isLoading)

                        HStack(spacing: 4) {
                            Text("Chưa có tài khoản?")
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Button("Đăng ký ngay") {
                                showingSignUp = true
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.warmYellow)
                        }
                        .font(Theme.Fonts.subheadline())
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .alert("Quên mật khẩu", isPresented: $showingResetPassword) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                Button("Gửi") {
                    Task { await authManager.resetPassword(email: email) }
                }
                Button("Huỷ", role: .cancel) {}
            } message: {
                Text("Nhập email để nhận link đặt lại mật khẩu")
            }
        }
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }

    private func signIn() {
        Task {
            await authManager.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        }
    }
}
