import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Apple Health figures beside the log, at the bottom of Trends (ADR-0048,
/// ADR-0049, ADR-0050): one card, one row per metric the reader has switched
/// on, each row two averages of their own Health data side by side — nights
/// they logged drinks, nights they recorded as no alcohol — with the nights
/// behind each, and nothing that relates one to the other. Resting heart
/// rate shipped first (Phase 3); sleep is the second row (Phase 4); heart
/// rate variability the third (Phase 5, ADR-0052: a floor twice the others'
/// and Quarter and Year only); wrist temperature the fourth and last (Phase
/// 6, ADR-0053: the reading itself, never a change from a baseline, in the
/// unit the reader's Health app shows) — all under the same heading, from
/// the same parts.
///
/// ## What holds the line
///
/// Every previous figure in the app reports a quantity of alcohol. This is the
/// first that puts a second axis beside it, and that axis carries a direction
/// the reader already believes in — "62 bpm on nights with drinks, 58 without"
/// is a verdict no sentence has to deliver. So the discipline is structural
/// (the plan's four rules, ADR-0050): the domain returns two figures and never
/// a difference; a sample-size gate hides the whole row below the range's
/// floor of nights with a value in *either* column — fourteen at Quarter and
/// Year, seven at Month, two at Week (ADR-0048's 2026-09-22 amendment), and
/// twenty-eight for heart rate variability where it is shown (ADR-0052); no
/// colour, no arrow, no chart; and the buckets come from the log alone —
/// nothing here reads a heart rate or a night's sleep to decide anything
/// about drinking.
///
/// ## The heading cannot outlive its content
///
/// `ComparisonsSection`'s rule, kept: the section resolves every row's
/// condition and the offer's once, and the heading's condition is the literal
/// disjunction of them. The card does not read a switch; the offer does not
/// read a switch; only `resolve` does.
///
/// ## Read, compute, render, discard
///
/// `HealthPairingModel.load` reads each switched-on metric's samples, folds
/// them into two figures and drops them in the same call; the model keeps the
/// figures for the render and nothing else, and clears them the moment the
/// switches are off. Nothing is written anywhere but the one timing breadcrumb
/// per metric the read layer leaves (ADR-0049). The load is driven by
/// `TrendsView`, because a `.task` has to hang off a view that exists, and
/// this section renders nothing at all when it has nothing to show — a
/// zero-height stand-in would still take the screen's section spacing, and
/// the design's first acceptance check is that Trends is pixel-identical with
/// everything off.
struct HealthPairingSection: View {
  /// The request this render would read, or nil when nothing could be shown
  /// — every switch off and the offer answered — in which case `TrendsView`
  /// does not derive one and the section draws nothing.
  let request: HealthPairingRequest?
  /// The figures the model last computed, with the request they answer, or
  /// nil: not loaded yet, no data, below the gate, or every switch off (the
  /// model clears them). The section decides which rows to draw; the card
  /// never re-checks a switch.
  let loaded: HealthPairingModel.Loaded?
  let onAcceptOffer: () -> Void
  let onDeclineOffer: () -> Void

  @Environment(AppSettings.self) private var settings

  var body: some View {
    let shown = resolve()

    if !shown.rows.isEmpty || shown.offer, let request {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        SectionLabel("From Apple Health")

        // The card is drawn from what was read, under the range that read
        // covered: on a range change the previous card stands until the new
        // read lands, then both the figures and their source line change
        // together, so a figure is never shown under another range's name.
        if let card = shown.card {
          HealthPairingCard(
            rows: shown.rows, range: card.request.range, temperatureUnit: card.temperatureUnit)
        }

        if shown.offer {
          HealthPairingOffer(
            buckets: request.buckets,
            range: request.range,
            onAccept: onAcceptOffer,
            onDecline: onDeclineOffer
          )
        }
      }
      // `TrendsView`'s stack is centre-aligned — the modifier every section
      // carries so its heading does not render down the middle.
      .frame(maxWidth: .infinity, alignment: .leading)
      // The design's loading state: nothing until the query returns, then the
      // card arrives with the structure-change animation. No skeleton and no
      // spinner, because a placeholder that later vanishes would reveal the
      // no-data state, and a denied read is invisible.
      .transition(.opacity)
    }
  }

  private struct Shown {
    var card: HealthPairingModel.Loaded?
    var rows: [HealthPairingCard.Row] = []
    var offer = false
  }

  /// The conditions, resolved once. A row: its switch on, and the last read
  /// produced figures for it that cleared the gate — a metric switched on
  /// since that read has none yet, and the task is already re-reading for
  /// it, so it is not drawn from a read that did not ask for it. The offer:
  /// never answered, no pairing switch on, and the log alone clearing the
  /// gate on **both** sides at this range's own floor (two nights a bucket
  /// at Week, seven at Month, fourteen at Quarter and Year — ADR-0048's
  /// 2026-09-22 amendment) — the drink side the design named, and the
  /// no-drinks side too, because that column holds nights recorded as no
  /// alcohol (ADR-0048) and is not plentiful by nature; an offer gated on one
  /// side could be accepted, granted, and show nothing.
  private func resolve() -> Shown {
    var shown = Shown()
    if settings.isAnyHealthPairingOn {
      guard let loaded else { return shown }
      // The range the reader is on, not the one the figures were read for:
      // while a range change is being re-read the previous card stands
      // (ADR-0050), and a row that does not exist at the new range (heart
      // rate variability at Month, ADR-0052) must leave with the change
      // rather than with the read — a review catch.
      let range = request?.range ?? loaded.request.range
      let rows = PairedMetric.allCases.compactMap { metric -> HealthPairingCard.Row? in
        guard settings.showsPairing(metric), metric.isShown(at: range),
          let figures = loaded.figures[metric]
        else { return nil }
        return HealthPairingCard.Row(metric: metric, figures: figures)
      }
      if !rows.isEmpty {
        shown.card = loaded
        shown.rows = rows
      }
    } else if !settings.hasAnsweredHealthPairingOffer, let request,
      request.buckets.clearsGate(minimumNights: PairedFigures.minimumNights(at: request.range))
    {
      shown.offer = true
    }
    return shown
  }
}

