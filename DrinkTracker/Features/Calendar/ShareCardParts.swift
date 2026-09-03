import DrinkTrackerCore
import SwiftUI

// The parts both share cards are built from (ADR-0027), in one file so the
// month card and the year card cannot drift: one ink, one frame, one header,
// one figure block, one day grid, one legend, one renderer.

/// The exported image's ground and inks.
///
/// Explicit, not semantic: an exported image has no host surface, so
/// `.primary` and `.secondary` have nothing to resolve against and the card
/// paints its own light or dark pair. This is the one literal-colour site
/// beside `IntensityPalette` (PRD invariant 10) — the pair the month card has
/// always painted, moved here without changing a value so two cards share one
/// site. Every fill and every outline decision still comes from
/// `IntensityPalette`.
struct ShareCardInk {
  let scheme: ColorScheme

  var ground: Color {
    scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
  }

  var primary: Color {
    scheme == .dark ? .white : .black
  }

  /// 0.55 over white measures ≈4.7:1 and over the dark ground ≈6.0:1 — both
  /// AA for normal text (composited in sRGB; re-measured from rendered pixels
  /// at tier 3, never eyeballed).
  var secondary: Color {
    primary.opacity(0.55)
  }

  /// Ink for a day number on its fill. `IntensityPalette.ink` cannot be used
  /// here because it resolves `.primary`/`.secondary` against a host surface.
  func cellInk(_ intensity: DayIntensity) -> Color {
    switch intensity {
    case .unlogged: secondary
    case .alcoholFree: primary
    case .low: scheme == .dark ? .white : .black
    case .medium, .high: scheme == .dark ? .black : .white
    }
  }
}

/// The card's fixed geometry. 360pt wide, sized for Messages (1.2 spec,
/// Feature D); everything inside is derived from that one number so the
/// arithmetic is stated here rather than discovered at layout time.
enum ShareCardLayout {
  static let width: CGFloat = 360
  static let contentWidth: CGFloat = width - 2 * GlassTokens.Spacing.section  // 312

  /// Month card: 7 × 41 + 6 × 4 = 311.
  static let monthCell: CGFloat = 41
  static let monthSpacing: CGFloat = 4

  /// Year card: three columns of (312 − 2 × 12) / 3 = 96pt, cells of
  /// (96 − 6 × 2) / 7 = 12pt, six rows reserved so every month's box is the
  /// same height whatever its leading blanks.
  static let miniColumns = 3
  static let miniGutter: CGFloat = 12
  static let miniRowGap: CGFloat = 16
  static let miniSpacing: CGFloat = 2
  static var miniColumnWidth: CGFloat {
    (contentWidth - CGFloat(miniColumns - 1) * miniGutter) / CGFloat(miniColumns)
  }
  static var miniCell: CGFloat {
    (miniColumnWidth - 6 * miniSpacing) / 7
  }
  static var miniGridHeight: CGFloat {
    6 * miniCell + 5 * miniSpacing
  }
}

/// The card's outer shape, ending on the wordmark — text alone, never the
/// mark (design-system §1, "The mark").
struct ShareCardFrame<Content: View>: View {
  let ink: ShareCardInk
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      content()

      Text(verbatim: "Tallyist")
        .font(.caption.weight(.semibold))
        .foregroundStyle(ink.secondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(GlassTokens.Spacing.section)
    .frame(width: ShareCardLayout.width)
    .background(ink.ground)
  }
}

/// The period's name, and under it where the record stops and how many days
/// it covers. "Through September 2" rather than "today": the image is read
/// later than it is made. Two localized captions side by side, never a
/// joined key.
struct ShareCardHeader: View {
  let title: Text
  /// The day the record stops, while the period is still in progress; nil
  /// once the period is whole, when the title already names all of it.
  let through: Date?
  let dayCount: Int
  let ink: ShareCardInk

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      title
        .font(.title2.weight(.semibold))
        .foregroundStyle(ink.primary)

      HStack(spacing: GlassTokens.Spacing.tight) {
        if let through {
          Text("Through \(through.formatted(.dateTime.month(.wide).day()))")
          Text(verbatim: "·")
        }
        Text(RecentSummaryCaptions.dayCount(dayCount))
      }
      .font(.caption)
      .foregroundStyle(ink.secondary)
    }
  }
}

/// ADR-0006's four figures with the unlogged count named — the calendar
/// card's own figures, from the same fold (`TrendSummary.summary(of:)`), in
/// the same order, with the same captions (`RecentSummaryCaptions`). A
/// `Grid` rather than the card's stacks: nothing lazy, nothing that depends
/// on a measured proposal, under `ImageRenderer`.
struct ShareCardFigures: View {
  let summary: RecentSummary
  let region: Region
  let ink: ShareCardInk

