import SwiftUI

struct ClientListView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showingAddForm = false
    @State private var searchText = ""

    var filteredClients: [Client] {
        var list = syncManager.clients
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
                ForEach(filteredClients) { client in
                    NavigationLink(destination: ClientDetailView(client: client)) {
                        ClientRowView(client: client)
                    }
                }
                .onDelete(perform: deleteClients)
            }
            .overlay {
                if filteredClients.isEmpty {
                    ContentUnavailableView("Chưa có khách hàng", systemImage: "person.crop.circle.badge.plus", description: Text(syncManager.selectedBranchId != nil ? "Không có khách hàng ở cơ sở này" : "Nhấn + để thêm khách hàng mới"))
                }
            }
            .navigationTitle("Khách hàng")
            .searchable(text: $searchText, prompt: "Tìm khách hàng...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddForm = true }) {
                        Label("Thêm", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                SearchClientView()
            }
            .refreshable {
                await syncManager.refresh()
            }
            .profileToolbar()
        }
    }

    private func deleteClients(offsets: IndexSet) {
        for index in offsets {
            let client = filteredClients[index]
            Task { await syncManager.deleteClient(client) }
        }
    }
}

struct ClientRowView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            CuteIconCircle(icon: "person.fill", color: Theme.Colors.mintGreen)

            VStack(alignment: .leading, spacing: 4) {
                Text(client.name)
                    .font(Theme.Fonts.headline())
                if !client.goal.isEmpty {
                    Text(client.goal)
                        .font(Theme.Fonts.caption())
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(client.remainingSessions)")
                    .font(Theme.Fonts.title3())
                    .foregroundStyle(client.remainingSessions > 0 ? Theme.Colors.mintGreen : Theme.Colors.softPink)
                Text("buổi còn lại")
                    .font(Theme.Fonts.caption())
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
