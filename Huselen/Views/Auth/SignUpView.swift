import SwiftUI

// MARK: - PT Type Chip

struct PTTypeChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(Theme.Fonts.subheadline())
            }
            .foregroundStyle(isSelected ? .white : Theme.Colors.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.Colors.softOrange.gradient) : AnyShapeStyle(Theme.Colors.cardBackground))
                    .shadow(
                        color: isSelected ? Theme.Colors.softOrange.opacity(0.2) : .clear,
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sign Up View

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .owner
    @State private var isFreelance = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Header
                    headerSection
                        .padding(.bottom, 28)

                    // MARK: - Section 1: Role Selection
                    roleSelectionSection
                        .padding(.bottom, 28)

                    // MARK: - Section 2: Personal Info
                    personalInfoSection
                        .padding(.bottom, 28)

                    // MARK: - Section 3: Security
                    securitySection
                        .padding(.bottom, 28)

                    // MARK: - Error
                    if let error = authManager.errorMessage {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                        }
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.softPink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }

                    // MARK: - CTA
                    Button(action: signUp) {
                        if authManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Tạo tài khoản")
                        }
                    }
                    .buttonStyle(CuteButtonStyle(
                        color: isFormValid ? Theme.Colors.softPink : .gray.opacity(0.4)
                    ))
                    .disabled(!isFormValid || authManager.isLoading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
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

    // MARK: - Form Validation

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
                role: selectedRole,
                isFreelance: isFreelance
            )
            if authManager.errorMessage == nil && !authManager.isAuthenticated {
                showSuccess = true
            }
        }
    }
}

// MARK: - Subviews

private extension SignUpView {

    // MARK: Header

    var headerSection: some View {
        VStack(spacing: 10) {
            // Overlapping circles decoration with sparkles
            ZStack {
                Circle()
                    .fill(Theme.Colors.softPink.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .offset(x: -15, y: 10)

                Circle()
                    .fill(Theme.Colors.lavender.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .offset(x: 20, y: -5)

                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.Colors.softPink)
            }
            .frame(height: 120)

            Text("Chào mừng bạn!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Tạo tài khoản chỉ mất vài phút")
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.top, 24)
    }

    // MARK: Role Selection

    var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bạn là ai?")
                .font(Theme.Fonts.title3())
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                RoleCard(
                    icon: "building.2.fill",
                    title: "Chủ phòng gym",
                    subtitle: "Quản lý phòng tập, nhân viên và hội viên",
                    color: Theme.Colors.warmYellow,
                    isSelected: selectedRole == .owner,
                    action: { selectedRole = .owner }
                )

                RoleCard(
                    icon: "figure.strengthtraining.traditional",
                    title: "Personal Trainer",
                    subtitle: "Quản lý lịch tập và học viên của bạn",
                    color: Theme.Colors.softOrange,
                    isSelected: selectedRole == .trainer,
                    action: { selectedRole = .trainer }
                )

                RoleCard(
                    icon: "person.fill",
                    title: "Học viên",
                    subtitle: "Theo dõi lịch tập và tiến trình của bạn",
                    color: Theme.Colors.mintGreen,
                    isSelected: selectedRole == .client,
                    action: { selectedRole = .client }
                )
            }
            .padding(.horizontal, 24)

            // PT type selection
            if selectedRole == .trainer {
                HStack(spacing: 10) {
                    PTTypeChip(
                        title: "PT phòng gym",
                        icon: "building.fill",
                        isSelected: !isFreelance,
                        action: { isFreelance = false }
                    )

                    PTTypeChip(
                        title: "PT tự do",
                        icon: "figure.walk",
                        isSelected: isFreelance,
                        action: { isFreelance = true }
                    )
                }
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.25), value: selectedRole)
            }
        }
        .onChange(of: selectedRole) { _, newRole in
            if newRole != .trainer { isFreelance = false }
        }
    }

    // MARK: Personal Info

    var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CuteIconCircle(icon: "person.text.rectangle", color: Theme.Colors.lavender, size: 32)
                Text("Thông tin cá nhân")
                    .font(Theme.Fonts.title3())
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 20)
                    TextField("Nguyễn Văn A", text: $fullName)
                        .textInputAutocapitalization(.words)
                }
                .cuteTextField()

                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .frame(width: 20)
                    TextField("your@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .cuteTextField()
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: Security

    var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CuteIconCircle(icon: "lock.shield", color: Theme.Colors.softPink, size: 32)
                Text("Bảo mật")
                    .font(Theme.Fonts.title3())
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(width: 20)
                        SecureField("Ít nhất 6 ký tự", text: $password)
                    }
                    .cuteTextField()

                    if !password.isEmpty {
                        PasswordStrengthBar(password: password)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.rotation")
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .frame(width: 20)
                        SecureField("Nhập lại mật khẩu", text: $confirmPassword)
                    }
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
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview

// MARK: - FormField (shared, used by GymSetupView and others)

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

#Preview {
    SignUpView()
        .environment(AuthManager())
}
