import CoreTransferable
import DrinkTrackerCore
import SwiftUI
import UniformTypeIdentifiers

/// The year share card (ADR-0027): the year view, as an image.
///
/// Same terms as the month card — user-initiated from the year view's own
/// toolbar, built at share time, nothing persisted, nothing logged. The
/// year's name, where the record stops, the calendar card's four figures for
/// the days through today with unlogged days named, twelve mini grids, the
/// legend. No comparison to anyone.
struct YearShareImage: Transferable {
  let year: Int
  let grids: [MonthGrid]
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
    .suggestedFileName { card in
      String(format: "tallyist-%04d.png", card.year)
    }
  }

  @MainActor
  func renderPNG(today: Date) -> Data? {
    let summary = TrendSummary.yearSummary(grids, through: today, calendar: calendar)
    return ShareCardRenderer.png(
      YearShareCardView(
        year: year, grids: grids, summary: summary, today: today,
        region: region, calendar: calendar, ink: ShareCardInk(scheme: colorScheme)
      ),
      scheme: colorScheme
    )
  }
}

struct YearShareCardView: View {
  let year: Int
  let grids: [MonthGrid]
  let summary: RecentSummary
  let today: Date
  let region: Region
  let calendar: Calendar
  let ink: ShareCardInk

  private var through: Date? {
    summary.dayCount < grids.reduce(0) { $0 + $1.days.count } ? today : nil
  }

  var body: some View {
    ShareCardFrame(ink: ink) {
      // The year as text, never a numeric placeholder, which prints "2,026".
      ShareCardHeader(
        title: Text(verbatim: String(year)),
        through: through,
        dayCount: summary.dayCount,
        ink: ink
      )

      ShareCardFigures(summary: summary, region: region, ink: ink)

      // Three columns by four rows, all twelve always drawn so the shape is
      // the same every year; 12pt cells survive Messages' bubble scaling
      // where a four-column card's 8pt ones would not.
      Grid(horizontalSpacing: ShareCardLayout.miniGutter, verticalSpacing: ShareCardLayout.miniRowGap) {
        ForEach(Array(stride(from: 0, to: grids.count, by: ShareCardLayout.miniColumns)), id: \.self) { start in
          GridRow {
            ForEach(grids[start..<min(start + ShareCardLayout.miniColumns, grids.count)]) { grid in
              MiniMonthCard(grid: grid, today: today, calendar: calendar, ink: ink)
            }
          }
        }
      }

      ShareCardLegend(ink: ink)
    }
  }
}

/// One month of the year card: its abbreviated name over a 12pt grid, six
/// rows reserved so the four rows of months align whatever their leading
/// blanks.
private struct MiniMonthCard: View {
  let grid: MonthGrid
  let today: Date
  let calendar: Calendar
  let ink: ShareCardInk

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(verbatim: grid.month.formatted(.dateTime.month(.abbreviated)))
        .font(.caption2.weight(.semibold))
        .foregroundStyle(ink.secondary)

      ShareCardDayGrid(
        grid: grid,
        side: ShareCardLayout.miniCell,
        spacing: ShareCardLayout.miniSpacing,
        showsDayNumbers: false,
        today: today,
        calendar: calendar,
        ink: ink
      )
      .frame(height: ShareCardLayout.miniGridHeight, alignment: .top)
    }
    .frame(width: ShareCardLayout.miniColumnWidth, alignment: .leading)
  }
}
