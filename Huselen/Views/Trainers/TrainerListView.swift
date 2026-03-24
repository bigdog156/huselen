import SwiftUI

struct TrainerListView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showingAddForm = false
    @State private var searchText = ""
    @State private var trainerToDelete: Trainer?

    var filteredTrainers: [Trainer] {
        var list = syncManager.trainers
        if let branchId = syncManager.selectedBranchId {
            list = list.filter { $0.branchId == branchId }
        }
        let sorted = list.sorted { $0.name < $1.name }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTrainers) { trainer in
                    NavigationLink(destination: TrainerDetailView(trainer: trainer)) {
                        TrainerRowView(trainer: trainer)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            trainerToDelete = trainer
                        } label: {
                            Label("Xoá", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Xoá PT \(trainerToDelete?.name ?? "")?",
                isPresented: Binding(
                    get: { trainerToDelete != nil },
                    set: { if !$0 { trainerToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Xoá PT", role: .destructive) {
                    if let trainer = trainerToDelete {
                        Task { await syncManager.deleteTrainer(trainer) }
                        trainerToDelete = nil
                    }
                }
                Button("Huỷ", role: .cancel) { trainerToDelete = nil }
            } message: {
                Text("Hành động này không thể hoàn tác. Các buổi tập liên quan sẽ không còn PT.")
            }
            .overlay {
                if filteredTrainers.isEmpty {
                    ContentUnavailableView("Chưa có PT nào", systemImage: "person.badge.plus", description: Text(syncManager.selectedBranchId != nil ? "Không có PT ở cơ sở này" : "Nhấn + để thêm PT mới"))
                }
            }
            .navigationTitle("Personal Trainers")
            .searchable(text: $searchText, prompt: "Tìm PT...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddForm = true }) {
                        Label("Thêm PT", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                SearchTrainerView()
            }
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

}

struct TrainerRowView: View {
    let trainer: Trainer

    var body: some View {
        HStack(spacing: 12) {
            CuteIconCircle(icon: "figure.strengthtraining.traditional", color: Theme.Colors.softOrange)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(trainer.name)
                        .font(Theme.Fonts.headline())
                    if !trainer.isActive {
                        CuteBadge(text: "Nghỉ", color: Theme.Colors.softPink)
                    }
                }
                if !trainer.specialization.isEmpty {
                    Text(trainer.specialization)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(trainer.completedSessionsCount)")
                    .font(Theme.Fonts.title3())
                    .foregroundStyle(Theme.Colors.softOrange)
                Text("buổi")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
