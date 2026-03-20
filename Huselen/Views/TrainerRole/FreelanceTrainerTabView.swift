import SwiftUI

struct FreelanceTrainerTabView: View {
    var body: some View {
        TabView {
            PTScheduleView()
                .tabItem {
                    Label("Lịch của tôi", systemImage: "calendar")
                }

            FreelancePTClientsView()
                .tabItem {
                    Label("Học viên", systemImage: "person.2")
                }
        }
        .environment(\.appAccentColor, Theme.Colors.softOrange)
    }
}
