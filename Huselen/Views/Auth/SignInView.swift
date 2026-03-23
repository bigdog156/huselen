import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var email = ""
    @State private var password = ""
    @State private var showingSignUp = false
    @State private var showingResetPassword = false

    // MARK: - Staggered Entrance
    @State private var heroAppeared = false
    @State private var formAppeared = false
    @State private var ctaAppeared = false

    // MARK: - Focus
    enum Field: Hashable { case email, password }
    @FocusState private var focusedField: Field?

    var body: some View {
        @Bindable var auth = authManager

        NavigationStack {
            ScrollView {
                ZStack {
                    // MARK: - Decorative Background Blobs
                    backgroundBlobs

                    VStack(spacing: 28) {
                        // MARK: - Hero
                        heroSection
                            .opacity(heroAppeared ? 1 : 0)
                            .offset(y: heroAppeared ? 0 : 20)

                        // MARK: - Form
                        formSection
                            .opacity(formAppeared ? 1 : 0)
                            .offset(y: formAppeared ? 0 : 20)

                        // MARK: - CTA
                        ctaSection
                            .opacity(ctaAppeared ? 1 : 0)
                            .offset(y: ctaAppeared ? 0 : 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .background(Theme.Colors.cream.ignoresSafeArea())
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
                    .presentationDetents([.large])
                    .presentationCornerRadius(30)
                    .presentationDragIndicator(.visible)
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
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    heroAppeared = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                    formAppeared = true
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                    ctaAppeared = true
                }
            }
        }
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 { return "Chào buổi sáng! ☀️" }
        if hour >= 12 && hour < 18 { return "Chào buổi chiều! 🌤️" }
        return "Chào buổi tối! 🌙"
    }

    // MARK: - Form Valid

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

// MARK: - Subviews

private extension SignInView {

    var backgroundBlobs: some View {
        GeometryReader { geo in
            Circle()
                .fill(Theme.Colors.warmYellow.opacity(0.1))
                .frame(width: 200, height: 200)
                .position(x: geo.size.width * 0.85, y: 80)

            Circle()
                .fill(Theme.Colors.softPink.opacity(0.08))
                .frame(width: 160, height: 160)
                .position(x: geo.size.width * 0.1, y: 300)

            Circle()
                .fill(Theme.Colors.lavender.opacity(0.08))
                .frame(width: 120, height: 120)
                .position(x: geo.size.width * 0.7, y: 500)
        }
    }

    var heroSection: some View {
        VStack(spacing: 14) {
            // Squircle app icon
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.Colors.warmYellow.gradient)
                    .frame(width: 100, height: 100)

                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Huselen")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text(greeting)
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.top, 50)
    }

    var formSection: some View {
        VStack(spacing: 18) {
            // Email field
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 20)

                TextField("your@email.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            }
            .cuteTextField()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .strokeBorder(
                        focusedField == .email ? Theme.Colors.warmYellow.opacity(0.6) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField)

            // Password field
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(width: 20)

                SecureField("Nhập mật khẩu", text: $password)
                    .focused($focusedField, equals: .password)

                Button("Quên?") {
                    showingResetPassword = true
                }
                .font(Theme.Fonts.subheadline())
                .foregroundStyle(Theme.Colors.warmYellow)
            }
            .cuteTextField()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .strokeBorder(
                        focusedField == .password ? Theme.Colors.warmYellow.opacity(0.6) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField)

            // Error message
            if let error = authManager.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: error.contains("Đã gửi") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(Theme.Fonts.caption())
                .foregroundStyle(error.contains("Đã gửi") ? Theme.Colors.mintGreen : Theme.Colors.softPink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
    }

    var ctaSection: some View {
        VStack(spacing: 16) {
            // Primary sign in button
            Button(action: signIn) {
                if authManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Đăng nhập")
                }
            }
            .buttonStyle(CuteButtonStyle(
                color: isFormValid ? Theme.Colors.warmYellow : .gray.opacity(0.4)
            ))
            .disabled(!isFormValid || authManager.isLoading)

            // "hoặc" divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Theme.Colors.separator)
                    .frame(height: 1)
                Text("hoặc")
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.textTertiary)
                Rectangle()
                    .fill(Theme.Colors.separator)
                    .frame(height: 1)
            }

            // Ghost sign up button
            Button {
                showingSignUp = true
            } label: {
                Text("Tạo tài khoản mới")
                    .font(Theme.Fonts.headline())
                    .foregroundStyle(Theme.Colors.softPink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                            .fill(Theme.Colors.softPink.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Preview

#Preview {
    SignInView()
        .environment(AuthManager())
}
