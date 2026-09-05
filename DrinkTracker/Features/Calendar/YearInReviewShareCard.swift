import CoreTransferable
import DrinkTrackerCore
import SwiftUI
import UniformTypeIdentifiers

/// The year-in-review card (ADR-0029): one complete calendar year as an
/// image — the year card's four figures over a chart of the year's twelve
/// monthly totals.
///
/// Same terms as the other two cards: user-initiated from the year view's
/// own share control, built at share time, nothing persisted, nothing logged
/// about the share. Offered only for a year that has ended and has something
/// recorded in it (`TrendSummary.isComplete`, `YearInReview.isOnRecord`); the
/// year in progress keeps the year card. No comparison to another year or
/// to anyone: the bars are the twelve month cards' own totals, and the
/// dashed line is the Trends chart's own monthly average.
struct YearInReviewImage: Transferable {
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
    // Distinct from the year card's `tallyist-2025.png`: the two are
    // different pictures of the same year and must not overwrite each other
    // in "Save to Files".
    .suggestedFileName { card in
      String(format: "tallyist-%04d-review.png", card.year)
    }
  }

  /// `today` is read once and handed to the review (which clips like every
  /// other window) and to the header, so a year that somehow reaches here
  /// in progress is labelled as such rather than drawn as whole.
  @MainActor
  func renderPNG(today: Date) -> Data? {
    let review = TrendSummary.yearInReview(grids, through: today, calendar: calendar)
    return ShareCardRenderer.png(
      YearInReviewCardView(
        year: year, review: review, yearDayCount: grids.reduce(0) { $0 + $1.days.count },
        today: today, region: region, calendar: calendar, ink: ShareCardInk(scheme: colorScheme)
      ),
      scheme: colorScheme
    )
  }
}

/// Figures before the chart, as on the other cards: count is the hero, and
/// the unlogged sentence sits under the counts it qualifies — directly above
/// a chart whose average counts those days as zero.
struct YearInReviewCardView: View {
  let year: Int
  let review: YearInReview
  let yearDayCount: Int
  let today: Date
  let region: Region
  let calendar: Calendar
  let ink: ShareCardInk

  /// Data-derived like the year card's: nil for the whole year the gate
  /// promises, today if a day was clipped.
  private var through: Date? {
    review.summary.dayCount < yearDayCount ? today : nil
  }

  var body: some View {
    ShareCardFrame(ink: ink) {
      // The year as text, never a numeric placeholder, which prints "2,026".
      ShareCardHeader(
        title: Text(verbatim: String(year)),
        through: through,
        dayCount: review.summary.dayCount,
        ink: ink
      )

      ShareCardFigures(summary: review.summary, region: region, ink: ink)

      ShareCardMonthlyChart(review: review, region: region, calendar: calendar, ink: ink)
    }
  }
}

/// The year's twelve monthly totals as bars, hand-drawn to the card's fixed
/// geometry (`ShareCardLayout`) rather than through Swift Charts: an
/// exported document needs the same pixels every time, and nothing here may
/// depend on a measured proposal under `ImageRenderer`.
///
/// What it draws, and only that: a caption naming the unit and the line, a
/// three-tick axis (0, half, top), one hairline at the middle, twelve bars in
/// the accent fill, a 1pt baseline, the dashed average, and the months'
/// initials. No label on the line — the caption carries its value — no top
/// gridline, no tallest-month callout, nothing relative to another year.
struct ShareCardMonthlyChart: View {
  let review: YearInReview
  let region: Region
  let calendar: Calendar
  let ink: ShareCardInk

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      caption
        .padding(.bottom, GlassTokens.Spacing.tight)

      HStack(alignment: .bottom, spacing: ShareCardLayout.chartAxisGap) {
        axis
        plot
      }

