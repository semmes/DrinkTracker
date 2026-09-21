import Foundation

// The health pairing's arithmetic (ADR-0048): which nights had drinks and
// which were recorded as having none, which Health value belongs to which
// night, and the two averages the table shows side by side. Pure functions
// over the log and plain sample values, with `now` and the calendar injected,
// so every case here is a tier-1 test and nothing imports HealthKit
// (invariant 9). The read layer (Phase 2) turns HealthKit samples into
// `HealthSample` and `SleepSample` values that live for one render and are
// never written anywhere — not the store, not the App Group, not a cache
// (plan decision 5; App Review guideline 5.1.3 (ii)).
//
// Three rules from the plan are structural here rather than a matter of copy:
// the domain returns two figures and two counts and never a difference
// between them; a sample-size gate applies to both buckets before anything
// is returned; and nothing reads a health value to decide anything about
// drinking — the buckets come from the log alone.

/// A quantity read from Health, stripped to when it happened and what it
/// measured. An instant sample has `start == end`.
public struct HealthSample: Hashable, Sendable {
  public let start: Date
  public let end: Date
  public let value: Double

  public init(start: Date, end: Date, value: Double) {
    self.start = start
    self.end = end
    self.value = value
  }

  /// The instant a sample is filed by: halfway through it. Health files a
  /// sleep session by its middle (Phase 0), and one rule for every sample
  /// keeps an instant sample and a spanning one from being cased apart.
  var middle: Date {
    start.addingTimeInterval(end.timeIntervalSince(start) / 2)
  }
}

/// What a sleep sample says the person was doing. Health's own six values,
/// named here so nothing in this package needs HealthKit to say "asleep".
public enum SleepStage: Hashable, Sendable, CaseIterable {
  case inBed
  case awake
  case asleepUnspecified
  case core
  case deep
  case rem

  /// Health's `allAsleepValues`: every stage but in bed and awake. In bed is
  /// not sleep — a phone-only sleep schedule writes nothing else, and a night
  /// of it alone contributes no time asleep.
  public var isAsleep: Bool {
    switch self {
    case .inBed, .awake: false
    case .asleepUnspecified, .core, .deep, .rem: true
    }
  }
}

/// One sleep category sample: a stretch of time in one stage.
public struct SleepSample: Hashable, Sendable {
  public let start: Date
  public let end: Date
  public let stage: SleepStage

  public init(start: Date, end: Date, stage: SleepStage) {
    self.start = start
    self.end = end
    self.stage = stage
  }
}

/// Which of a night's windows a health value is filed by.
public enum NightAttribution: Hashable, Sendable {
  /// The sample's middle falls in the night's sleep day (18:00 to 18:00):
  /// for a value Health keeps per night, such as sleeping wrist temperature.
  case sleepDay
  /// The sample's middle falls on the calendar day after the evening: for a
  /// value Health keeps per calendar day, such as resting heart rate, whose
  /// day-after figure is the one the night's sleep is inside.
  case dayAfter
}

/// One night's health value, keyed by the night's evening.
public struct NightValue: Hashable, Sendable {
  public let night: Date
  public let value: Double

  public init(night: Date, value: Double) {
    self.night = night
    self.value = value
  }
}

/// The nights of a range sorted into the two columns. A night is in neither
/// when the log says nothing about it — see `HealthPairing.buckets`.
public struct NightBuckets: Hashable, Sendable {
  /// Nights with at least one logged drink in their drink window.
  public let drinks: [DrinkingNight]
  /// Nights whose evening's day is recorded as no alcohol, with no drink in
  /// the window.
  public let noDrinks: [DrinkingNight]

  public init(drinks: [DrinkingNight], noDrinks: [DrinkingNight]) {
    self.drinks = drinks
    self.noDrinks = noDrinks
  }

  /// Whether the log alone could clear the gate on both sides — what the
  /// one-time offer checks before any Health value exists. The table's own
  /// gate counts nights that have a value, which is never more than this.
  public func clearsGate(minimumNights: Int = PairedFigures.minimumNights) -> Bool {
    drinks.count >= minimumNights && noDrinks.count >= minimumNights
  }
}

/// The two averages the table shows, each with the nights behind it, and the
/// span of nights they cover. Two figures and two counts, on purpose: nothing
/// here computes the difference, the ratio, or which is larger, and a test
/// pins the stored properties to exactly these so nothing can be added
/// quietly (ADR-0048, plan rule 1).
public struct PairedFigures: Hashable, Sendable {
  public struct Figure: Hashable, Sendable {
    /// The mean of the nights' values, in the sample's own unit.
    public let average: Double
    /// How many nights had a value. What lets a reader weigh the average.
    public let nights: Int

    public init(average: Double, nights: Int) {
      self.average = average
      self.nights = nights
    }
  }

