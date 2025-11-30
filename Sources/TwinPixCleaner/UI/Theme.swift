import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .system: return "gear"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct ThemeToggle: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .system
    
    var body: some View {
        Picker("", selection: $currentTheme) {
            ForEach(AppTheme.allCases) { theme in
                Image(systemName: theme.icon)
                    .font(.system(size: 16, weight: .medium))
                    .tag(theme)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}
