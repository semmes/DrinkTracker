import SwiftUI

/// The Light / Dark / System choice in Settings (1.2 spec, Feature A).
///
/// Lives in the app target and in *standard* `UserDefaults`, deliberately not
/// the App Group: the widget keeps following the system appearance, which is
/// what users expect on a home screen and what Apple's guidance points to —
/// an app-side override must not leak there.
enum AppearancePreference: String, CaseIterable, Identifiable {
  case system, light, dark

  static let storageKey = "appearancePreference"

  var id: String { rawValue }

  /// What `.preferredColorScheme` receives; nil means follow the device.
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var label: String {
    switch self {
    case .system: "System"
    case .light: "Light"
    case .dark: "Dark"
    }
  }
}