  public let drinks: Figure
  public let noDrinks: Figure
  /// The evening of the earliest night that contributed to either figure.
  public let firstNight: Date
  /// The evening of the latest night that contributed to either figure.
  public let lastNight: Date

  /// Nights with a value each bucket needs before figures are returned at
  /// all. Two weeks of nights: with n nights the mean is settled to about
  /// SD/√n of the night-to-night spread, which at 14 is a little over a
  /// quarter of it; going to 28 would buy less than the step from 7 to 14
  /// bought. Below it the whole row is hidden, never shown with a caveat.
  /// A noisier type (heart rate variability) passes a larger floor.
  public static let minimumNights = 14

  public init(drinks: Figure, noDrinks: Figure, firstNight: Date, lastNight: Date) {
    self.drinks = drinks
    self.noDrinks = noDrinks
    self.firstNight = firstNight
    self.lastNight = lastNight
  }
}

public enum HealthPairing {

  /// Every night whose evening falls on a calendar day from `first` through
  /// `last`, oldest first, keeping only those whose day after has ended by
  /// `now`. A figure Health keeps per calendar day is still being revised
  /// while that day runs (the watch rewrites the current and previous day's
  /// resting heart rate), so the night is counted once the day it wakes into
  /// is over: the evening two days ago is the newest night on any render.
  public static func nights(
    from first: Date,
    through last: Date,
    completeBy now: Date,
    calendar: Calendar
  ) -> [DrinkingNight] {
    TrendSummary.dayKeys(from: first, through: last, calendar: calendar)
      .compactMap { DrinkingNight(evening: $0, calendar: calendar) }
      .filter { $0.dayAfter.end <= now }
  }

  /// Sorts `nights` into the two columns from the log alone.
  ///
  /// A night with a logged drink in its window is a drinks night — any entry,
  /// as the calendar's own "days with drinks" counts them. A night is a
  /// no-drinks night only when the day it is named for is one of
  /// `alcoholFreeDays`, the days recorded as no alcohol, and nothing was
  /// logged in its window. A night with nothing recorded is in neither
  /// column: the app has never read silence as abstinence (ADR-0006,
  /// ADR-0033), and a column headed "no drinks" built from nights it knows
  /// nothing about would be the first surface to. It also means the only way
  /// to move a night into the second column is a record, never an omission.
  ///
  /// One consequence, accepted: a marker names a calendar day, and the
  /// window's last six hours fall on the next one, so a drink at 1 a.m. makes
  /// the night before it a drinks night (right) and leaves the night of its
  /// own day unrecorded, because the app will not mark a day that holds a
  /// drink (also right — that day did).
  public static func buckets(
    _ nights: [DrinkingNight],
    drinks: [LoggedDrink],
    alcoholFreeDays: [Date],
    calendar: Calendar
  ) -> NightBuckets {
    var eveningsWithDrinks: Set<Date> = []
    for drink in drinks {
      if let night = DrinkingNight.containing(drink.loggedAt, calendar: calendar) {
        eveningsWithDrinks.insert(night.evening)
      }
    }
    let markedDays = Set(alcoholFreeDays.map { calendar.startOfDay(for: $0) })
    var withDrinks: [DrinkingNight] = []
    var recordedNone: [DrinkingNight] = []
    for night in nights {
      if eveningsWithDrinks.contains(night.evening) {
        withDrinks.append(night)
      } else if markedDays.contains(night.evening) {
        recordedNone.append(night)
      }
    }
    return NightBuckets(drinks: withDrinks, noDrinks: recordedNone)
  }

  /// One value per night from a quantity type: the mean of the samples filed
  /// under it by `attribution`. A night no sample falls on has no value and
  /// is absent, never zero. Samples on nights outside `nights` are dropped.
  public static func nightlyValues(
    of samples: [HealthSample],
    for nights: [DrinkingNight],
    attribution: NightAttribution,
    calendar: Calendar
  ) -> [NightValue] {
    let byEvening = Dictionary(nights.map { ($0.evening, $0) }, uniquingKeysWith: { first, _ in first })
    var sums: [Date: (total: Double, count: Int)] = [:]
    for sample in samples {
      guard sample.end >= sample.start, sample.value.isFinite else { continue }
      let middle = sample.middle
      guard let night = night(filing: middle, by: attribution, among: byEvening, calendar: calendar)
      else { continue }
      let running = sums[night.evening] ?? (0, 0)
      sums[night.evening] = (running.total + sample.value, running.count + 1)
    }
    return sums
      .map { NightValue(night: $0.key, value: $0.value.total / Double($0.value.count)) }
      .sorted { $0.night < $1.night }
  }

