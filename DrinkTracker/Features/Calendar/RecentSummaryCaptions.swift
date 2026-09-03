import DrinkTrackerCore
import SwiftUI

/// The summary card's captions, in one place, so every surface that prints
/// ADR-0006's figures names them with the same words (ADR-0026): the calendar
/// card under the month grid and the year view's card; the share images adopt
/// them next (ADR-0027).
///
/// **The captions carry no count, and that is deliberate.** A catalog key can
/// only take plural variations if the count is inside it, so a language with
/// more than two plural forms gets two slots here and has to pick the one that
/// reads best. The alternative is a caption that repeats the number standing
/// 40 points above it, or dismantling the four-figure layout ADR-0006 exists to
/// protect. A caption under a number is doing different work from a sentence:
/// the number carries the meaning and the caption names it. Same kind of
/// documented limit as `Region.unitName(for:)`.
///
/// The spoken forms are where that trade is *not* accepted. VoiceOver fuses the
/// number and its caption into one sentence, with no adjacency left to carry
/// the meaning, so the two whole-number figures pass a single key holding the
/// count — genuinely pluralisable. The fractional figures have no spoken form:
/// their value reaches the catalog as `%@`, which no plural rule can select
/// on, so a separate key there would add nothing but another string to
/// translate.
enum RecentSummaryCaptions {

  static func daysWithDrinks(_ count: Int) -> LocalizedStringKey {
    count == 1 ? "day with drinks" : "days with drinks"
  }

  static func daysWithNone(_ count: Int) -> LocalizedStringKey {
    count == 1 ? "day with none" : "days with none"
  }

  /// The totals caption, as a whole phrase per region and number.
  ///
  /// It used to be `"\(region.unitNamePlural) total"`, which handed the noun in
  /// already inflected and always plural — so a total of exactly one read
  /// "1 standard drinks total". The two day figures had always agreed with
  /// their number; this one simply had not been made to follow.
  static func total(_ standardDrinks: Double, region: Region) -> LocalizedStringKey {
    let isSingular = StandardDrink.readsAsOne(standardDrinks)
    switch region {
    case .unitedStates, .australia:
      return isSingular ? "standard drink total" : "standard drinks total"
    case .unitedKingdom:
      return isSingular ? "unit total" : "units total"
    }
  }

  /// The caption under the average, in the app — addressed to the reader,
  /// who is the subject.
  static let averageCaption: LocalizedStringKey = "on days you drank"

  /// The average's displayed value: the figure, or an em dash when no day in
  /// the window has drinks. A mean over no days is not a number, and printing
  /// 0 would claim one that cannot be checked against the log — ADR-0006's
  /// whole test. The model keeps returning 0; this is display only.
  static func averageValue(_ summary: RecentSummary) -> String {
    summary.daysWithDrinks == 0 ? "—" : StandardDrink.formatted(summary.averageOnDrinkingDays)
  }

  /// Named rather than hidden. Without it the two day-counts look like they
  /// should add to the window, and a reader would reasonably assume the
  /// difference was alcohol-free rather than unrecorded. Nil at zero.
  static func unlogged(_ count: Int) -> LocalizedStringKey? {
    guard count > 0 else { return nil }
    let key: LocalizedStringKey = count == 1
      ? "\(count) day has nothing logged either way."
      : "\(count) days have nothing logged either way."
    return key
  }

  /// How many days the window covers, beside a month or year title — what
  /// keeps the three day-counts checkable once the window is no longer
  /// always 30. Singular chosen on the integer displayed.
  static func dayCount(_ count: Int) -> LocalizedStringKey {
    let key: LocalizedStringKey = count == 1 ? "1 day" : "\(count) days"
    return key
  }

  // MARK: - Spoken

  static func spokenDaysWithDrinks(_ count: Int) -> Text {
    count == 1 ? Text("\(count) day with drinks") : Text("\(count) days with drinks")
  }

  static func spokenDaysWithNone(_ count: Int) -> Text {
    count == 1 ? Text("\(count) day with none") : Text("\(count) days with none")
  }

  /// What the em dash says aloud: the absence, and why.
  static var spokenNoAverage: Text {
    Text("No days with drinks to average")
  }
}
