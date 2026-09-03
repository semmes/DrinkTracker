import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Twelve months at once — the shape of a year rather than any single day.
///
/// Cells here are a few points across, far below a touch target, so nothing is
/// tappable: this is a reading surface. Tapping a month's name goes back to the
/// month view, which is where days are edited.
///
/// This is the view the single-hue ramp exists for. At this density hue is nearly
/// useless — the eye is reading lightness, and lightness is the channel that
/// survives every form of colour vision deficiency.
///
/// The page ends on the same four figures the month view's card carries, for
/// the year shown (ADR-0026): whole for a past year, January 1 through today
/// for the current one. Twelve named months match exactly one window, so
/// there is no picker here.
struct YearView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(\.scenePhase) private var scenePhase

  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var allEntries: [DrinkEntry]
  @Query private var alcoholFreeDays: [AlcoholFreeDay]

  @State private var year: Int = Calendar.current.component(.year, from: Date())

  /// Start of the current calendar day, refreshed on the day-change
  /// notification and on foregrounding — the same reason `CalendarView`
  /// holds one: "2025, through today" has to become "2025" on January 1
  /// without waiting for something else to re-render.
  @State private var today: Date = Calendar.current.startOfDay(for: Date())

  private var calendar: Calendar { .current }

  private let columns = [
    GridItem(.flexible(), spacing: 20),
    GridItem(.flexible(), spacing: 20)
  ]

  var body: some View {
    // Built once per render and handed to everything below: the twelve grids
    // cost a walk over the whole log, and the card would otherwise pay it
    // again.
    let grids = self.grids
    let summary = TrendSummary.yearSummary(grids, through: today, calendar: calendar)
    let yearDayCount = grids.reduce(0) { $0 + $1.days.count }

    ScrollView {
      VStack(spacing: GlassTokens.Spacing.section) {
        yearHeader

        LazyVGrid(columns: columns, spacing: GlassTokens.Spacing.section) {
          ForEach(grids) { grid in
            MiniMonth(grid: grid, calendar: calendar)
          }
        }

        IntensityLegend(isCompact: true)

        // A year grid that is mostly blank looks like a year of not drinking.
        // At 11pt cells the legend's "Not logged" swatch needs the words, and
        // the card below names how many days that is.
        Text("Blank days are days without a record, not days without alcohol.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)

        RecentSummaryCard(
          summary: summary,
          region: settings.effectiveRegion,
          heading: .year(year, isClipped: summary.dayCount < yearDayCount)
        )
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle(String(year))
    .navigationBarTitleDisplayMode(.large)
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { today = calendar.startOfDay(for: Date()) }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      today = calendar.startOfDay(for: Date())
    }
  }

  // MARK: - Data

  private var markedDays: Set<Date> {
    Set(alcoholFreeDays.map(\.day))
  }

  private var grids: [MonthGrid] {
    TrendSummary.yearGrids(
      year,
      totalsByDay: TrendSummary.totalsByDay(
        allEntries.loggedDrinks,
        region: settings.effectiveRegion,
        calendar: calendar
      ),
      alcoholFreeDays: markedDays,
      calendar: calendar
    )
  }

  // MARK: - Header

  private var yearHeader: some View {
    HStack {
      Button {
        year -= 1
      } label: {
        Image(systemName: "chevron.left")
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .accessibilityLabel("Previous year")

      Spacer()

      Text(String(year))
        .font(GlassTokens.Typography.sheetTitle)
        .contentTransition(.numericText(value: Double(year)))

      Spacer()

      Button {
        year += 1
      } label: {
        Image(systemName: "chevron.right")
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .accessibilityLabel("Next year")
      .disabled(isCurrentYear)
      .opacity(isCurrentYear ? 0.3 : 1)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.accentColor)
    .animation(.snappy(duration: 0.2), value: year)
  }

  private var isCurrentYear: Bool {
    year >= calendar.component(.year, from: today)
  }
}

/// One month of the year grid.
private struct MiniMonth: View {
  let grid: MonthGrid
  let calendar: Calendar

  @Environment(AppSettings.self) private var settings

  private let side: CGFloat = 11
  private let spacing: CGFloat = 2

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Text(grid.month.formatted(.dateTime.month(.abbreviated)))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)

      LazyVGrid(
        columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: 7),
        spacing: spacing
      ) {
        ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
          Color.clear.frame(width: side, height: side)
        }
        ForEach(grid.days) { day in
          IntensityCell(day: day, showsDayNumber: false, side: side, region: settings.effectiveRegion)
        }
      }
    }
    // One element per month rather than 31: swiping through 365 individually
    // labelled cells to cross a year is not navigation, it's an obstacle.
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(monthDescription)
  }

  private var monthDescription: String {
    let name = grid.month.formatted(.dateTime.month(.wide))
    let counts = Dictionary(grouping: grid.days, by: \.intensity).mapValues(\.count)
    let recorded = grid.recordedDayCount
    guard recorded > 0 else { return "\(name), nothing recorded" }

    // The tallies are joined into one list, and `joined` needs String, so these
    // Deliberately a String, not a key: the fragments are joined into a list,
    // so the only key it could produce is "%@: %@" — punctuation with nothing
    // to translate. Making this properly translatable means building the list
    // differently, which is a copy change rather than a type change.
    var parts: [String] = []
    if let free = counts[.alcoholFree], free > 0 { parts.append("\(free) with no alcohol") }
    if let low = counts[.low], low > 0 { parts.append("\(low) with 1 to 2 drinks") }
    if let medium = counts[.medium], medium > 0 { parts.append("\(medium) with 3 to 5") }
    if let high = counts[.high], high > 0 { parts.append("\(high) with 6 or more") }
    return "\(name): \(parts.joined(separator: ", "))"
  }
}
