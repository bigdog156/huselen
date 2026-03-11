import SwiftUI

struct ClientTabView: View {
    var body: some View {
        TabView {
            MySessionsView()
                .tabItem {
                    Label("Lịch tập", systemImage: "calendar")
                }

            MyPackagesView()
                .tabItem {
                    Label("Gói của tôi", systemImage: "creditcard")
                }

            MyBodyStatsView()
                .tabItem {
                    Label("Chỉ số", systemImage: "figure")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.mintGreen)
    }
}
