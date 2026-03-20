import SwiftUI

struct FreelancePTClientsView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @State private var showAddClient = false
    @State private var searchText = ""

    private var clients: [Client] {
        let sorted = syncManager.clients.sorted { $0.name < $1.name }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(clients) { client in
                    NavigationLink(destination: FreelanceClientDetailView(client: client)) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.softOrange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.headline)
                                if !client.goal.isEmpty {
                                    Text(client.goal)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            if !client.phone.isEmpty {
                                Text(client.phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteClients)
            }
            .overlay {
                if clients.isEmpty {
                    ContentUnavailableView(
                        "Chưa có học viên",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Nhấn + để thêm học viên mới")
                    )
                }
            }
            .navigationTitle("Học viên")
            .searchable(text: $searchText, prompt: "Tìm học viên...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddClient = true } label: {
                        Label("Thêm", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddClient) {
                FreelanceAddClientSheet()
            }
            .refreshable {
                await syncManager.refresh()
            }
        }
    }

    private func deleteClients(offsets: IndexSet) {
        for index in offsets {
            let client = clients[index]
            Task { await syncManager.deleteClient(client) }
        }
    }
}

// MARK: - Add Client Sheet (Freelance)

struct FreelanceAddClientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataSyncManager.self) private var syncManager

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var goal = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin cơ bản") {
                    TextField("Họ và tên", text: $name)
                    TextField("Số điện thoại", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Mục tiêu") {
                    TextField("Mục tiêu tập luyện", text: $goal)
                }
            }
            .navigationTitle("Thêm học viên")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let client = Client(
            name: name.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces)
        )
        client.goal = goal
        Task {
            await syncManager.createClient(client)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Client Detail (Freelance)

struct FreelanceClientDetailView: View {
    @Environment(DataSyncManager.self) private var syncManager
    @Bindable var client: Client

    @State private var showUpdateStats = false

    private var completedSessions: Int {
        client.sessions.filter { $0.isCompleted }.count
    }

    private var upcomingSessions: [TrainingGymSession] {
        client.sessions
            .filter { !$0.isCompleted && $0.scheduledDate >= Date() }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        List {
            // Profile section
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.Colors.softOrange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.name)
                            .font(.title3.bold())
                        if !client.goal.isEmpty {
                            Text(client.goal)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                if !client.phone.isEmpty {
                    LabeledContent("Điện thoại", value: client.phone)
                }
                if !client.email.isEmpty {
                    LabeledContent("Email", value: client.email)
                }
            }

            // Body stats
            Section("Chỉ số cơ thể") {
                LabeledContent("Cân nặng") {
                    Text(client.weight > 0 ? String(format: "%.1f kg", client.weight) : "—")
                        .foregroundStyle(client.weight > 0 ? .primary : .secondary)
                }
                LabeledContent("Chiều cao") {
                    Text(client.height > 0 ? String(format: "%.1f cm", client.height) : "—")
                        .foregroundStyle(client.height > 0 ? .primary : .secondary)
                }

                Button("Cập nhật chỉ số") { showUpdateStats = true }
            }

            // Training stats
            Section("Tập luyện") {
                LabeledContent("Buổi đã tập") {
                    Text("\(completedSessions)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
            }

            // Upcoming sessions
            if !upcomingSessions.isEmpty {
                Section("Lịch sắp tới") {
                    ForEach(upcomingSessions.prefix(5)) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.scheduledDate, format: .dateTime.weekday(.abbreviated).day().month())
                                    .font(.subheadline.bold())
                                Text(session.scheduledDate, format: .dateTime.hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.duration) phút")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Notes
            if !client.notes.isEmpty {
                Section("Ghi chú") {
                    Text(client.notes)
                }
            }
        }
        .navigationTitle(client.name)
        .sheet(isPresented: $showUpdateStats) {
            UpdateBodyStatsSheet(client: client)
        }
    }
}
