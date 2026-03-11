import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isLoading {
                // Cute splash screen
                VStack(spacing: 20) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Theme.Colors.warmYellow.opacity(0.15))
                            .frame(width: 140, height: 140)
                        Circle()
                            .fill(Theme.Colors.warmYellow.opacity(0.1))
                            .frame(width: 180, height: 180)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(Theme.Colors.warmYellow)
                    }

                    VStack(spacing: 6) {
                        Text("Huselen")
                            .font(Theme.Fonts.largeTitle())
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Qu\u{1EA3}n l\u{00FD} PT chuy\u{00EA}n nghi\u{1EC7}p \u{1F4AA}")
                            .font(Theme.Fonts.subheadline())
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }

                    Spacer()

                    ProgressView()
                        .tint(Theme.Colors.warmYellow)
                        .scaleEffect(1.2)
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.cream.ignoresSafeArea())
            } else if authManager.isAuthenticated {
                ContentView()
            } else {
                SignInView()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authManager.isAuthenticated)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: authManager.isLoading)
    }
}