/// The metrics the pairing shows, in the Settings order — the order the
/// card's rows and the offer's take (design README). Each is one switch in
/// Settings, one read in `HealthKitService`, one row here.
enum PairedMetric: CaseIterable, Hashable, Sendable {
  case restingHeartRate
  case sleep
  case heartRateVariability
  case wristTemperature
}

/// The unit the wrist temperature row prints and speaks: the one the reader's
/// Health app shows the reading in (`HealthKitService.preferredTemperatureUnit`,
/// ADR-0053), which follows the locale unless they changed it there — so the
/// figure on the card is the figure a reader can find in Health, in the same
/// unit. The domain's values stay in Celsius; the conversion happens where
/// the figure is drawn.
enum TemperatureUnit: Hashable, Sendable {
  case celsius
  case fahrenheit

  var foundationUnit: UnitTemperature {
    switch self {
    case .celsius: .celsius
    case .fahrenheit: .fahrenheit
    }
  }
}

extension PairedMetric {
  /// Nights with a value each bucket needs before this metric's row is
  /// shown at `range`: the domain's floor for the range (two at Week, seven
  /// at Month, fourteen at Quarter and Year — ADR-0048's 2026-09-22
  /// amendment), or the larger one it names for heart rate variability
  /// (ADR-0052), which is shown only at the ranges that hold it. Read by the
  /// load, which skips a read the log cannot clear, and by the ask, so a
  /// sheet lands the first time this metric's row is possible and not before.
  func minimumNights(at range: TrendRange) -> Int {
    switch self {
    case .restingHeartRate, .sleep, .wristTemperature: PairedFigures.minimumNights(at: range)
    case .heartRateVariability: PairedFigures.minimumNightsForHeartRateVariability
    }
  }

  /// Whether this metric can have a row at `range`. Heart rate variability
  /// lives at Quarter and Year only (ADR-0052): its floor is more nights
  /// than a month holds, and the wider ranges are where the averaging does
  /// the work the plan asks of it — the per-range floors of ADR-0048's
  /// 2026-09-22 amendment scale the base floor, not this one. Elsewhere it
  /// is neither read nor asked for, and its switch's caption says where it
  /// is shown.
  func isShown(at range: TrendRange) -> Bool {
    switch self {
    case .restingHeartRate, .sleep, .wristTemperature: true
    case .heartRateVariability: range == .quarter || range == .year
    }
  }
}

extension AppSettings {
  /// The switch for `metric`. One place maps a metric to its flag, so a row,
  /// the offer's "no switch is on" and the read's set of metrics cannot
  /// disagree about which switch is which.
  func showsPairing(_ metric: PairedMetric) -> Bool {
    switch metric {
    case .restingHeartRate: showsRestingHeartRatePairing
    case .sleep: showsSleepPairing
    case .heartRateVariability: showsHeartRateVariabilityPairing
    case .wristTemperature: showsWristTemperaturePairing
    }
  }

  /// The same map, written: what accepting the offer turns on, so a metric
  /// added to `PairedMetric` cannot be left off the offer's "every shipped
  /// switch" by forgetting a line.
  func setShowsPairing(_ metric: PairedMetric, _ isOn: Bool) {
    switch metric {
    case .restingHeartRate: showsRestingHeartRatePairing = isOn
    case .sleep: showsSleepPairing = isOn
    case .heartRateVariability: showsHeartRateVariabilityPairing = isOn
    case .wristTemperature: showsWristTemperaturePairing = isOn
    }
  }

  /// The metrics whose switches are on — what a read asks for.
  var pairingMetricsOn: Set<PairedMetric> {
    Set(PairedMetric.allCases.filter(showsPairing))
  }
}

/// Everything one read needs, derived from the log once per change of its
/// inputs (`HealthPairingModel.request`) and hashable, so a `.task(id:)`
/// re-reads exactly when the range, the day or the buckets change and not
/// otherwise.
struct HealthPairingRequest: Hashable {
  let range: TrendRange
  /// The start of the day the render is made on. A night counts once the
  /// day after it has ended, and a read never includes the current day, so
  /// the instant within the day changes nothing — keying on the day keeps a
  /// foregrounding from re-reading for no reason.
  let today: Date
  let nights: [DrinkingNight]
  let buckets: NightBuckets
  /// The days the read covers: the range's own, clipped by the read layer to
  /// yesterday.
  let window: DateInterval
  let calendar: Calendar

