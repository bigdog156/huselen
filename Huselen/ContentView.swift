//
//  ContentView.swift
//  Huselen
//
//  Created by FinOS on 2/24/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(DataSyncManager.self) private var syncManager

    var body: some View {
        Group {
            switch authManager.userRole {
            case .owner:
                AdminTabView()
            case .trainer:
                if authManager.isFreelancePT {
                    FreelanceTrainerTabView()
                } else {
                    TrainerTabView()
                }
            case .client:
                ClientTabView()
            }
        }
        .task {
            await syncManager.fetchAll(role: authManager.userRole, isFreelance: authManager.isFreelancePT)
        }
        .alert("Lỗi", isPresented: Binding(
            get: { syncManager.errorMessage != nil },
            set: { if !$0 { syncManager.errorMessage = nil } }
        )) {
            Button("OK") { syncManager.errorMessage = nil }
        } message: {
            Text(syncManager.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthManager())
        .environment(DataSyncManager())
}
