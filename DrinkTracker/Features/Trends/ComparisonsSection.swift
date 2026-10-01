import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// The published comparisons at the bottom of Trends, under one heading that
/// names them (ADR-0038's 2026-09-10 amendment), in one card segmented by their
/// titles (its 2026-09-23 amendment), over the range the picker chose
/// (ADR-0058).
///
/// Settings → Comparisons carries three switches — "Weekly average",
/// "Drinking days", "Weekend and weekdays" — and until this section existed a
/// reader could flip one and watch an unnamed block appear or vanish. Each
/// switch has one segment carrying that switch's own title (the third titled
/// by its measure, "Days with a drink"), under a COMPARISONS heading that reads
/// as Settings' own section does, in the switches' own order. The segments
/// share one glass card, a hairline between each shown segment and the next —
/// the owner's request of 2026-09-23, and the reopen the 2026-09-10 amendment
/// named for three source rows reading as chrome. Each segment keeps its own
/// source line, so no source line's wording depends on which switches are on.
///
/// ## One set of days
///
/// All three segments read the fold `TrendsView` makes for the chart card —
/// the range's own days, cut at the first record while the log is younger than
/// the range — so their figures are the header's figures and cannot drift from
/// them (ADR-0058). Until then the first two ran their own queries and their own
/// clock over ADR-0030's window, 28 days and then 364, whatever the picker said;
/// at Quarter the card read 12.5 a week over 28 days under a chart reading 158.9
/// over 88. Nothing here reads the store or the clock now, so the section has no
/// failure of its own to report: `TrendsView` draws its unreadable state before
/// it draws this.
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
/// literal disjunction of the three. No segment re-checks its own switch. That
/// is structural, not a discipline: a heading — or a card — over an empty
/// section is impossible to write without deleting the `if` it lives in — the
/// `asksType` lesson from ADR-0034's amendment, where a view read the answer to
/// its own question. The dividers follow the same rule: each is drawn by the
/// segment below it, and only when a segment above it is shown. And the fold
/// arrives nil while the record is under the floor, so no segment can be drawn
/// without the days it covers.
struct ComparisonsSection: View {
  /// The window's figures, or nil while the record holds fewer than
  /// `TrendWindow.comparisonFloor` days (ADR-0058): one floor for all three
  /// comparisons, at every range, Week included.
  let fold: TrendWindowFold?
  let region: Region

  @Environment(AppSettings.self) private var settings

  var body: some View {
    let shown = resolve()

    if let fold, !shown.isEmpty {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        SectionLabel("Comparisons")

        SUCard(model: .glass) {
          VStack(alignment: .leading, spacing: 0) {
            if let reference = shown.average {
              WeeklyAverageComparison(
                reference: reference,
                fold: fold,
                region: region,
                column: settings.comparisonColumn,
                isFollowed: shown.days != nil || shown.weekend != nil
              )
            }

            if let frequency = shown.days {
              if shown.average != nil { SegmentDivider() }
              DrinkingDaysComparison(
                frequency: frequency,
                fold: fold,
                isFollowed: shown.weekend != nil
              )
            }

            if let weekend = shown.weekend {
              if shown.average != nil || shown.days != nil { SegmentDivider() }
              WeekendComparison(split: weekend.split, reference: weekend.reference, window: fold.window)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
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
    var average: PopulationReference?
    var days: FrequencyReference?
    var weekend: (reference: WeekendReference, split: WeekendSplit)?

    var isEmpty: Bool { average == nil && days == nil && weekend == nil }
  }

  /// One gate per comparison: the reader's switch, its own bundled file, and
  /// the record's floor, which the fold being here at all already says. Never
  /// a placeholder for a missing source: no file, no comparison. Each reads
  /// only its own file now — the drinking days used to require the survey's
  /// file too, a quirk of the population window they shared, and the window
  /// they share is the range's.
  private func resolve() -> Shown {
    var shown = Shown()
    guard let fold else { return shown }

    if settings.showsWeeklyAverageComparison, let reference = PopulationReference.bundled {
      shown.average = reference
    }
    if settings.showsDrinkingDaysComparison, let frequency = FrequencyReference.bundled {
      shown.days = frequency
    }
    // The record's floor, not four weeks of range (ADR-0058, reversing
    // ADR-0038's floor): Week's three Friday-to-Sunday days and four others sit
    // beside the published rate once the log is four weeks old.
    if settings.showsWeekendComparison, let reference = WeekendReference.bundled {
      shown.weekend = (reference, TrendSummary.weekendSplit(fold.weekdays, weekend: reference.weekendWeekdays))
    }

    return shown
  }
}
