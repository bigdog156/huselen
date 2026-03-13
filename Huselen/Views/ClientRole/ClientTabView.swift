import SwiftUI

struct ClientTabView: View {
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

            MealPlanView()
                .tabItem {
                    Label("Meal Plan", systemImage: "fork.knife")
                }

            MyBodyStatsView()
                .tabItem {
                    Label("Chỉ số", systemImage: "figure")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.mintGreen)
    }
}