  init(
    range: TrendRange,
    endingOn today: Date,
    drinks: [LoggedDrink],
    alcoholFreeDays: Set<Date>,
    calendar: Calendar
  ) {
    let day = calendar.startOfDay(for: today)
    let first = range.startDate(endingOn: day, calendar: calendar)
    self.range = range
    self.today = day
    // `completeBy: day` and `completeBy: now` admit the same nights: a night
    // ends at a midnight, and a midnight is on or before the day's start
    // exactly when it is on or before any instant of the day.
    self.nights = HealthPairing.nights(from: first, through: day, completeBy: day, calendar: calendar)
    // Only the range's own drinks are sorted into nights. Every night listed
    // has its evening on or before the day before yesterday, so its window
    // lies inside [first, day); a drink outside that span maps to a night the
    // bucketing discards anyway, and placing one costs a dozen calendar
    // calls — over a whole log of years, that is the difference between a
    // range change and a stall.
    let inRange = drinks.filter { first <= $0.loggedAt && $0.loggedAt < day }
    self.buckets = HealthPairing.buckets(
      nights, drinks: inRange, alcoholFreeDays: Array(alcoholFreeDays), calendar: calendar)
    self.window = DateInterval(start: first, end: max(first, day))
    self.calendar = calendar
  }
}

/// One read: the request, and which metrics it asks for — the `.task(id:)`
/// key, so a switch turned on re-reads and nothing else does.
struct HealthPairingRead: Hashable {
  let request: HealthPairingRequest
  let metrics: Set<PairedMetric>
}

/// The figures for the render, and the reads that produce them.
///
/// One instance, owned by `TrendsView` as `@State`, loaded from its `.task`.
/// `load` is the whole of the pairing's contact with Health in the app: read
/// each metric's samples, file them by night, fold the two figures, and let
/// the samples go — they are locals of one call. What survives is `loaded`,
/// two means and two counts per metric with the request they answer, which
/// is what the card draws; and `clear` drops even that the moment nothing
/// should be drawn.
@Observable
@MainActor
final class HealthPairingModel {
  /// What a read produced, with the request it was made for — so the card
  /// draws figures only under the range they cover. A metric absent from
  /// `figures` was not read, or was read and fell below the gate; the card
  /// draws neither, and the section does not need to tell them apart.
  struct Loaded: Equatable {
    let request: HealthPairingRequest
    let figures: [PairedMetric: PairedFigures]
    /// The unit the wrist temperature row is drawn in, read from Health
    /// beside its samples (ADR-0053); Celsius where no row was read.
    let temperatureUnit: TemperatureUnit
  }

  private(set) var loaded: Loaded?

  /// The request for the current render, derived once per change of its
  /// inputs rather than once per body pass. Deriving it walks the range's
  /// days into nights and the range's drinks into buckets — thousands of
  /// calendar calls at Year — and `TrendsView`'s body runs on every frame of
  /// a chart scrub; the inputs compare in microseconds. Ignored by
  /// observation, so refreshing it during a body pass changes nothing the
  /// view watches.
  @ObservationIgnored private var derived: (inputs: Inputs, request: HealthPairingRequest)?

  private struct Inputs: Equatable {
    let range: TrendRange
    let today: Date
    let drinks: [LoggedDrink]
    let alcoholFreeDays: Set<Date>
    let calendar: Calendar
  }

  func request(
    range: TrendRange,
    endingOn today: Date,
    drinks: [LoggedDrink],
    alcoholFreeDays: Set<Date>,
    calendar: Calendar
  ) -> HealthPairingRequest {
    let inputs = Inputs(
      range: range, today: calendar.startOfDay(for: today), drinks: drinks,
      alcoholFreeDays: alcoholFreeDays, calendar: calendar)
    if let derived, derived.inputs == inputs { return derived.request }
    let request = HealthPairingRequest(
      range: range, endingOn: inputs.today, drinks: drinks,
      alcoholFreeDays: alcoholFreeDays, calendar: calendar)
    derived = (inputs, request)
    return request
  }

