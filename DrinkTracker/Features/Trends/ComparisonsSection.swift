import DrinkTrackerCore
import SwiftData
import SwiftUI

/// The published comparisons at the bottom of Trends, under one heading that
/// names them (ADR-0038's 2026-09-10 amendment).
///
/// Settings → Comparisons carries three switches — "Weekly average",
/// "Drinking days", "Weekend and weekdays" — and until this section existed a
/// reader could flip one and watch an unnamed block appear or vanish. Each
/// switch now has one card carrying that switch's own title, under a
/// COMPARISONS heading that reads as Settings' own section does, in the
/// switches' own order.
///
/// ## Why the seven weekday rows are not in here
///
/// `WeekdayCard` sits *above* this section and stays outside it. Its rows are
/// the reader's own log, and ADR-0038 says in as many words that they "never
/// depend on" the weekend switch. A heading spanning them would do worse than
/// mislabel: ADR-0032 refuses, in its Decision, to name a busiest day or relate
/// one weekday to another, and the card's own aligned columns exist so that
/// "alignment does the comparing that the copy refuses to do" — putting the
/// word *Comparisons* over them would make the copy do it. So the weekend
/// comparison moved down here instead, and the rows stayed put.
///
/// ## The heading cannot outlive its content
///
/// All three gates are resolved once, here, and the heading's condition is the
/// literal disjunction of the three. No card re-checks its own switch. That is
/// structural, not a discipline: a heading over an empty section is impossible
/// to write without deleting the `if` it lives in — the `asksType` lesson from
/// ADR-0034's amendment, where a view read the answer to its own question.
struct ComparisonsSection: View {
  /// The range's seven weekday totals, already folded by `TrendsView` — the
  /// same array the card above prints, so the two cannot disagree about the
  /// range.
  let weekdayTotals: [WeekdayTotal]
  let region: Region
  let calendar: Calendar

  @Environment(AppSettings.self) private var settings

  // Moved verbatim from `PopulationReferenceCard`, sort orders included.
  // Deliberately *not* folded into `TrendsView.Snapshot`: that view's own
  // entry query is `.reverse`, so the consolidation would have to read
  // `allEntries.last` where these read `.first`, and the first recorded fact
  // is what the whole four-week gate hangs on. No test tier reaches it.
  @Query(sort: \DrinkEntry.loggedAt, order: .forward) private var entries: [DrinkEntry]
  @Query(sort: \AlcoholFreeDay.day, order: .forward) private var freeDays: [AlcoholFreeDay]

  var body: some View {
    // A fresh clock, as the combined card has read it since 1.2 — not
    // `TrendsView.today`. It decides when the four-week record gate flips and
    // where the two windows are cut, so moving it is a behaviour change, and
    // this change renders nothing.
    let now = Date()
    let shown = resolve(now: now)

    if !shown.isEmpty {
      // Mapped once for both cards, as the combined card mapped it once for
      // both blocks: `loggedDrinks` walks the whole log, and reading it per
      // card would allocate a second copy of it on every body pass.
      let drinks = entries.loggedDrinks

      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        SectionLabel("Comparisons")

        if let population = shown.average {
          WeeklyAverageCard(
            reference: population.reference,
            window: population.window,
            drinks: drinks,
            region: region,
            column: settings.comparisonColumn,
            now: now,
            calendar: calendar
          )
        }

        if let days = shown.days {
          DrinkingDaysCard(
            frequency: days.reference,
            window: days.window,
            drinks: drinks,
            now: now,
            calendar: calendar
          )
        }

        if let weekend = shown.weekend {
          WeekendComparisonCard(split: weekend.split, reference: weekend.reference)
        }
      }
      // `TrendsView`'s stack is centre-aligned, so a leading-aligned section
      // would otherwise render its heading down the middle — the modifier
      // `SettingsSection` carries for the same reason.
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Gates

  /// What is actually on screen, resolved once. Every field is nil when its
  /// comparison is not shown, for any reason: the reader's switch, a missing
  /// bundled file, or too little record.
  private struct Shown {
    var average: (reference: PopulationReference, window: PopulationReference.Window)?
    var days: (reference: FrequencyReference, window: PopulationReference.Window)?
    var weekend: (reference: WeekendReference, split: WeekendSplit)?

    var isEmpty: Bool { average == nil && days == nil && weekend == nil }
  }

  private func resolve(now: Date) -> Shown {
    var shown = Shown()

    // The population window is one umbrella over both of the first two, and
    // it is preserved exactly as the combined card had it: *both* blocks
    // required the survey file and a non-nil window, even though the
    // drinking-days lines only read `FrequencyReference`. That quirk is
    // inherited, not a new rule — tidying it is a one-line change that wants
    // a render of its own.
    if let reference = PopulationReference.bundled,
      let window = PopulationReference.window(firstRecord: firstRecord, now: now) {
      if settings.showsWeeklyAverageComparison {
        shown.average = (reference, window)
      }
      // Never a placeholder for a missing source: no file, no comparison.
      if settings.showsDrinkingDaysComparison, let frequency = FrequencyReference.bundled {
        shown.days = (frequency, window)
      }
    }

    // Four weeks of *range*, not of record (ADR-0038): the split is a fact
    // about the range shown, and a Week range puts three Friday-to-Sunday days
    // beside a rate per hundred person-days.
    if settings.showsWeekendComparison, let reference = WeekendReference.bundled {
      let split = TrendSummary.weekendSplit(weekdayTotals, weekend: reference.weekendWeekdays)
      if split.isComparable {
        shown.weekend = (reference, split)
      }
    }

    return shown
  }

  /// The first recorded fact — an entry or an alcohol-free marker.
  private var firstRecord: Date? {
    [entries.first?.loggedAt, freeDays.first?.day].compactMap { $0 }.min()
  }
}
