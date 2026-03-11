import SwiftUI

struct TrainerListView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showingAddForm = false
    @State private var searchText = ""

    var filteredTrainers: [Trainer] {
        let sorted = syncManager.trainers.sorted { $0.name < $1.name }
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
                }
                .onDelete(perform: deleteTrainers)
            }
            .overlay {
                if filteredTrainers.isEmpty {
                    ContentUnavailableView("Chưa có PT nào", systemImage: "person.badge.plus", description: Text("Nhấn + để thêm PT mới"))
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

    private func deleteTrainers(offsets: IndexSet) {
        for index in offsets {
            let trainer = filteredTrainers[index]
            Task { await syncManager.deleteTrainer(trainer) }
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
