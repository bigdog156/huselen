import SwiftUI

struct PackageListView: View {
    @State private var packageManager = PackageManager()
    @State private var showingAddForm = false

    private var activePackages: [GymPTPackage] {
        packageManager.packages.filter { $0.isActive }
    }

    private var inactivePackages: [GymPTPackage] {
        packageManager.packages.filter { !$0.isActive }
    }

    var body: some View {
        NavigationStack {
            List {
                if packageManager.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                if let error = packageManager.errorMessage {
                    Section {
                        Text(error)
                            .font(Theme.Fonts.caption())
                            .foregroundStyle(.red)
                    }
                }

                Section("Gói đang bán") {
                    if activePackages.isEmpty && !packageManager.isLoading {
                        Text("Chưa có gói nào")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activePackages) { pkg in
                            NavigationLink(destination: PackageFormView(packageManager: packageManager, editingPackage: pkg)) {
                                SupabasePackageRowView(package: pkg)
                            }
                        }
                        .onDelete { offsets in
                            Task {
                                for index in offsets {
                                    if let id = activePackages[index].id {
                                        _ = await packageManager.deletePackage(id: id)
                                    }
                                }
                            }
                        }
                    }
                }

                if !inactivePackages.isEmpty {
                    Section("Gói đã ngừng bán") {
                        ForEach(inactivePackages) { pkg in
                            NavigationLink(destination: PackageFormView(packageManager: packageManager, editingPackage: pkg)) {
                                SupabasePackageRowView(package: pkg)
                                    .opacity(0.6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gói PT")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddForm = true }) {
                        Label("Thêm gói", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                PackageFormView(packageManager: packageManager)
            }
            .refreshable {
                await packageManager.fetchPackages()
            }
            .task {
                await packageManager.fetchPackages()
            }
            .profileToolbar()
        }
    }
}

struct SupabasePackageRowView: View {
    let package: GymPTPackage

    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "VND"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: package.price)) ?? "\(package.price)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(package.name)
                    .font(Theme.Fonts.headline())
                Spacer()
                Text(formattedPrice)
                    .font(Theme.Fonts.subheadline())
                    .foregroundStyle(Theme.Colors.mintGreen)
            }
            HStack {
                Label("\(package.totalSessions) buổi", systemImage: "figure.run")
                    .font(Theme.Fonts.caption())
                Spacer()
                Label("\(package.durationDays) ngày", systemImage: "calendar")
                    .font(Theme.Fonts.caption())
            }
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }
}
