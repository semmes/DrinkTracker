import DrinkTrackerCore
import SwiftUI

/// The population comparison's sentences, in one place, so the Trends card
/// (the trailing window) and the year view (a complete year) say the same
/// things in the same words (ADR-0018, ADR-0030, ADR-0031).
///
/// Copy rules from the 1.2 spec, kept literally: "lower than", never "better
/// than"; no congratulation and no warning in either direction; the source
/// and its year visible; the note says what this is and is not. Every
/// function returns a key so the sentence reaches the catalog and a
/// translation can reorder the interpolations.
///
/// The volume comparison names the survey column it read (ADR-0039): "US
/// adults", "US men" or "US women" who drink — one key per column and
/// direction, never a noun interpolated into a shared sentence, so a
/// translation can decline it. The note's drinkers share follows the column
/// from the bundled file, so a data-file change cannot leave the note
/// stating the wrong number.
enum PopulationReferenceCopy {

  /// "Your average is about 4 standard drinks a week." One key per region
  /// and number: the noun's form follows the displayed digits.
  static func averageLine(_ units: Double, region: Region) -> LocalizedStringKey {
    let value = StandardDrink.formatted(units)
    let isSingular = StandardDrink.readsAsOne(units)
    switch region {
    case .unitedStates, .australia:
      return isSingular
        ? "Your average is about \(value) standard drink a week."
        : "Your average is about \(value) standard drinks a week."
    case .unitedKingdom:
      return isSingular
        ? "Your average is about \(value) unit a week."
        : "Your average is about \(value) units a week."
    }
  }

  /// The same sentence for a year that has ended: "In 2025, your average was
  /// about 4 standard drinks a week." The year goes in as text, never a
  /// grouped number.
  static func yearAverageLine(_ units: Double, year: Int, region: Region) -> LocalizedStringKey {
    let value = StandardDrink.formatted(units)
    let name = String(year)
    let isSingular = StandardDrink.readsAsOne(units)
    switch region {
    case .unitedStates, .australia:
      return isSingular
        ? "In \(name), your average was about \(value) standard drink a week."
        : "In \(name), your average was about \(value) standard drinks a week."
    case .unitedKingdom:
      return isSingular
        ? "In \(name), your average was about \(value) unit a week."
        : "In \(name), your average was about \(value) units a week."
    }
  }

  static func noDrinks(in window: PopulationReference.Window) -> LocalizedStringKey {
    switch window {
    case .fourWeeks: "No drinks in the last 4 weeks."
    case .twelveMonths: "No drinks in the last 12 months."
    }
  }

  static func noDrinks(inYear year: Int) -> LocalizedStringKey {
    "No drinks logged in \(String(year))."
  }

  static func comparisonLine(_ comparison: PopulationReference.Comparison, in column: PopulationReference.Column) -> LocalizedStringKey {
    switch (comparison, column) {
    case (.lowerThan(let percent), .allAdults):
      "That's lower than roughly \(percent)% of US adults who drink."
    case (.moreThan(let percent), .allAdults):
      "That's more than roughly \(percent)% of US adults who drink."
    case (.lowerThan(let percent), .men):
      "That's lower than roughly \(percent)% of US men who drink."
    case (.moreThan(let percent), .men):
      "That's more than roughly \(percent)% of US men who drink."
    case (.lowerThan(let percent), .women):
      "That's lower than roughly \(percent)% of US women who drink."
    case (.moreThan(let percent), .women):
      "That's more than roughly \(percent)% of US women who drink."
    }
  }

  /// "You logged drinks on 9 of the last 28 days." — the calendar's own
  /// count over the card's window.
  static func drinkingDaysLine(_ days: Int, of windowDays: Int) -> LocalizedStringKey {
    "You logged drinks on \(days) of the last \(windowDays) days."
  }

  /// "US adults who drink average about 7 in 28." — a published mean, scaled
  /// to the same window and rounded to whole days: a mean over a population
  /// is not a figure a tenth of a day can be checked against.
  static func drinkingDaysReferenceLine(_ reference: FrequencyReference, windowDays: Int) -> LocalizedStringKey {
    let mean = Int(reference.drinkingDays(per: windowDays).rounded())
    return "US adults who drink average about \(mean) in \(windowDays)."
  }

  /// The weekly average's source, on Trends and on the year view alike — one
  /// constant, read by both, which is what stops the two surfaces' source
  /// lines from drifting.
  ///
  /// It was `yearSource` while the year view was the only surface naming this
  /// one body of work alone; on Trends the survey shared a "·"-joined line with
  /// NESARC-III. Since ADR-0038's 2026-09-10 amendment each comparison is its
  /// own card and names exactly the source behind it, so the joined line — and
  /// with it a source line whose wording was a function of which switches were
  /// on — is gone. Same string, same catalog key.
  static let surveySource: LocalizedStringKey = "Source: Alcohol Research Group, 2020 National Alcohol Survey"

