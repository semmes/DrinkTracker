import Foundation

/// How much was logged on a single day, bucketed for the calendar's colour ramp.
///
/// The buckets are deliberately coarse. A calendar cell is a few points across and
/// exists to show a *pattern* over weeks and months; the exact figure lives in the
/// day's own list, one tap away.
///
/// Ordering matters — `allCases` is legend order, and the raw values are the ramp's
/// step order — so cases are declared least to most.
public enum DayIntensity: String, CaseIterable, Sendable, Hashable {
  /// Nothing recorded. Not the same as a day with no alcohol: this is "we don't
  /// know", and every day before the app was installed is one of these. Collapsing
  /// the two would make the calendar claim a history it doesn't have.
  case unlogged

  /// Explicitly recorded as a day with no alcohol.
  case alcoholFree

  /// 1–2 standard drinks.
  case low

  /// 3–5 standard drinks.
  case medium

  /// 6–9 standard drinks.
  case high

  /// 10 or more standard drinks.
  ///
  /// Added in 1.3 (ADR-0034). The three-step ramp put every heavy day in one
  /// bucket: a six-drink evening and a fourteen-drink one drew the same cell,
  /// so the top of the range said "6+" and then stopped describing anything.
  /// Splitting it is a resolution change, not a verdict — the ramp still runs
  /// light-to-dark on one hue, and "10+" is as flat a phrase as "1–2".
  case veryHigh

  /// The label shown in the calendar legend.
  public var legendLabel: String {
    switch self {
    case .unlogged: "Not logged"
    case .alcoholFree: "No alcohol"
    case .low: "1–2"
    case .medium: "3–5"
    case .high: "6–9"
    case .veryHigh: "10+"
    }
  }

  /// Spoken by VoiceOver, where colour carries nothing at all.
  ///
  /// Deliberately flat: these describe an amount, never a verdict. "No alcohol" is
  /// a fact about a day; "good day" would be an opinion about a person.
  public var accessibilityDescription: String {
    switch self {
    case .unlogged: "nothing logged"
    case .alcoholFree: "no alcohol"
    case .low: "1 to 2 standard drinks"
    case .medium: "3 to 5 standard drinks"
    case .high: "6 to 9 standard drinks"
    case .veryHigh: "10 or more standard drinks"
    }
  }

  /// Whether this bucket represents a day something was actually recorded for.
  public var isRecorded: Bool { self != .unlogged }

  /// Buckets a day's total.
  ///
  /// The total is expressed in the *current* region's units before it gets here, so
  /// the same physical drinking falls in different buckets under different region
  /// settings. That is the same display-lens behaviour as every other total in the
  /// app — see ADR-0002 — not a rounding artefact.
  ///
  /// Rounds to the nearest whole drink before bucketing, so the boundaries line up
  /// exactly with the labels: a 2.5-drink day reads as 3, and lands in "3–5" rather
  /// than being quietly labelled "1–2".
  public static func bucket(
    standardDrinks: Double,
    isMarkedAlcoholFree: Bool,
    hasEntries: Bool
  ) -> DayIntensity {
    if hasEntries {
      // Anything logged is at least "low", even if it rounds to zero — a 0.3-drink
      // day is a day something was drunk, and showing it as alcohol-free would be
      // wrong in the one direction that matters.
      let rounded = standardDrinks.rounded()
      if rounded >= 10 { return .veryHigh }
      if rounded >= 6 { return .high }
      if rounded >= 3 { return .medium }
      return .low
    }
    return isMarkedAlcoholFree ? .alcoholFree : .unlogged
  }
}
