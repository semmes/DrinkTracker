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
    /// Gap between major blocks, e.g. the counter and the pace card.
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

    /// A heading *inside* a card, for a card that holds more than one table.
    /// Uppercase with tracking at the call site, so the step down from the
    /// card's own content comes from case and letterspacing rather than from
    /// a smaller size or thinner ink.
    static let sectionLabel = Font.system(.footnote, weight: .medium)

    /// The head over a numeric column. It carries the noun the rows below it
    /// no longer repeat, so it is set in `.primary` ink, never `.secondary`:
    /// at this size secondary lands near 3.4:1, and hierarchy here comes from
    /// size, case and tracking rather than from thinning the ink (invariant 10).
    static let columnHead = Font.system(.caption2, weight: .medium)

    /// A figure the user's own logging produced: rounded and tabular, so it
    /// aligns down a column and reads apart from a published figure, which
    /// stays in default SF. The numeral carries that distinction because the
    /// design system allows no second hue for it.
    static let rowFigure = Font.system(.callout, design: .rounded, weight: .semibold)

    /// The same rule one step down, for a secondary count beside a figure.
    static let rowCount = Font.system(.footnote, design: .rounded, weight: .semibold)
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