  /// Reads each of `read.metrics` for its request and replaces `loaded` —
  /// under the design's structure-change animation, so a card that appears
  /// fades in and figures that change crossfade. Skipped, and cleared, when
  /// the log alone cannot clear the gate: the table's gate counts nights with
  /// a value, never more than the log's nights, so no read could produce a
  /// row (ADR-0049's reads happen only where a row is possible). The metrics
  /// are read one after the other in the Settings order; each is its own
  /// query and its own breadcrumb.
  func load(_ read: HealthPairingRead, health: HealthKitService) async {
    let request = read.request
    guard !read.metrics.isEmpty,
      request.buckets.clearsGate(minimumNights: PairedFigures.minimumNights(at: request.range))
    else {
      clear()
      return
    }
    var figures: [PairedMetric: PairedFigures] = [:]
    var temperatureUnit = TemperatureUnit.celsius
    for metric in PairedMetric.allCases where read.metrics.contains(metric) {
      // A metric whose own floor the log cannot clear is not read: the
      // figures would be nil whatever came back, and a query that cannot
      // show anything is a cost and a breadcrumb for nothing (ADR-0052).
      guard request.buckets.clearsGate(minimumNights: metric.minimumNights(at: request.range))
      else { continue }
      let values: [NightValue]
      switch metric {
      case .restingHeartRate:
        let samples = await health.restingHeartRate(
          in: request.window, endingBefore: request.today, calendar: request.calendar)
        values = HealthPairing.nightlyValues(
          of: samples, for: request.nights, attribution: .dayAfter, calendar: request.calendar)
      case .sleep:
        let samples = await health.sleep(
          in: request.window, endingBefore: request.today, calendar: request.calendar)
        values = HealthPairing.timeAsleep(from: samples, for: request.nights, calendar: request.calendar)
      case .heartRateVariability:
        let samples = await health.heartRateVariability(
          in: request.window, endingBefore: request.today, calendar: request.calendar)
        values = HealthPairing.nightlyValues(
          of: samples, for: request.nights, attribution: .dayAfter, calendar: request.calendar)
      case .wristTemperature:
        // The watch's one reading a night, filed under the night whose
        // sleep day holds its middle, and averaged as it is — the absolute
        // reading, never a deviation from a baseline (ADR-0053). The unit is
        // the reader's own Health preference, read beside the samples.
        let samples = await health.wristTemperature(
          in: request.window, endingBefore: request.today, calendar: request.calendar)
        values = HealthPairing.nightlyValues(
          of: samples, for: request.nights, attribution: .sleepDay, calendar: request.calendar)
        // Asked only beside samples: a read that returned nothing draws
        // nothing, so the question would be one more round trip for no row —
        // and HealthKit answers it with the reader's own choice only for a
        // type it has authorized, the locale's default otherwise.
        if !samples.isEmpty {
          temperatureUnit = await health.preferredTemperatureUnit()
        }
      }
      guard !Task.isCancelled else { return }
      if let result = HealthPairing.figures(
        request.buckets, values: values, minimumNights: metric.minimumNights(at: request.range))
      {
        figures[metric] = result
      }
    }
    let result = Loaded(request: request, figures: figures, temperatureUnit: temperatureUnit)
    guard result != loaded else { return }
    withAnimation(.smooth(duration: 0.25)) {
      loaded = result
    }
  }

  func clear() {
    guard loaded != nil else { return }
    withAnimation(.smooth(duration: 0.25)) {
      loaded = nil
    }
  }
}

// MARK: - The card

/// One card, one grid, three columns — the weekday table's parts
/// (`ComparisonTable`), not a second copy of them. The header row is the card's
/// title beside two column heads on one baseline; then one metric row per
/// switched-on metric with figures, the name over its two night counts and
/// the two figures with their unit, a hairline between rows; then the source
/// line.
///
/// The numerals are rounded and tabular because they are the reader's own
/// (design-system §3). Units and labels stay default SF. No colour anywhere
/// on the card: the only brand colour on this feature's surfaces is the
/// switches' tint and the offer's two buttons, and a colour on a figure here
/// would be a delta drawn (the Phase 3 block's own rule).
struct HealthPairingCard: View {
  struct Row: Hashable {
    let metric: PairedMetric
    let figures: PairedFigures
  }

  let rows: [Row]
  let range: TrendRange
  /// The unit the wrist temperature row is drawn and spoken in (ADR-0053).
  let temperatureUnit: TemperatureUnit

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The weekday table's fold, read from the one shared place.
  private var isStacked: Bool { ComparisonTable.folds(dynamicTypeSize) }

  /// The two numeric columns' width — a floor, so a wider figure or head
  /// still fits, never a clip. The owner's review of the shipped card
  /// (2026-09-22) read its heads as jammed and its figures as scattered
  /// beside the weekend card above, whose columns are content-sized but
  /// happen to be wide: "US adults" sits in a column "31 of every 100"
  /// made 96.7pt, so its heads are 36.9pt apart, where "DRINKS" and "NO
  /// DRINKS" over content-sized columns were 8pt apart and each row's
  /// figures ended wherever their unit let them. 74 is the narrowest scaled
  /// width that holds every cell ("36.62 °C" 64.0, "NO DRINKS" 67.0,
  /// "100.12 °F" 72.8) and puts the two heads 36.8pt apart — the reference
  /// card's own spacing to a tenth. Its cost is the label column, measured
  /// in ADR-0050's amendment: 157pt on the owner's 393pt phone, 139 on a
  /// 375pt one against "Heart rate variability" at 138.3. Scaled with the
  /// head's text style, as the weekday table's is.
  @ScaledMetric(relativeTo: .caption2) private var figureColumn: CGFloat = 74

  /// The design's temperature note, under the last row and only while the
  /// wrist temperature row is on the card — it is the last row by the
  /// Settings order, so the note sits directly beneath it. It says what the
  /// figure is, because the same nights read differently in the Health app
  /// (ADR-0053).
  private var showsTemperatureNote: Bool {
    rows.contains { $0.metric == .wristTemperature }
  }

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        if isStacked {
          stackedFigures
        } else {
          figureTable
        }

        if showsTemperatureNote {
          Text(HealthPairingCopy.temperatureNote)
            .font(.caption)
            .foregroundStyle(.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, isStacked ? GlassTokens.Spacing.tight : 0)
        }

        Divider()
          .opacity(0.7)
          .padding(.top, GlassTokens.Spacing.tight)

