import SwiftUI

struct BranchListView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showingAddForm = false

    var body: some View {
        List {
            ForEach(syncManager.branches) { branch in
                NavigationLink {
                    BranchFormView(branch: branch)
                } label: {
                    HStack(spacing: 12) {
                        CuteIconCircle(icon: "building.2.fill", color: Theme.Colors.skyBlue)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(branch.name)
                                    .font(Theme.Fonts.headline())
                                if !branch.isActive {
                                    CuteBadge(text: "Nghỉ", color: Theme.Colors.softPink)
                                }
                            }
                            if !branch.address.isEmpty {
                                Text(branch.address)
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            let trainerCount = syncManager.trainers.filter { $0.branchId == branch.id }.count
                            Text("\(trainerCount)")
                                .font(Theme.Fonts.title3())
                                .foregroundStyle(Theme.Colors.skyBlue)
                            Text("PT")
                                .font(Theme.Fonts.caption())
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteBranches)
        }
        .overlay {
            if syncManager.branches.isEmpty {
                ContentUnavailableView("Chưa có cơ sở nào", systemImage: "building.2", description: Text("Nhấn + để thêm cơ sở mới"))
            }
        }
        .navigationTitle("Cơ sở phòng tập")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddForm = true }) {
                    Label("Thêm", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            BranchFormView()
        }
    }

    private func deleteBranches(offsets: IndexSet) {
        for index in offsets {
            let branch = syncManager.branches[index]
            Task { await syncManager.deleteBranch(branch) }
        }
    }
}
