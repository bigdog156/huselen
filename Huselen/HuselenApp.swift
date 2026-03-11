//
//  HuselenApp.swift
//  Huselen
//
//  Created by FinOS on 2/24/26.
//

import SwiftUI

@main
struct HuselenApp: App {
    @State private var authManager = AuthManager()
    @State private var syncManager = DataSyncManager()

    init() {
        // Global navigation bar appearance - rounded font
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold).rounded(),
            .foregroundColor: UIColor(Theme.Colors.textPrimary)
        ]
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: UIColor(Theme.Colors.textPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // Tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(syncManager)
                .tint(Theme.Colors.warmYellow)
        }
    }
}

// MARK: - UIFont Rounded Helper

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
