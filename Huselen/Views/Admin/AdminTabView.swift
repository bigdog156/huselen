import SwiftUI

struct AdminTabView: View {
    @Environment(DataSyncManager.self) private var syncManager

    var body: some View {
        VStack(spacing: 0) {
            if !syncManager.branches.isEmpty {
                BranchPickerBar()
            }

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

                AdminManagementView()
                    .tabItem {
                        Label("Quản lý", systemImage: "gearshape.2")
                    }
            }
        }
        .environment(\.appAccentColor, Theme.Colors.warmYellow)
    }
}

struct BranchPickerBar: View {
    @Environment(DataSyncManager.self) private var syncManager

    var body: some View {
        @Bindable var sync = syncManager
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BranchChip(
                    title: "Tất cả",
                    isSelected: syncManager.selectedBranchId == nil
                ) {
                    syncManager.selectedBranchId = nil
                }

                ForEach(syncManager.branches.filter(\.isActive)) { branch in
                    BranchChip(
                        title: branch.name,
                        isSelected: syncManager.selectedBranchId == branch.id
                    ) {
                        syncManager.selectedBranchId = branch.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Theme.Colors.cardBackground)
    }
}

struct BranchChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.caption())
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.Colors.skyBlue : Theme.Colors.cardBackground)
                .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Theme.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
