import DrinkTrackerCore
import SwiftUI

/// The population comparison's sentences, in one place, so the Trends card
/// (the range the picker chose, ADR-0058) and the year view (a complete year)
/// say the same things in the same words (ADR-0018, ADR-0030, ADR-0031).
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

  /// The Week range's sentence, where "Your average is about…" would be untrue
  /// of one week: seven days hold one of each weekday, so their total is the
  /// weekly figure and nothing is averaged (ADR-0058, decision 1). "You logged
  /// 13.2 standard drinks in the last 7 days." One key per region and number,
  /// as `averageLine`'s are.
  static func weekTotalLine(_ units: Double, region: Region) -> LocalizedStringKey {
    let value = StandardDrink.formatted(units)
    let isSingular = StandardDrink.readsAsOne(units)
    switch region {
    case .unitedStates, .australia:
      return isSingular
        ? "You logged \(value) standard drink in the last 7 days."
        : "You logged \(value) standard drinks in the last 7 days."
    case .unitedKingdom:
      return isSingular
        ? "You logged \(value) unit in the last 7 days."
        : "You logged \(value) units in the last 7 days."
    }
  }

  /// The weekly-average segment's sentence for a window: the Week range's own,
  /// or "Your average is about…" over every longer one. The folded sizes show
  /// it and VoiceOver reads it, so the two can never word the figure apart.
  static func weeklyLine(_ units: Double, window: TrendWindow, region: Region) -> LocalizedStringKey {
    window.range == .week && !window.isClipped
      ? weekTotalLine(units, region: region)
      : averageLine(units, region: region)
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

  /// The Comparisons card's figure line: "21 standard drinks a week", the
  /// figure set large and rounded because it is the reader's own (design
  /// system §3), the rest at the size of the text around it. The sentence
  /// above — "Your average is about 21 standard drinks a week." — is what
  /// VoiceOver reads and what the accessibility sizes show; this is its
  /// figure and noun, not a rewording. One key per region and number, the
  /// noun's form following the displayed digits, as `averageLine`'s do; the
  /// figure goes in as a `Text` so a translation can place it.
  static func averageFigure(_ units: Double, region: Region) -> Text {
    let figure = Text(verbatim: StandardDrink.formatted(units))
      .font(GlassTokens.Typography.cardValue)
      .foregroundColor(.primary)
    let isSingular = StandardDrink.readsAsOne(units)
    switch region {
    case .unitedStates, .australia:
      return isSingular
        ? Text("\(figure) standard drink a week")
        : Text("\(figure) standard drinks a week")
    case .unitedKingdom:
      return isSingular
        ? Text("\(figure) unit a week")
        : Text("\(figure) units a week")
    }
  }

  /// The span every segment's header names (ADR-0058): the range the picker
  /// chose, in the chart card's own words, or "Since Aug 12" while the log is
  /// younger than the range and the window starts at its first record. One
  /// function, read by all three segments, so no two of them can name
  /// different days.
  static func spanTitle(_ window: TrendWindow) -> Text {
    if let since = window.sinceText {
      return Text("Since \(since)")
    }
    return Text(rangeTitle(window.range))
  }

  /// The span a Trends range covers — the chart card's own titles.
  static func rangeTitle(_ range: TrendRange) -> LocalizedStringKey {
    switch range {
    case .week: "Last 7 days"
    case .month: "Last 30 days"
    case .quarter: "Last 13 weeks"
    case .year: "Last 12 months"
    }
  }

  /// The weekly-average segment's absence, stated over its own span.
  static func noDrinks(in window: TrendWindow) -> LocalizedStringKey {
    if let since = window.sinceText {
      return "No drinks since \(since)."
    }
    switch window.range {
    case .week: return "No drinks in the last 7 days."
    case .month: return "No drinks in the last 30 days."
    case .quarter: return "No drinks in the last 13 weeks."
    case .year: return "No drinks in the last 12 months."
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

  /// "You logged drinks on 46 of the last 88 days." — the Trends header's own
  /// count over the window. True of a clipped window too, whose days are the
  /// last N days by construction: the first record's day through today.
  static func drinkingDaysLine(_ days: Int, of windowDays: Int) -> LocalizedStringKey {
    "You logged drinks on \(days) of the last \(windowDays) days."
  }

  /// "US adults who drink average about 21 in 88." — a published mean, scaled
  /// to the same window and rounded to whole days: a mean over a population
  /// is not a figure a tenth of a day can be checked against.
  static func drinkingDaysReferenceLine(_ reference: FrequencyReference, windowDays: Int) -> LocalizedStringKey {
    let mean = reference.displayedDrinkingDays(per: windowDays)
    return "US adults who drink average about \(mean) in \(windowDays)."
  }

  /// The same sentence's predicate, beside its subject in the card's row:
  /// the row label reads "US adults who drink" and the figure "average about
  /// 7 in 28", so the row still reads as the reviewed sentence, split at the
  /// verb. The mean is the whole number its bar is drawn from.
  static func drinkingDaysReferenceFigure(_ reference: FrequencyReference, windowDays: Int) -> LocalizedStringKey {
    let mean = reference.displayedDrinkingDays(per: windowDays)
    return "average about \(mean) in \(windowDays)"
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
  ///
  /// The first sentence says where the comparing happens, in the shape of
  /// the Settings footnote since the owner's copy pass of 2026-09-23. It
  /// replaced "nothing about your log leaves this device", which reads alone
  /// as untrue of a log that syncs to iCloud. The derivation sentence is
  /// unchanged; ADR-0018 quotes it.
  static func explainer(in column: PopulationReference.Column, drinkersPercent: Double) -> LocalizedStringKey {
    let percent = Int(drinkersPercent.rounded())
    switch column {
    case .allAdults:
      return "Your average is compared on this device with a published population statistic, never with data from other Tallyist users. Percentages come from the survey's distribution of weekly drinks among US adults, recalculated to cover only the \(percent)% who reported drinking, and compared by grams of alcohol."
    case .men:
      return "Your average is compared on this device with a published population statistic, never with data from other Tallyist users. Percentages come from the survey's distribution of weekly drinks among US men, recalculated to cover only the \(percent)% who reported drinking, and compared by grams of alcohol."
    case .women:
      return "Your average is compared on this device with a published population statistic, never with data from other Tallyist users. Percentages come from the survey's distribution of weekly drinks among US women, recalculated to cover only the \(percent)% who reported drinking, and compared by grams of alcohol."
    }
  }

  /// Which span the figure covers, stated plainly, and, short of a year, that
  /// the survey asked about a year: its column is drinks a week averaged over
  /// the previous twelve months (ADR-0030), so a shorter span is placed on a
  /// distribution of yearly averages, and the note says so rather than letting
  /// the sentence imply otherwise (ADR-0058). At Week the subject is "this
  /// figure", because seven days' total is not an average.
  static func windowNote(_ window: TrendWindow) -> LocalizedStringKey {
    if let since = window.sinceText {
      return "Your average covers the days since \(since)."
    }
    switch window.range {
    case .week: return "This figure covers your last 7 days. The survey asked about a year."
    case .month: return "Your average covers your last 30 days. The survey asked about a year."
    case .quarter: return "Your average covers your last 13 weeks. The survey asked about a year."
    case .year: return "Your average covers your last 12 months, the span the survey asked about."
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
    let weekend = reference.displayedWeekendPer100Days
    let other = reference.displayedOtherPer100Days
    return "Among US adults, \(weekend) of every 100 Friday-to-Sunday days include a drink, and \(other) of every 100 other days."
  }

  static let weekendNote: LocalizedStringKey =
    "A published rate from a national dietary survey of US adults, 2005 to 2010, drinkers and non-drinkers together: days with a drink of 10 grams of alcohol or more, per 100 person-days, with the weekend as the study defined it. Not data from other Tallyist users."
}

extension TrendWindow {
  /// A clipped window's first day as every "Since" label prints it — "Aug 12",
  /// the month abbreviated and the day — or nil while the window is the
  /// range's own (ADR-0058). One format, read by the comparisons' spans and
  /// notes and by the total card's label, so the screen names one date. The
  /// day is inside the last twelve months, so no year is needed to read it.
  var sinceText: String? {
    guard isClipped, let firstDay else { return nil }
    return firstDay.formatted(.dateTime.month(.abbreviated).day())
  }
}

/// The tappable source line with the note it opens — a Button, not
/// `onTapGesture` on the card, because gestures on glass-backed containers
/// get swallowed (the session-pace toggle taught the lesson).
struct SourceDisclosure<Note: View>: View {
  let sources: LocalizedStringKey
  /// What VoiceOver says the line opens. The comparisons' own by default;
  /// the health pairing passes its own, because its card is not a
  /// comparison and must not be spoken as one (ADR-0050).
  var hint: LocalizedStringKey = "Explains this comparison"
  /// Space under the note while it is open. Zero where the note is the last
  /// thing in a card, whose own inset follows; the Comparisons card's segments
  /// pass the gap the closed source row leaves above their dividing rule, so
  /// an open note does not sit on it.
  var openNoteInset: CGFloat = 0
  @ViewBuilder let note: () -> Note

  @State private var isExpanded = false

  var body: some View {
    Button {
      withAnimation(.smooth(duration: 0.25)) { isExpanded.toggle() }
    } label: {
      HStack(spacing: GlassTokens.Spacing.tight) {
        Text(sources)
          .font(.caption)
          .foregroundStyle(.secondaryInk)
          .multilineTextAlignment(.leading)
        Spacer()
        Image(systemName: "chevron.down")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondaryInk)
          .rotationEffect(.degrees(isExpanded ? 180 : 0))
      }
      .contentShape(.rect)
      .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(sources))
    .accessibilityHint(Text(hint))

    if isExpanded {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        note()
      }
      .font(.caption)
      .foregroundStyle(.secondaryInk)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.bottom, openNoteInset)
    }
  }
}
