import CoreTransferable
import DrinkTrackerCore
import SwiftUI
import UniformTypeIdentifiers

/// The month share card (1.2 spec, Feature D; ADR-0027): a one-way image
/// export of one month.
///
/// User-initiated every time — the ShareLink in the calendar's toolbar is the
/// only way in; no prompts, no nudges. The PNG is built at share time from
/// raw data (no temp file, nothing persisted, nothing logged about sharing).
/// Content is the user's own month and nothing else: the month's name, where
/// the record stops, the calendar card's four figures for those days with
/// unlogged days named, the grid, the legend. No comparison to anyone.
struct MonthShareImage: Transferable {
  let grid: MonthGrid
  let region: Region
  let colorScheme: ColorScheme
  let calendar: Calendar

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { card in
      let data = await MainActor.run { card.renderPNG(today: Date()) }
      guard let data else {
        throw CocoaError(.fileWriteUnknown)
      }
      return data
    }
    // Per item, through the (Item) -> String? overload: a period is not an
    // identifier, and it stops "Save to Files" stacking identical names.
    // Still a DataRepresentation — no temp file. Year and month come from
    // the calendar's own components, not an ISO format, which would render
    // in UTC and name August for a September 1st east of Greenwich.
    .suggestedFileName { card in
      let parts = card.calendar.dateComponents([.year, .month], from: card.grid.month)
      return String(format: "tallyist-%04d-%02d.png", parts.year ?? 0, parts.month ?? 0)
    }
  }

  /// `today` is read once, here, and handed to the summary, the "Through"
  /// line, and the future-day fade, so the three cannot disagree.
  @MainActor
  func renderPNG(today: Date) -> Data? {
    let summary = TrendSummary.monthSummary(grid, through: today, calendar: calendar)
    return ShareCardRenderer.png(
      MonthShareCardView(
        grid: grid, summary: summary, today: today,
        region: region, calendar: calendar, ink: ShareCardInk(scheme: colorScheme)
      ),
      scheme: colorScheme
    )
  }
}

/// The purpose-built layout — never a screenshot of the live Calendar view.
/// Figures before the grid: count is the hero (design-system §1), and the
/// unlogged sentence sits directly under the two day-counts it qualifies.
struct MonthShareCardView: View {
  let grid: MonthGrid
  let summary: RecentSummary
  let today: Date
  let region: Region
  let calendar: Calendar
  let ink: ShareCardInk

  /// Data-derived, like the in-app heading: a day was clipped.
  private var through: Date? {
    summary.dayCount < grid.days.count ? today : nil
  }

  var body: some View {
    ShareCardFrame(ink: ink) {
      ShareCardHeader(
        title: Text(verbatim: grid.month.formatted(.dateTime.month(.wide).year())),
        through: through,
        dayCount: summary.dayCount,
        ink: ink
      )

      ShareCardFigures(summary: summary, region: region, ink: ink)

      VStack(spacing: ShareCardLayout.monthSpacing) {
        weekdayHeader
        ShareCardDayGrid(
          grid: grid,
          side: ShareCardLayout.monthCell,
          spacing: ShareCardLayout.monthSpacing,
          showsDayNumbers: true,
          today: today,
          calendar: calendar,
          ink: ink
        )
      }

      ShareCardLegend(ink: ink)
    }
  }

  /// A reader away from the app has no other way to know which column is
  /// which. Rotated to the calendar's first weekday, as the in-app header is;
  /// identity by position, because very-short symbols repeat.
  private var weekdayHeader: some View {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let offset = calendar.firstWeekday - 1
    let ordered = Array(symbols[offset...] + symbols[..<offset])
    return HStack(spacing: ShareCardLayout.monthSpacing) {
      ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
        Text(verbatim: symbol)
          .font(.caption2)
          .foregroundStyle(ink.secondary)
          .frame(width: ShareCardLayout.monthCell)
      }
    }
  }
}
