import SwiftUI

/// Layout and type tokens for the app.
///
/// Colors are deliberately absent: everything draws from the system semantic
/// colors (`.primary`, `.secondary`, `Color.accentColor`) so the app inherits
/// Liquid Glass's automatic light/dark and vibrancy behaviour instead of
/// freezing a palette that would fight it.
enum GlassTokens {

  enum Spacing {
    /// Gap between related items inside a group.
    static let tight: CGFloat = 8
    /// Default gap between elements in a stack.
    static let regular: CGFloat = 12
    /// Gap between distinct groups on a screen.
    static let section: CGFloat = 24
    /// Gap between major blocks, e.g. metric and quick-add row.
    static let block: CGFloat = 32
    /// Horizontal screen margin.
    static let screenMargin: CGFloat = 20
    /// Inner padding for cards.
    static let cardPadding: CGFloat = 16
  }

  enum Radius {
    static let control: CGFloat = 14
    static let pill: CGFloat = 22
    static let card: CGFloat = 26
    static let sheet: CGFloat = 34
  }

  enum Layout {
    /// Minimum hit target, per Apple's accessibility guidance.
    static let minimumTouchTarget: CGFloat = 44
    /// Height of the quick-add buttons on Today.
    static let quickAddHeight: CGFloat = 88
    /// Height of the trend chart.
    static let chartHeight: CGFloat = 200
  }

  /// Type roles. All built on relative text styles so Dynamic Type scales them.
  enum Typography {
    /// The large number on Today. Rounded design keeps the figure feeling
    /// observational rather than clinical.
    static let metric = Font.system(size: 76, weight: .semibold, design: .rounded)
    static let onboardingHeadline = Font.system(.largeTitle, weight: .bold)
    static let sheetTitle = Font.system(.title2, weight: .semibold)
    static let cardValue = Font.system(.title, design: .rounded, weight: .semibold)
    static let cardLabel = Font.system(.footnote, weight: .regular)
    static let supporting = Font.system(.subheadline)
  }
}

// MARK: - Glass container

extension View {
  /// Wraps content in the app's standard Liquid Glass surface.
  ///
  /// Uses the system `.glassEffect` so the material, its interactive highlight,
  /// and its accessibility fallbacks (Reduce Transparency, Increase Contrast)
  /// all come from the OS rather than being approximated with a blur.
  func glassSurface(
    cornerRadius: CGFloat = GlassTokens.Radius.card,
    interactive: Bool = false
  ) -> some View {
    glassEffect(
      interactive ? .regular.interactive() : .regular,
      in: .rect(cornerRadius: cornerRadius, style: .continuous)
    )
  }

  /// Standard horizontal screen margin.
  func screenMargin() -> some View {
    padding(.horizontal, GlassTokens.Spacing.screenMargin)
  }
}
