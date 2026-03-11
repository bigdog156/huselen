import SwiftUI

struct SearchClientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager
    @State private var searchManager = ProfileSearchManager(role: "client")
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var addingProfileIds: Set<UUID> = []
    @State private var showManualForm = false

    private var existingProfileIds: Set<UUID> {
        Set(syncManager.clients.compactMap(\.profileId))
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
                            icon: "person.fill",
                            color: alreadyAdded ? Theme.Colors.textSecondary : Theme.Colors.mintGreen
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.fullName)
                                .font(Theme.Fonts.headline())
                            if let username = profile.username, !username.isEmpty {
                                Text("@\(username)")
                                    .font(Theme.Fonts.caption())
                                    .foregroundStyle(Theme.Colors.mintGreen)
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
                                addClient(from: profile)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.mintGreen)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !searchManager.isLoading && searchManager.results.isEmpty && searchManager.errorMessage == nil {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Tìm khách hàng trên hệ thống" : "Không tìm thấy khách hàng",
                        systemImage: searchText.isEmpty ? "magnifyingglass" : "person.slash",
                        description: Text(searchText.isEmpty ? "Nhập tên, username hoặc email" : "Thử từ khóa khác")
                    )
                }
            }
            .navigationTitle("Thêm khách hàng")
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
                ClientFormView()
            }
            .task {
                await searchManager.fetchAll()
            }
        }
    }

    private func addClient(from profile: ProfileSearchResult) {
        let client = Client(
            name: profile.fullName,
            phone: profile.phone ?? "",
            email: profile.email ?? "",
            profileId: profile.id
        )
        addingProfileIds.insert(profile.id)
        Task {
            let success = await syncManager.createClient(client)
            addingProfileIds.remove(profile.id)
            if success {
                syncManager.errorMessage = nil
            }
        }
    }
}
