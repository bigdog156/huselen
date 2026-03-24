import SwiftUI

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    private static let storageKey = "app_color_scheme"

    var selectedScheme: AppColorScheme {
        didSet { UserDefaults.standard.set(selectedScheme.rawValue, forKey: Self.storageKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.selectedScheme = AppColorScheme(rawValue: stored) ?? .system
    }

    /// The SwiftUI ColorScheme override to pass to .preferredColorScheme()
    var colorScheme: ColorScheme? {
        switch selectedScheme {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - App Color Scheme

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Hệ thống"
        case .light:  return "Sáng"
        case .dark:   return "Tối"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}

// MARK: - Theme Picker Row (reusable)

struct ThemePickerRow: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var tm = themeManager
        HStack {
            CuteIconCircle(icon: themeManager.selectedScheme.icon, color: Theme.Colors.lavender, size: 36)
            Text("Giao diện")
                .font(Theme.Fonts.body())
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Picker("", selection: $tm.selectedScheme) {
                ForEach(AppColorScheme.allCases) { scheme in
                    Text(scheme.label).tag(scheme)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Colors.lavender)
        }
        .padding(.vertical, 4)
    }
}
