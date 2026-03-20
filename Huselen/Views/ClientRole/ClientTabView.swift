import SwiftUI
import Auth

struct ClientTabView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        TabView {
            ClientCheckInView()
                .tabItem {
                    Label("Check-in", systemImage: "camera.fill")
                }

            MySessionsView()
                .tabItem {
                    Label("Lịch tập", systemImage: "calendar")
                }

            MyPackagesView()
                .tabItem {
                    Label("Gói của tôi", systemImage: "creditcard")
                }

            MealLogView(userId: authManager.currentUser?.id.uuidString ?? "")
                .tabItem {
                    Label("Nhật ký ăn", systemImage: "fork.knife")
                }

            MyBodyStatsView()
                .tabItem {
                    Label("Chỉ số", systemImage: "figure")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.mintGreen)
    }
}