        // Its own hint: the shared line's default says "comparison", the one
        // word this card is not (ADR-0050).
        SourceDisclosure(sources: HealthPairingCopy.sourceLine(for: range), hint: "Explains these figures") {
          Text(HealthPairingCopy.sourceNote)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var figureTable: some View {
    Grid(alignment: .trailing, horizontalSpacing: GlassTokens.Spacing.tight, verticalSpacing: 0) {
      // One line, three parts on one baseline: the title in the label column,
      // the two heads over the numeric columns. The title keeps its header
      // trait; the heads are hidden because each row's own sentence speaks
      // the long phrases the short heads stand for.
      GridRow(alignment: .firstTextBaseline) {
        CardTitle("Your averages")
          .frame(maxWidth: .infinity, alignment: .leading)
          .gridColumnAlignment(.leading)
        ComparisonTable.columnHead(Text("Drinks"), width: figureColumn)
          .accessibilityHidden(true)
        ComparisonTable.columnHead(Text("No drinks"), width: figureColumn)
          .accessibilityHidden(true)
      }
      .padding(.bottom, GlassTokens.Spacing.tight)

      ForEach(Array(rows.enumerated()), id: \.element.metric) { index, row in
        // The first rule is the card's own separator; the rest are the
        // weekday table's lighter step of it, so two rows read as one table.
        Divider().opacity(index == 0 ? 1 : 0.7)

        // One VoiceOver stop per row, its label on the name cell and the
        // figure cells hidden — the weekday table's lesson: a modifier on a
        // `GridRow` lands on every cell.
        GridRow(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(row.metric.name)
              .font(.subheadline)
              .foregroundStyle(.primary)
            nightsCaption(row.figures)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .gridColumnAlignment(.leading)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(rowLabel(row))

          figureCell(row.metric, row.figures.drinks.average)
            .accessibilityHidden(true)
          figureCell(row.metric, row.figures.noDrinks.average)
            .accessibilityHidden(true)
        }
        .padding(.vertical, GlassTokens.Spacing.tight)
      }
    }
  }

  /// "18 and 31 nights" — the counts that let a reader weigh the two averages,
  /// which is the honest alternative to the app weighing them. The numerals a
  /// step darker, as the ratio cell's are; one key with both, so a translation
  /// can reorder them.
  private func nightsCaption(_ figures: PairedFigures) -> some View {
    Text(
      "\(Text(verbatim: String(figures.drinks.nights)).font(GlassTokens.Typography.rowCount).foregroundColor(.primary)) and \(Text(verbatim: String(figures.noDrinks.nights)).font(GlassTokens.Typography.rowCount).foregroundColor(.primary)) nights"
    )
    .font(.caption)
    .monospacedDigit()
    .foregroundStyle(.secondaryInk)
  }

  /// The figure in the reader's numeral face, its unit beside it in default
  /// SF where the metric has one — "62 bpm"; time asleep carries its own,
  /// "6h 12m". A subject change crossfades (the range switched); a value
  /// never rolls here, because a roll between two ranges would draw a
  /// direction.
  private func figureCell(_ metric: PairedMetric, _ average: Double) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      metric.figure(average, temperatureUnit: temperatureUnit)
        .font(GlassTokens.Typography.rowFigure)
        .monospacedDigit()
        .foregroundStyle(.primary)
        .contentTransition(.opacity)
      if let unit = metric.unitLabel(temperatureUnit: temperatureUnit) {
        unit
          .font(.caption)
          .foregroundStyle(.secondaryInk)
      }
    }
    .animation(.smooth(duration: 0.22), value: average)
    .frame(minWidth: figureColumn, alignment: .trailing)
  }

  /// From `.xLarge` up, the fold the weekday table takes: the title, then per
  /// row its name and one line per column with its label written out — the
  /// same sentences VoiceOver speaks, so nothing a reader meets at a large
  /// size is newly worded.
  private var stackedFigures: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      CardTitle("Your averages")
      ForEach(Array(rows.enumerated()), id: \.element.metric) { index, row in
        if index > 0 {
          Divider().opacity(0.7)
        }
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text(row.metric.name)
            .font(.subheadline)
            .foregroundStyle(.primary)
          Text(HealthPairingCopy.drinksSentence(row.metric, row.figures.drinks, temperatureUnit: temperatureUnit))
          Text(HealthPairingCopy.noDrinksSentence(row.metric, row.figures.noDrinks, temperatureUnit: temperatureUnit))
        }
        .font(.body)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(row))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// "Resting heart rate. On nights you logged drinks, 62 beats per minute,
  /// over 18 nights. On nights recorded as no alcohol, 58 beats per minute,
  /// over 31 nights." The long phrases, not the heads; no comparative word.
  private func rowLabel(_ row: Row) -> Text {
    Text(HealthPairingCopy.rowSentence(row.metric, row.figures, temperatureUnit: temperatureUnit))
  }
}

// MARK: - The one-time offer

/// The table's own shape with its figure cells empty, one row per metric the
/// build ships, the drink log's counts as the only real numbers on it, one
/// sentence saying what it is, and one primary action (ADR-0051). It shows
/// before it asks: what the reader is agreeing to is on screen rather than
/// described. It appears once — the section decides when — and both answers
/// are final and silent.
struct HealthPairingOffer: View {
  let buckets: NightBuckets
  let range: TrendRange
  let onAccept: () -> Void
  let onDecline: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var isStacked: Bool { ComparisonTable.folds(dynamicTypeSize) }