  /// The drinking-days card's source.
  static let daysSource: LocalizedStringKey = "Source: NIAAA, NESARC-III, 2012–13"

  /// The note's first paragraph: what the percentages are and are not, for
  /// the column that was read. `drinkersPercent` is the file's own figure
  /// (100 less the column's abstainers — 72, 75 or 69), printed whole.
  static func explainer(in column: PopulationReference.Column, drinkersPercent: Double) -> LocalizedStringKey {
    let percent = Int(drinkersPercent.rounded())
    switch column {
    case .allAdults:
      return "A published population statistic, not data from other Tallyist users — nothing about your log leaves this device. Percentages come from the survey's distribution of weekly drinks among US adults, recalculated to cover only the \(percent)% who reported drinking, and compared by grams of alcohol."
    case .men:
      return "A published population statistic, not data from other Tallyist users — nothing about your log leaves this device. Percentages come from the survey's distribution of weekly drinks among US men, recalculated to cover only the \(percent)% who reported drinking, and compared by grams of alcohol."
    case .women:
      return "A published population statistic, not data from other Tallyist users — nothing about your log leaves this device. Percentages come from the survey's distribution of weekly drinks among US women, recalculated to cover only the \(percent)% who reported drinking, and compared by grams of alcohol."
    }
  }

  /// Which span the average covers, stated plainly. The twelve-month window
  /// is offered once the record supports it; a single heavy week moves a
  /// four-week average by a quarter and a year hardly at all.
  static func windowNote(_ window: PopulationReference.Window) -> LocalizedStringKey {
    switch window {
    case .fourWeeks: "Your average covers your last 4 weeks."
    case .twelveMonths: "Your average covers your last 12 months, the span the survey asked about."
    }
  }

  static func yearWindowNote(_ year: Int) -> LocalizedStringKey {
    "Your average covers all of \(String(year))."
  }

  static let drinkingDaysNote: LocalizedStringKey =
    "Drinking days come from NESARC-III, 2012–13: a published mean among US adults who drank in the past year, scaled to the same number of days."

  // MARK: - Weekdays (ADR-0032)

  static let weekdaySource: LocalizedStringKey = "Source: Liang and Chikritzhs, 2015 (NHANES 2005–10)"

  /// "Friday to Sunday: 6 of 13 days with a drink." — the user's own split on
  /// the paper's definition of the weekend.
  static func weekendLine(_ split: WeekendSplit) -> LocalizedStringKey {
    "Friday to Sunday: \(split.weekendDaysWithDrinks) of \(split.weekendDays) days with a drink."
  }

  static func weekdaysLine(_ split: WeekendSplit) -> LocalizedStringKey {
    "Monday to Thursday: \(split.otherDaysWithDrinks) of \(split.otherDays) days."
  }

  /// "Among US adults, 31 of every 100 Friday-to-Sunday days include a drink,
  /// and 24 of every 100 other days." Rounded to whole days per hundred.
  static func weekendReferenceLine(_ reference: WeekendReference) -> LocalizedStringKey {
    let weekend = Int(reference.weekendEpisodesPer100Days.rounded())
    let other = Int(reference.otherEpisodesPer100Days.rounded())
    return "Among US adults, \(weekend) of every 100 Friday-to-Sunday days include a drink, and \(other) of every 100 other days."
  }

  static let weekendNote: LocalizedStringKey =
    "A published rate from a national dietary survey of US adults, 2005 to 2010, drinkers and non-drinkers together: days with a drink of 10 grams of alcohol or more, per 100 person-days, with the weekend as the study defined it. Not data from other Tallyist users."
}

/// The tappable source line with the note it opens — a Button, not
/// `onTapGesture` on the card, because gestures on glass-backed containers
/// get swallowed (the session-pace toggle taught the lesson).
struct SourceDisclosure<Note: View>: View {
  let sources: LocalizedStringKey
  @ViewBuilder let note: () -> Note

  @State private var isExpanded = false

  var body: some View {
    Button {
      withAnimation(.smooth(duration: 0.25)) { isExpanded.toggle() }
    } label: {
      HStack(spacing: GlassTokens.Spacing.tight) {
        Text(sources)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
        Spacer()
        Image(systemName: "chevron.down")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(isExpanded ? 180 : 0))
      }
      .contentShape(.rect)
      .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(sources))
    .accessibilityHint("Explains this comparison")

    if isExpanded {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        note()
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}
