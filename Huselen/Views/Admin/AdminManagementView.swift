import SwiftUI

struct AdminManagementView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Gói tập") {
                    NavigationLink {
                        PackageListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gói PT")
                                    .font(Theme.Fonts.body())
                                Text("Quản lý các gói tập luyện")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "creditcard.fill")
                                .foregroundStyle(Theme.Colors.warmYellow)
                        }
                    }
                }

                Section("Nhân sự") {
                    NavigationLink {
                        AdminAttendanceView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chấm công PT")
                                    .font(Theme.Fonts.body())
                                Text("Theo dõi giờ làm việc của PT")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .foregroundStyle(Theme.Colors.mintGreen)
                        }
                    }
                }

                Section("Tài chính") {
                    NavigationLink {
                        RevenueView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Doanh thu")
                                    .font(Theme.Fonts.body())
                                Text("Thống kê doanh thu theo tháng")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(Theme.Colors.softOrange)
                        }
                    }
                }

                Section("Cơ sở") {
                    NavigationLink {
                        BranchListView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cơ sở phòng tập")
                                    .font(Theme.Fonts.body())
                                Text("Quản lý các chi nhánh")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(Theme.Colors.skyBlue)
                        }
                    }
                }

                Section("Cài đặt") {
                    NavigationLink {
                        GymWiFiSettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WiFi phòng gym")
                                    .font(Theme.Fonts.body())
                                Text("Cài đặt WiFi cho check-in")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "wifi")
                                .foregroundStyle(Theme.Colors.skyBlue)
                        }
                    }
                }
            }
            .navigationTitle("Quản lý")
            .profileToolbar()
        }
    }
}
