import SwiftUI

/// Layout and type tokens for the app.
///
/// Colors are deliberately absent: everything draws from the system semantic
/// colors (`.primary`, `.secondaryInk`, `.tertiaryInk`, `Color.accentColor`)
/// so the app inherits Liquid Glass's automatic light/dark behaviour instead
/// of freezing a palette that would fight it. The two ink tokens at the end of
/// this file are the system's secondary and tertiary label colours as flat
/// colours rather than the hierarchical `.secondary` and `.tertiary` styles,
/// for one measured reason: on glass the hierarchical styles are vibrant, and
/// against this app's black dark ground that made every card title and
/// caption 2.5:1.
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

// MARK: - Ink

extension ShapeStyle where Self == Color {
  /// Secondary ink for text: the system's `secondaryLabel` as a flat colour,
  /// never the hierarchical `.secondary` style. On glass the hierarchical
  /// styles are drawn with vibrancy, and against this app's dark ground — the
  /// black grouped background — there is nothing for them to be vibrant
  /// against. Measured on the iOS 27 simulator on 2026-09-22 (the owner's
  /// device report, `docs/design-system.md` §2): a card title in `.secondary`
  /// rendered #4D4D4D on the card's black, 2.48:1, where the same style
  /// outside a card rendered #8C8C92, 6.28:1; in light, 2.85:1 inside against
  /// 3.54:1 outside. The flat semantic colour is exactly what `.secondary`
  /// resolves to off glass, so nothing off glass changes; on glass it reads
  /// as it does beside the glass. It still follows light and dark, Increase
  /// Contrast and every other system setting — only the vibrancy goes. A
  /// tier-2 test (`InkTests`) keeps the hierarchical styles out of the app
  /// target's text.
  static var secondaryInk: Color { Color(.secondaryLabel) }

  /// Tertiary ink, by the same rule: `tertiaryLabel`, flat.
  static var tertiaryInk: Color { Color(.tertiaryLabel) }
}