  /// The one caption that differs from the in-app card: "on days with
  /// drinks", not "on days you drank". The image is read by someone who is
  /// not its subject, and this reuses the first figure's own phrase so the
  /// reader sees which count the average divides by (ADR-0027).
  private let averageCaption: LocalizedStringKey = "on days with drinks"

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      Grid(
        alignment: .leading,
        horizontalSpacing: GlassTokens.Spacing.regular,
        verticalSpacing: GlassTokens.Spacing.regular
      ) {
        GridRow {
          figure(
            "\(summary.daysWithDrinks)",
            RecentSummaryCaptions.daysWithDrinks(summary.daysWithDrinks)
          )
          figure(
            "\(summary.daysAlcoholFree)",
            RecentSummaryCaptions.daysWithNone(summary.daysAlcoholFree)
          )
        }

        // A hairline in the card's own ink: a Divider would resolve a
        // system colour the renderer has no surface for.
        Rectangle()
          .fill(ink.secondary.opacity(0.3))
          .frame(height: 0.5)
          .gridCellColumns(2)

        GridRow {
          figure(
            StandardDrink.formatted(summary.totalStandardDrinks),
            RecentSummaryCaptions.total(summary.totalStandardDrinks, region: region)
          )
          figure(RecentSummaryCaptions.averageValue(summary), averageCaption)
        }
      }

      // Required on an image others read: two day-counts that do not sum to
      // the period leave a remainder a reader will take as alcohol-free
      // (ADR-0006). Hidden at zero, the in-app rule.
      if let unlogged = RecentSummaryCaptions.unlogged(summary.daysUnlogged) {
        Text(unlogged)
          .font(.caption)
          .foregroundStyle(ink.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func figure(_ value: String, _ caption: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(GlassTokens.Typography.cardValue)
        .foregroundStyle(ink.primary)
      Text(caption)
        .font(.caption)
        .foregroundStyle(ink.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// One month's cells, placed row by row from `MonthGrid.rows`. Days after
/// `today` fade to 0.3 — the in-app grid's own treatment of the future — and
/// on a mini grid, where a blank future day has no fill and no number, the
/// header's "Through" line is what carries the cutoff.
struct ShareCardDayGrid: View {
  let grid: MonthGrid
  let side: CGFloat
  let spacing: CGFloat
  let showsDayNumbers: Bool
  let today: Date
  let calendar: Calendar
  let ink: ShareCardInk

  var body: some View {
    let cutoff = calendar.startOfDay(for: today)
    Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
      ForEach(Array(grid.rows.enumerated()), id: \.offset) { _, row in
        GridRow {
          ForEach(Array(row.enumerated()), id: \.offset) { _, day in
            if let day {
              cell(day, isFuture: day.date > cutoff)
            } else {
              Color.clear.frame(width: side, height: side)
            }
          }
        }
      }
    }
  }

  private func cell(_ day: CalendarDay, isFuture: Bool) -> some View {
    let intensity = day.intensity
    let radius: CGFloat = side >= 20 ? 8 : 3
    return RoundedRectangle(cornerRadius: radius, style: .continuous)
      .fill(IntensityPalette.fill(intensity, scheme: ink.scheme))
      .frame(width: side, height: side)
      .overlay {
        if IntensityPalette.isOutlined(intensity) {
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(ink.secondary, lineWidth: side >= 20 ? 1.5 : 1)
        }
      }
      .overlay {
        if showsDayNumbers {
          // `format: .number`, not string interpolation: "\(n)" alone would
          // be the bare "%lld" key.
          Text(calendar.component(.day, from: day.date), format: .number)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(ink.cellInk(intensity))
        }
      }
      .opacity(isFuture ? 0.3 : 1)
  }
}

/// The five-entry legend, "Not logged" included: a blank cell with a
/// four-entry legend reads as zero to anyone who did not make the card.
/// Iterates the same list and keys as the in-app legend.
struct ShareCardLegend: View {
  let ink: ShareCardInk

  var body: some View {
    FlowLayout(spacing: GlassTokens.Spacing.regular) {
      ForEach(DayIntensity.legendOrder, id: \.self) { intensity in
        HStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(IntensityPalette.fill(intensity, scheme: ink.scheme))
            .overlay {
              RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(
                  // The unlogged swatch has no fill, so without a hairline
                  // there would be nothing beside its label at all.
                  IntensityPalette.isOutlined(intensity) || intensity == .unlogged
                    ? ink.secondary
                    : .clear,
                  lineWidth: 1
                )
            }
            .frame(width: 12, height: 12)
          Text(intensity.legendKey)
        }
      }
    }
    .font(.caption2)
    .foregroundStyle(ink.secondary)
  }
}

/// The one render path: 3× PNG through `ImageRenderer`, type size pinned.
///
/// The card is a 360pt document; a 7-column grid or a 2×2 cannot reflow at
/// accessibility sizes, so the render pins `.large` and the in-app card and
/// cells remain the Dynamic Type and VoiceOver surface. PNG data from
/// `pngData()` carries no EXIF beyond orientation, resolution, and pixel
/// size — verified by chunk inspection on the shipped month card.
enum ShareCardRenderer {
  @MainActor
  static func png(_ content: some View, scheme: ColorScheme) -> Data? {
    let renderer = ImageRenderer(
      content: content
        .environment(\.colorScheme, scheme)
        .dynamicTypeSize(.large)
    )
    renderer.scale = 3
    renderer.proposedSize = ProposedViewSize(width: ShareCardLayout.width, height: nil)
    return renderer.uiImage?.pngData()
  }
}