      HStack(spacing: ShareCardLayout.chartAxisGap) {
        Color.clear
          .frame(width: ShareCardLayout.chartAxisWidth, height: 0)
        monthLabels
      }
      .padding(.top, 4)
    }
  }

  // MARK: - Caption

  /// Two localized phrases around a middle dot, concatenated so the line
  /// wraps as one paragraph inside 312pt; never a joined key. "your
  /// average" is the Trends chart's own register for this line; the value
  /// is printed here rather than on the line itself. When the average is
  /// zero no line is drawn (see `plot`), so the caption must not name one:
  /// it is the first phrase alone, and twelve empty bars say the rest.
  private var caption: some View {
    captionText
      .font(.caption)
      .foregroundStyle(ink.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var captionText: Text {
    guard review.monthlyAverage > 0 else { return Text(unitsByMonth) }
    return Text(unitsByMonth)
      + Text(verbatim: " · ")
      + Text("the dashed line is your average, \(StandardDrink.formatted(review.monthlyAverage))")
  }

  /// A whole phrase per region, like `RecentSummaryCaptions.total`: the
  /// unit's name is not glued in from `unitNamePlural`, whose lowercase
  /// mid-sentence form would open the caption.
  private var unitsByMonth: LocalizedStringKey {
    switch region {
    case .unitedStates, .australia: "Standard drinks by month"
    case .unitedKingdom: "Units by month"
    }
  }

  // MARK: - Axis

  /// Three ticks, right-aligned, their bottoms at 0, 38 and 80pt so the
  /// middle one centres on the gridline. 9pt medium rounded: a derived
  /// figure, in the numerals' face, small enough to defer to the bars.
  private var axis: some View {
    ZStack(alignment: .bottomTrailing) {
      Color.clear
      tick(0)
      tick(review.axisMaximum / 2)
        .offset(y: -ShareCardLayout.chartMidTickBottom)
      tick(review.axisMaximum)
        .offset(y: -ShareCardLayout.chartTopTickBottom)
    }
    .frame(width: ShareCardLayout.chartAxisWidth, height: ShareCardLayout.chartPlotHeight)
  }

  /// `fixedSize`: a half-drink tick ("34.5") is wider than the 20pt column
  /// and must overflow leftward into the card's padding, never wrap.
  private func tick(_ value: Double) -> some View {
    Text(verbatim: StandardDrink.formatted(value))
      .font(.system(size: 9, weight: .medium, design: .rounded))
      .foregroundStyle(ink.secondary)
      .lineLimit(1)
      .fixedSize()
  }

  // MARK: - Plot

  private var plot: some View {
    let height = ShareCardLayout.chartPlotHeight
    let width = ShareCardLayout.chartPlotWidth
    let scale = height / review.axisMaximum

    return ZStack(alignment: .bottomLeading) {
      // One hairline at the middle, in the card's own ink (a Divider would
      // resolve a system colour the renderer has no surface for). No line
      // at the top: the axis tick says where the top is.
      Rectangle()
        .fill(ink.secondary.opacity(0.3))
        .frame(width: width, height: 0.5)
        .offset(y: -height / 2)

      HStack(alignment: .bottom, spacing: ShareCardLayout.chartBarGap) {
        ForEach(Array(review.monthlyTotals.enumerated()), id: \.offset) { _, total in
          // AccentFill, not accentColor: the fill token, 500 in both modes
          // (design-system review R2), so the bars are the same blue on
          // both grounds. A zero month is a zero-height bar — nothing
          // drawn, which is what a zero total is.
          UnevenRoundedRectangle(
            topLeadingRadius: ShareCardLayout.chartBarRadius,
            topTrailingRadius: ShareCardLayout.chartBarRadius,
            style: .continuous
          )
          .fill(Color("AccentFill"))
          .frame(maxWidth: .infinity)
          .frame(height: min(height, max(0, total * scale)))
        }
      }
      .frame(width: width, height: height, alignment: .bottom)

      Rectangle()
        .fill(ink.secondary)
        .frame(width: width, height: 1)

      // The Trends chart's own stroke ([4, 4] dashes, 1pt, secondary),
      // drawn last so it reads over the bars. At an average of zero the
      // line would lie on the baseline, so — as on Trends, which draws no
      // line at zero — it is left out, and the caption drops its clause.
      if review.monthlyAverage > 0 {
        Path { path in
          let y = height - min(height, review.monthlyAverage * scale)
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(ink.secondary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .frame(width: width, height: height)
      }
    }
    .frame(width: width, height: height)
  }

  // MARK: - Months

  /// The calendar's own one-letter month symbols, January first as the
  /// grids are — never a hardcoded "JFMAMJJASOND".
  private var monthLabels: some View {
    let symbols = calendar.veryShortStandaloneMonthSymbols
    return HStack(spacing: ShareCardLayout.chartBarGap) {
      ForEach(Array(symbols.prefix(12).enumerated()), id: \.offset) { _, symbol in
        Text(verbatim: symbol)
          .font(.system(size: 9))
          .foregroundStyle(ink.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .frame(width: ShareCardLayout.chartPlotWidth)
  }
}