  /// Seconds asleep per night, assembled the way the Health app's Time
  /// Asleep was seen to be: the asleep stages (never in bed, never awake)
  /// merged into stretches where they overlap or touch — so two sources
  /// recording the same hour count it once — then each stretch filed whole
  /// under the night whose sleep day holds its middle, and a night's stretches
  /// summed, an afternoon nap alongside the night before it. A night with no
  /// asleep stretch is absent, never zero.
  public static func timeAsleep(
    from samples: [SleepSample],
    for nights: [DrinkingNight],
    calendar: Calendar
  ) -> [NightValue] {
    let byEvening = Dictionary(nights.map { ($0.evening, $0) }, uniquingKeysWith: { first, _ in first })
    var seconds: [Date: TimeInterval] = [:]
    for stretch in asleepStretches(in: samples) {
      let middle = stretch.start.addingTimeInterval(stretch.duration / 2)
      guard let night = night(filing: middle, by: .sleepDay, among: byEvening, calendar: calendar)
      else { continue }
      seconds[night.evening, default: 0] += stretch.duration
    }
    return seconds
      .map { NightValue(night: $0.key, value: $0.value) }
      .sorted { $0.night < $1.night }
  }

  /// The two figures, or nil while either bucket has fewer than
  /// `minimumNights` nights with a value — the gate, resolved here so no
  /// surface can show one side without the other or a number with an
  /// asterisk. Each figure is the mean over its bucket's nights that have a
  /// value; a night with none is not a zero and not counted. Two values for
  /// one night (a caller's slip) collapse to their mean.
  public static func figures(
    _ buckets: NightBuckets,
    values: [NightValue],
    minimumNights: Int = PairedFigures.minimumNights
  ) -> PairedFigures? {
    let floor = max(1, minimumNights)
    var byNight: [Date: [Double]] = [:]
    for value in values where value.value.isFinite {
      byNight[value.night, default: []].append(value.value)
    }
    func figure(for nights: [DrinkingNight]) -> (figure: PairedFigures.Figure, evenings: [Date])? {
      var means: [Double] = []
      var evenings: [Date] = []
      for night in nights {
        guard let samples = byNight[night.evening], !samples.isEmpty else { continue }
        means.append(samples.reduce(0, +) / Double(samples.count))
        evenings.append(night.evening)
      }
      guard means.count >= floor else { return nil }
      let average = means.reduce(0, +) / Double(means.count)
      return (PairedFigures.Figure(average: average, nights: means.count), evenings)
    }
    guard
      let drinks = figure(for: buckets.drinks),
      let noDrinks = figure(for: buckets.noDrinks)
    else { return nil }
    let evenings = drinks.evenings + noDrinks.evenings
    guard let first = evenings.min(), let last = evenings.max() else { return nil }
    return PairedFigures(
      drinks: drinks.figure, noDrinks: noDrinks.figure, firstNight: first, lastNight: last
    )
  }

  // MARK: - Filing

  /// The night among `nights` that `instant` is filed under by `attribution`,
  /// found by key and then checked against the night's own window, so a
  /// calendar that placed a boundary oddly cannot file an instant on a night
  /// that does not hold it.
  private static func night(
    filing instant: Date,
    by attribution: NightAttribution,
    among nights: [Date: DrinkingNight],
    calendar: Calendar
  ) -> DrinkingNight? {
    let day = calendar.startOfDay(for: instant)
    let evening: Date?
    switch attribution {
    case .sleepDay:
      // Before 18:00 the instant is in the sleep day named for `day`, which is
      // the night of the day before; from 18:00 it is in the night of `day`.
      guard
        let boundary = DrinkingNight.boundary(
          hour: DrinkingNight.sleepDayBoundaryHour, on: day, calendar: calendar)
      else { return nil }
      evening = instant >= boundary ? day : calendar.date(byAdding: .day, value: -1, to: day)
    case .dayAfter:
      evening = calendar.date(byAdding: .day, value: -1, to: day)
    }
    guard let evening, let night = nights[calendar.startOfDay(for: evening)] else { return nil }
    switch attribution {
    case .sleepDay: return night.sleepDay.holds(instant) ? night : nil
    case .dayAfter: return night.dayAfter.holds(instant) ? night : nil
    }
  }

  /// The asleep samples merged into maximal stretches: sorted by start, and
  /// each folded into the previous when it begins before or exactly where
  /// that one ends. Order of input does not matter; zero-length and inverted
  /// samples are dropped.
  static func asleepStretches(in samples: [SleepSample]) -> [DateInterval] {
    let asleep = samples
      .filter { $0.stage.isAsleep && $0.end > $0.start }
      .sorted { $0.start < $1.start }
    var stretches: [DateInterval] = []
    for sample in asleep {
      if var last = stretches.last, sample.start <= last.end {
        last.end = max(last.end, sample.end)
        stretches[stretches.count - 1] = last
      } else {
        stretches.append(DateInterval(start: sample.start, end: sample.end))
      }
    }
    return stretches
  }
}
