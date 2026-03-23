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
    @State private var themeManager = ThemeManager()

    init() {
        configureNavigationBar()
        configureTabBar()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(syncManager)
                .environment(themeManager)
                .tint(Theme.Colors.warmYellow)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }

    // MARK: - UIKit Appearance

    private func configureNavigationBar() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()

        let titleColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.941, green: 0.929, blue: 0.902, alpha: 1)
                : UIColor(red: 0.180, green: 0.153, blue: 0.125, alpha: 1)
        }

        navAppearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold).rounded(),
            .foregroundColor: titleColor
        ]
        navAppearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold).rounded(),
            .foregroundColor: titleColor
        ]

        UINavigationBar.appearance().standardAppearance  = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    private func configureTabBar() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance  = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

// MARK: - UIFont Rounded Helper

extension UIFont {
    func rounded() -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
