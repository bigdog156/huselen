import SwiftUI

struct AdminTabView: View {
    var body: some View {
        TabView {
            ScheduleView()
                .tabItem {
                    Label("Lịch tập", systemImage: "calendar")
                }

            TrainerListView()
                .tabItem {
                    Label("PT", systemImage: "figure.strengthtraining.traditional")
                }

            ClientListView()
                .tabItem {
                    Label("Khách hàng", systemImage: "person.2")
                }

            PackageListView()
                .tabItem {
                    Label("Gói PT", systemImage: "creditcard")
                }

            RevenueView()
                .tabItem {
                    Label("Doanh thu", systemImage: "chart.bar")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.warmYellow)
    }
}