  /// The card's own column floor, so the offer's empty cells sit where the
  /// figures will (`HealthPairingCard.figureColumn`; a property wrapper
  /// cannot be shared as a static, the weekday table's own note).
  @ScaledMetric(relativeTo: .caption2) private var figureColumn: CGFloat = 74

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        if isStacked {
          stackedOffer
        } else {
          offerTable
        }

        // Its own VoiceOver stop, after the rows it counts for; the
        // placeholders above say nothing, so this is where the numbers are.
        Text(HealthPairingCopy.offerCounts(buckets, range: range))
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, GlassTokens.Spacing.tight)
          .accessibilitySortPriority(1)

        Divider()
          .opacity(0.7)
          .padding(.vertical, GlassTokens.Spacing.regular)

        // The card's label, first for VoiceOver: what it is, then the rows it
        // shows, then the two actions.
        Text(HealthPairingCopy.offerBody)
          .font(.body)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilitySortPriority(2)

        VStack(spacing: GlassTokens.Spacing.tight) {
          SUButton(model: .primary(String(localized: "Show these on Trends"))) {
            onAccept()
          }
          SUButton(model: .subtle(String(localized: "Not now"))) {
            onDecline()
          }
          .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        }
        .padding(.top, GlassTokens.Spacing.regular)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// The priorities sit on the elements themselves, not on the grid: a
  /// layout container is not an accessibility element, and a priority on one
  /// may not reach its children. Title and names at 1, so with the counts
  /// (also 1) they follow the body (2) in layout order, ahead of the buttons.
  private var offerTable: some View {
    Grid(alignment: .trailing, horizontalSpacing: GlassTokens.Spacing.tight, verticalSpacing: 0) {
      GridRow(alignment: .firstTextBaseline) {
        CardTitle("Your averages")
          .frame(maxWidth: .infinity, alignment: .leading)
          .gridColumnAlignment(.leading)
          .accessibilitySortPriority(1)
        ComparisonTable.columnHead(Text("Drinks"), width: figureColumn)
          .accessibilityHidden(true)
        ComparisonTable.columnHead(Text("No drinks"), width: figureColumn)
          .accessibilityHidden(true)
      }
      .padding(.bottom, GlassTokens.Spacing.tight)

      ForEach(Array(PairedMetric.allCases.enumerated()), id: \.element) { index, metric in
        Divider().opacity(index == 0 ? 1 : 0.7)

        GridRow(alignment: .firstTextBaseline) {
          Text(metric.name)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gridColumnAlignment(.leading)
            .accessibilitySortPriority(1)
          placeholder
          placeholder
        }
        .padding(.vertical, GlassTokens.Spacing.tight)
      }
    }
  }

  /// The empty figure cell. Tertiary ink, the figure's own face and width, so
  /// the real table lands in the same place; nothing for VoiceOver, which the
  /// design asks for by name — an empty cell read aloud is a value withheld.
  private var placeholder: some View {
    Text(verbatim: "– –")
      .font(GlassTokens.Typography.rowFigure)
      .monospacedDigit()
      .foregroundStyle(.tertiaryInk)
      .frame(minWidth: figureColumn, alignment: .trailing)
      .accessibilityHidden(true)
  }

  private var stackedOffer: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      CardTitle("Your averages")
        .accessibilitySortPriority(1)
      ForEach(PairedMetric.allCases, id: \.self) { metric in
        Text(metric.name)
          .font(.subheadline)
          .foregroundStyle(.primary)
          .accessibilitySortPriority(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Copy

extension PairedMetric {
  /// The row's name and the switch's title: the metric's own name, as the
  /// Health app prints it, shared so a reader meets one word in both places.
  var name: LocalizedStringKey {
    switch self {
    case .restingHeartRate: "Resting heart rate"
    case .sleep: "Sleep"
    case .heartRateVariability: "Heart rate variability"
    case .wristTemperature: "Wrist temperature"
    }
  }

  /// The unit printed beside the figure, where the figure does not carry its
  /// own. Beats per minute and milliseconds do not; hours and minutes do.
  /// The temperature's is the symbol of the unit the reader's Health app
  /// shows — Foundation's own "°C" or "°F", not a catalog key.
  func unitLabel(temperatureUnit: TemperatureUnit) -> Text? {
    switch self {
    case .restingHeartRate: Text("bpm")
    case .sleep: nil
    case .heartRateVariability: Text("ms")
    case .wristTemperature: Text(verbatim: temperatureUnit.foundationUnit.symbol)
    }
  }

  /// The figure as the table prints it: a whole number of beats per minute
  /// or of milliseconds, hours and minutes asleep, or a temperature to the
  /// hundredth of a degree in the reader's Health unit.
  func figure(_ average: Double, temperatureUnit: TemperatureUnit) -> Text {
    switch self {
    case .restingHeartRate: Text(verbatim: HealthPairingCopy.beatsPerMinute(average))
    case .sleep: Text(HealthPairingCopy.hoursAndMinutes(average))
    case .heartRateVariability: Text(verbatim: HealthPairingCopy.milliseconds(average))
    case .wristTemperature:
      Text(verbatim: HealthPairingCopy.temperatureFigure(average, in: temperatureUnit))
    }
  }
}

/// The feature's sentences in one place (the population reference's pattern),
/// so the card, its fold and its VoiceOver label cannot drift, and so the two
/// copy rules on top of house voice are checkable in one file: no comparative
/// word anywhere, and the source and the span named the way the population
/// reference names its survey. Every function returns a key, so each sentence
/// reaches the catalog whole and a translation can reorder its parts.
enum HealthPairingCopy {

  /// The figure as the row prints it: a whole number of beats per minute,
  /// half rounding up as the app's other displayed counts do. Formatted, not
  /// cast: `Int(_:)` traps on a finite value past its range, and the domain
  /// filters only for finiteness (PR #56's lesson on the population card).
  static func beatsPerMinute(_ average: Double) -> String {
    average.formatted(.number.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
  }

  /// Heart rate variability as the row prints it: a whole number of
  /// milliseconds, the design's figure format, by the same rounding as beats
  /// per minute. Whole, because a tenth of a millisecond on an average of
  /// nights is precision the night-to-night spread does not support, and
  /// because the Health app prints it whole.
  static func milliseconds(_ average: Double) -> String {
    beatsPerMinute(average)
  }

  /// The wrist temperature reading in the unit the reader's Health app
  /// shows: an absolute temperature, so it converts with the offset —
  /// Foundation's own conversion, which is exact for a mean of readings
  /// because the conversion is affine (ADR-0053). The domain's values are
  /// Celsius; nothing is converted before it is drawn.
  static func temperature(_ celsius: Double, in unit: TemperatureUnit) -> Measurement<UnitTemperature> {
    Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit.foundationUnit)
  }

  /// The reading as the row prints it: to the hundredth of a degree — the
  /// Health app's own precision for this type — by the same rounding as the
  /// other figures, the unit's symbol drawn beside it by the cell.
  static func temperatureFigure(_ celsius: Double, in unit: TemperatureUnit) -> String {
    temperature(celsius, in: unit).value
      .formatted(.number.precision(.fractionLength(2)).rounded(rule: .toNearestOrAwayFromZero))
  }

  /// The reading as a sentence speaks it — "97.88 degrees Fahrenheit" — from
  /// the same conversion and rounding as the printed figure, in the
  /// system's own words for the unit.
  static func spokenTemperature(_ celsius: Double, in unit: TemperatureUnit) -> String {
    temperature(celsius, in: unit)
      .formatted(
        .measurement(
          width: .wide, usage: .asProvided,
          numberFormatStyle: .number.precision(.fractionLength(2)).rounded(rule: .toNearestOrAwayFromZero)))
  }

  /// What the wrist temperature figure is, under the last row while its row
  /// is on the card: the reading the watch records, which is not the number
  /// the Health app shows for the same night — Health shows a change from a
  /// baseline of its own, which is not in HealthKit (ADR-0053). Said once,
  /// so a reader who checks a night in Health knows why the two differ.
  static let temperatureNote: LocalizedStringKey =
    "Wrist temperature is the overnight reading your watch records. Apple Health shows it as a change from a baseline of its own."

  /// Time asleep as the table prints it, "6h 12m" with the minutes
  /// zero-padded so a column of them aligns (the design's figure format):
  /// whole hours and minutes to the nearest minute, from the domain's one
  /// rounding, so this and the spoken form never disagree by a minute. The
  /// minutes are padded by the number formatter rather than `String(format:)`,
  /// so both numerals reach the screen in the reader's own digits.
  static func hoursAndMinutes(_ seconds: Double) -> LocalizedStringKey {
    let (hours, minutes) = HealthPairing.hoursAndMinutes(seconds)
    return "\(hours)h \(minutes.formatted(.number.precision(.integerLength(2))))m"
  }

  /// Time asleep as a sentence speaks it — "6 hours, 12 minutes" — from the
  /// same whole minutes as the printed figure; the system's own words, in the
  /// reader's language.
  static func spokenHoursAndMinutes(_ seconds: Double) -> String {
    let (hours, minutes) = HealthPairing.hoursAndMinutes(seconds)
    return Duration.seconds(hours * 3600 + minutes * 60)
      .formatted(.units(allowed: [.hours, .minutes], width: .wide))
  }

  /// "On nights you logged drinks, 62 beats per minute, over 18 nights." The
  /// long phrase the short head stands for; spoken, and shown at the sizes
  /// where the table folds. The count is never below the gate, so the noun is
  /// the plural. Time asleep: "On nights you logged drinks, 6 hours, 12
  /// minutes asleep, over 18 nights."
  static func drinksSentence(
    _ metric: PairedMetric, _ figure: PairedFigures.Figure, temperatureUnit: TemperatureUnit
  ) -> LocalizedStringKey {
    switch metric {
    case .restingHeartRate:
      "On nights you logged drinks, \(beatsPerMinute(figure.average)) beats per minute, over \(figure.nights) nights."
    case .sleep:
      "On nights you logged drinks, \(spokenHoursAndMinutes(figure.average)) asleep, over \(figure.nights) nights."
    case .heartRateVariability:
      "On nights you logged drinks, \(milliseconds(figure.average)) milliseconds, over \(figure.nights) nights."
    case .wristTemperature:
      "On nights you logged drinks, \(spokenTemperature(figure.average, in: temperatureUnit)), over \(figure.nights) nights."
    }
  }

  /// "On nights recorded as no alcohol, 58 beats per minute, over 31 nights."
  /// Recorded, not "other": the column holds the nights the reader marked, and
  /// a night with nothing logged is in neither (ADR-0048).
  static func noDrinksSentence(
    _ metric: PairedMetric, _ figure: PairedFigures.Figure, temperatureUnit: TemperatureUnit
  ) -> LocalizedStringKey {
    switch metric {
    case .restingHeartRate:
      "On nights recorded as no alcohol, \(beatsPerMinute(figure.average)) beats per minute, over \(figure.nights) nights."
    case .sleep:
      "On nights recorded as no alcohol, \(spokenHoursAndMinutes(figure.average)) asleep, over \(figure.nights) nights."
    case .heartRateVariability:
      "On nights recorded as no alcohol, \(milliseconds(figure.average)) milliseconds, over \(figure.nights) nights."
    case .wristTemperature:
      "On nights recorded as no alcohol, \(spokenTemperature(figure.average, in: temperatureUnit)), over \(figure.nights) nights."
    }
  }

  /// The row as VoiceOver speaks it, in one key: the name, then the two
  /// sentences above. Whole, rather than the two joined, so a translation
  /// orders the spoken sentence as its own language does — and so the label
  /// needs no `+` between `Text`s, which iOS 26 deprecates.
  static func rowSentence(
    _ metric: PairedMetric, _ figures: PairedFigures, temperatureUnit: TemperatureUnit
  ) -> LocalizedStringKey {
    switch metric {
    case .restingHeartRate:
      "Resting heart rate. On nights you logged drinks, \(beatsPerMinute(figures.drinks.average)) beats per minute, over \(figures.drinks.nights) nights. On nights recorded as no alcohol, \(beatsPerMinute(figures.noDrinks.average)) beats per minute, over \(figures.noDrinks.nights) nights."
    case .sleep:
      "Sleep. On nights you logged drinks, \(spokenHoursAndMinutes(figures.drinks.average)) asleep, over \(figures.drinks.nights) nights. On nights recorded as no alcohol, \(spokenHoursAndMinutes(figures.noDrinks.average)) asleep, over \(figures.noDrinks.nights) nights."
    case .heartRateVariability:
      "Heart rate variability. On nights you logged drinks, \(milliseconds(figures.drinks.average)) milliseconds, over \(figures.drinks.nights) nights. On nights recorded as no alcohol, \(milliseconds(figures.noDrinks.average)) milliseconds, over \(figures.noDrinks.nights) nights."
    case .wristTemperature:
      "Wrist temperature. On nights you logged drinks, \(spokenTemperature(figures.drinks.average, in: temperatureUnit)), over \(figures.drinks.nights) nights. On nights recorded as no alcohol, \(spokenTemperature(figures.noDrinks.average, in: temperatureUnit)), over \(figures.noDrinks.nights) nights."
    }
  }

  /// The source and the span, the way the population reference names its
  /// survey — one key per range, never a span interpolated into a shared
  /// sentence.
  static func sourceLine(for range: TrendRange) -> LocalizedStringKey {
    switch range {
    case .week: "From Apple Health, last 7 days"
    case .month: "From Apple Health, last 30 days"
    case .quarter: "From Apple Health, last 13 weeks"
    case .year: "From Apple Health, last 12 months"
    }
  }

  /// The disclosure's note: what the figures are, what each column holds —
  /// the definition the short heads need, written to match the domain
  /// exactly — and what happens to the data. Written for any number of rows:
  /// each row is the same two averages of a different figure, and the
  /// switch's caption in Settings says what each figure is.
  static let sourceNote: LocalizedStringKey =
    "Each row is two averages of your own Health data over the nights counted here, read from Apple Health on this device. Drinks means nights you logged drinks. No drinks means nights you recorded as no alcohol; a night with nothing logged is in neither column. A night without a reading is not counted. Tallyist keeps none of it."

  /// "18 nights with drinks logged and 31 recorded as no alcohol, last 13
  /// weeks" — the offer's only real numbers, from the log alone, so they are
  /// the same for every row. One key per range.
  static func offerCounts(_ buckets: NightBuckets, range: TrendRange) -> LocalizedStringKey {
    let drinks = buckets.drinks.count
    let none = buckets.noDrinks.count
    switch range {
    case .week:
      return "\(drinks) nights with drinks logged and \(none) recorded as no alcohol, last 7 days"
    case .month:
      return "\(drinks) nights with drinks logged and \(none) recorded as no alcohol, last 30 days"
    case .quarter:
      return "\(drinks) nights with drinks logged and \(none) recorded as no alcohol, last 13 weeks"
    case .year:
      return "\(drinks) nights with drinks logged and \(none) recorded as no alcohol, last 12 months"
    }
  }

  /// What the offer is, in three sentences: who records the figures, what the
  /// app would do with them, and what it does not do. "Apple Watch", not
  /// "your watch": the offer is shown on the strength of the log alone, and a
  /// reader without a watch is a reader too. Plural now that two metrics ship
  /// — the design's own wording, which Phase 3 made singular for one.
  static let offerBody: LocalizedStringKey =
    "Apple Watch already records these. Tallyist can show them here, beside your log. They are read from Apple Health on this device and never stored."
}
