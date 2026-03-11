import SwiftUI

struct SearchTrainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager
    @State private var searchManager = ProfileSearchManager(role: "trainer")
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var addingProfileIds: Set<UUID> = []
    @State private var showManualForm = false

    private var existingProfileIds: Set<UUID> {
        Set(syncManager.trainers.compactMap(\.profileId))
    }

    var body: some View {
        NavigationStack {
            List {
                if searchManager.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }

                if let error = searchManager.errorMessage {
                    Section {
                        Text(error)
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(.red)
                    }
                }

                if let error = syncManager.errorMessage {
                    Section {
                        Text(error)
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(.red)
                    }
                }

                ForEach(searchManager.results) { profile in
                    let alreadyAdded = existingProfileIds.contains(profile.id)
                    let isAdding = addingProfileIds.contains(profile.id)

                    HStack(spacing: 12) {
                        CuteIconCircle(
                            icon: "figure.strengthtraining.traditional",
                            color: alreadyAdded ? Theme.Colors.textSecondary : Theme.Colors.softOrange
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.fullName)
                                .font(Theme.Fonts.headline())
                            if let username = profile.username, !username.isEmpty {
                                Text("@\(username)")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.softOrange)
                            }
                            if let email = profile.email, !email.isEmpty {
                                Text(email)
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }

                        Spacer()

                        if alreadyAdded {
                            CuteBadge(text: "Đã thêm", color: Theme.Colors.mintGreen)
                        } else if isAdding {
                            ProgressView()
                        } else {
                            Button {
                                addTrainer(from: profile)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.softOrange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !searchManager.isLoading && searchManager.results.isEmpty && searchManager.errorMessage == nil {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Tìm PT trên hệ thống" : "Không tìm thấy PT",
                        systemImage: searchText.isEmpty ? "magnifyingglass" : "person.slash",
                        description: Text(searchText.isEmpty ? "Nhập tên, username hoặc email" : "Thử từ khóa khác")
                    )
                }
            }
            .navigationTitle("Thêm PT")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Tìm tên, username hoặc email...")
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    if newValue.isEmpty {
                        await searchManager.fetchAll()
                    } else {
                        await searchManager.search(query: newValue)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showManualForm = true
                    } label: {
                        Label("Thêm thủ công", systemImage: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showManualForm) {
                TrainerFormView()
            }
            .task {
                await searchManager.fetchAll()
            }
        }
    }

    private func addTrainer(from profile: ProfileSearchResult) {
        let trainer = Trainer(
            name: profile.fullName,
            phone: profile.phone ?? "",
            profileId: profile.id
        )
        addingProfileIds.insert(profile.id)
        Task {
            let success = await syncManager.createTrainer(trainer)
            addingProfileIds.remove(profile.id)
            if success {
                syncManager.errorMessage = nil
            }
        }
    }
}
