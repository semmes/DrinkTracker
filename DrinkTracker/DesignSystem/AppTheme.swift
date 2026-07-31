import ComponentsKit
import SwiftUI

/// Configures ComponentsKit's global theme so its components sit inside Apple's
/// Liquid Glass material system rather than introducing a second visual language.
///
/// ComponentsKit's stock container radii (16 / 20 / 26) already line up with iOS 26
/// continuous corners, so the work here is mostly about pinning colors to the system
/// tints and softening the stock shadows, which are heavier than Liquid Glass wants.
enum AppTheme {

  /// Called once from the app's initializer, before any view is built.
  static func install() {
    var theme = Theme()

    // System blue, matching Apple's default tint. Swap this single value if the
    // app ever takes on a brand color of its own.
    theme.colors.accent = ComponentColor(
      main: .universal(.hex("#007AFF")),
      contrast: .universal(.hex("#FFFFFF")),
      background: .themed(
        light: .hex("#E1EEFE"),
        dark: .hex("#2B3E53")
      )
    )

    // Liquid Glass surfaces carry their own depth, so component shadows are
    // pulled back to a hint rather than the library's default lift.
    theme.layout.shadow = .init(
      small: .init(
        radius: 6,
        offset: .init(width: 0, height: 2),
        color: .themed(
          light: .rgba(r: 0, g: 0, b: 0, a: 0.06),
          dark: .rgba(r: 0, g: 0, b: 0, a: 0.20)
        )
      ),
      medium: .init(
        radius: 12,
        offset: .init(width: 0, height: 4),
        color: .themed(
          light: .rgba(r: 0, g: 0, b: 0, a: 0.08),
          dark: .rgba(r: 0, g: 0, b: 0, a: 0.25)
        )
      ),
      large: .init(
        radius: 20,
        offset: .init(width: 0, height: 8),
        color: .themed(
          light: .rgba(r: 0, g: 0, b: 0, a: 0.10),
          dark: .rgba(r: 0, g: 0, b: 0, a: 0.30)
        )
      )
    )

    Theme.current = theme
  }
}

// MARK: - Shared component models

extension CardVM {
  /// The standard KPI/content card used on the trend screens.
  static var glass: CardVM {
    CardVM {
      $0.backgroundStyle = .liquidGlass
      $0.cornerRadius = .large
      $0.contentPaddings = .init(padding: GlassTokens.Spacing.cardPadding)
      $0.borderWidth = .small
      $0.shadow = .small
    }
  }
}

extension ButtonVM {
  /// The full-width primary action, e.g. "Log drink" and the onboarding CTAs.
  static func primary(_ title: String, isEnabled: Bool = true) -> ButtonVM {
    ButtonVM {
      $0.title = title
      $0.color = .accent
      $0.style = .filled
      $0.size = .large
      $0.cornerRadius = .large
      $0.isFullWidth = true
      $0.isEnabled = isEnabled
    }
  }

  /// A quiet, text-weight action such as "Skip" or "Not now".
  static func subtle(_ title: String) -> ButtonVM {
    ButtonVM {
      $0.title = title
      $0.color = .accent
      $0.style = .minimal
      $0.size = .medium
    }
  }
}

extension SliderVM {
  /// The ABV slider in the drink-detail sheet, scoped to the type's range.
  static func abv(range: ClosedRange<Double>) -> SliderVM {
    SliderVM {
      $0.color = .accent
      $0.minValue = range.lowerBound
      $0.maxValue = range.upperBound
      $0.step = 0.5
      $0.size = .medium
      $0.style = .light
    }
  }
}
