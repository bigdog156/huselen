import SwiftUI

struct TrainerTabView: View {
    var body: some View {
        TabView {
            PTScheduleView()
                .tabItem {
                    Label("Lịch của tôi", systemImage: "calendar")
                }

            PTClientsView()
                .tabItem {
                    Label("Học viên", systemImage: "person.2")
                }

            PTAttendanceView()
                .tabItem {
                    Label("Chấm công", systemImage: "clock.badge.checkmark")
                }

            PTStatsView()
                .tabItem {
                    Label("Thống kê", systemImage: "chart.bar")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.softOrange)
    }
}
