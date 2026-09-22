import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Apple Health figures beside the log, at the bottom of Trends (ADR-0048,
/// ADR-0049, ADR-0050): one card, two averages of the reader's own Health data
/// side by side — nights they logged drinks, nights they recorded as no
/// alcohol — with the nights behind each, and nothing that relates one to the
/// other. Resting heart rate is the one metric that ships (Phase 3); later
/// phases add a row each, under the same heading, from the same parts.
///
/// ## What holds the line
///
/// Every previous figure in the app reports a quantity of alcohol. This is the
/// first that puts a second axis beside it, and that axis carries a direction
/// the reader already believes in — "62 bpm on nights with drinks, 58 without"
/// is a verdict no sentence has to deliver. So the discipline is structural
/// (the plan's four rules, ADR-0050): the domain returns two figures and never
/// a difference; a sample-size gate hides the whole row below fourteen nights
/// with a value in *either* column; no colour, no arrow, no chart; and the
/// buckets come from the log alone — nothing here reads a heart rate to decide
/// anything about drinking.
///
/// ## The heading cannot outlive its content
///
/// `ComparisonsSection`'s rule, kept: the section resolves the row's condition
/// and the offer's once, and the heading's condition is the literal
/// disjunction of the two. The card does not read the switch; the offer does
/// not read the switch; only `resolve` does.
///
/// ## Read, compute, render, discard
///
/// `HealthPairingModel.load` reads the samples, folds them into the two
/// figures and drops them in the same call; the model keeps the figures for
/// the render and nothing else, and clears them the moment the switch is off.
/// Nothing is written anywhere but the one timing breadcrumb the read layer
/// leaves (ADR-0049). The load is driven by `TrendsView`, because a `.task`
/// has to hang off a view that exists, and this section renders nothing at
/// all when it has nothing to show — a zero-height stand-in would still take
/// the screen's section spacing, and the design's first acceptance check is
/// that Trends is pixel-identical with everything off.
struct HealthPairingSection: View {
  /// The request this render would read, or nil when nothing could be shown
  /// — the switch off and the offer answered — in which case `TrendsView`
  /// does not derive one and the section draws nothing.
  let request: HealthPairingRequest?
  /// The figures the model last computed, with the request they answer, or
  /// nil: not loaded yet, no data, below the gate, or the switch off (the
  /// model clears them). The section decides whether to draw them; the card
  /// never re-checks.
  let loaded: HealthPairingModel.Loaded?
  let onAcceptOffer: () -> Void
  let onDeclineOffer: () -> Void

  @Environment(AppSettings.self) private var settings

  var body: some View {
    let shown = resolve()

    if shown.row != nil || shown.offer, let request {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        SectionLabel("From Apple Health")

        // The card is drawn from what was read, under the range that read
        // covered: on a range change the previous card stands until the new
        // read lands, then both the figures and their source line change
        // together, so a figure is never shown under another range's name.
        if let loaded = shown.row {
          HealthPairingCard(figures: loaded.figures, range: loaded.request.range)
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
    var row: HealthPairingModel.Loaded?
    var offer = false
  }

  /// The two conditions, resolved once. The row: the switch on and figures
  /// that cleared the gate. The offer: never answered, no pairing switch on,
  /// and the log alone clearing the gate on **both** sides — the drink side
  /// the design named, and the no-drinks side too, because that column holds
  /// nights recorded as no alcohol (ADR-0048) and is not plentiful by nature;
  /// an offer gated on one side could be accepted, granted, and show nothing.
  private func resolve() -> Shown {
    var shown = Shown()
    if settings.showsRestingHeartRatePairing {
      shown.row = loaded
    } else if !settings.hasAnsweredHealthPairingOffer, let request, request.buckets.clearsGate() {
      shown.offer = true
    }
    return shown
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

/// The figures for the render, and the read that produces them.
///
/// One instance, owned by `TrendsView` as `@State`, loaded from its `.task`.
/// `load` is the whole of the pairing's contact with Health in the app: read
/// the samples, file them by night, fold the two figures, and let the samples
/// go — they are locals of one call. What survives is `loaded`, two means and
/// two counts with the request they answer, which is what the card draws;
/// and `clear` drops even that the moment nothing should be drawn.
@Observable
@MainActor
final class HealthPairingModel {
  /// What a read produced, with the request it was made for, so the card
  /// draws figures only under the range they cover.
  struct Loaded: Equatable {
    let request: HealthPairingRequest
    let figures: PairedFigures
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

  /// Reads resting heart rate for `request` and replaces `loaded` — under the
  /// design's structure-change animation, so a card that appears fades in and
  /// figures that change crossfade. Skipped, and cleared, when the log alone
  /// cannot clear the gate: the table's gate counts nights with a value, never
  /// more than the log's nights, so no read could produce a row (ADR-0049's
  /// reads happen only where a row is possible).
  func load(_ request: HealthPairingRequest, health: HealthKitService) async {
    guard request.buckets.clearsGate() else {
      clear()
      return
    }
    let samples = await health.restingHeartRate(
      in: request.window, endingBefore: request.today, calendar: request.calendar)
    guard !Task.isCancelled else { return }
    let values = HealthPairing.nightlyValues(
      of: samples, for: request.nights, attribution: .dayAfter, calendar: request.calendar)
    let result = HealthPairing.figures(request.buckets, values: values)
      .map { Loaded(request: request, figures: $0) }
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
/// title beside two column heads on one baseline; the metric row is the name
/// over its two night counts, then the two figures with their unit; then the
/// source line.
///
/// The numerals are rounded and tabular because they are the reader's own
/// (design-system §3). Units and labels stay default SF. No colour anywhere
/// on the card: the only brand colour on this feature's surfaces is the
/// switch's tint and the offer's two buttons, and a colour on a figure here
/// would be a delta drawn (the Phase 3 block's own rule).
struct HealthPairingCard: View {
  let figures: PairedFigures
  let range: TrendRange

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  /// The weekday table's fold, read from the one shared place.
  private var isStacked: Bool { ComparisonTable.folds(dynamicTypeSize) }

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        if isStacked {
          stackedFigures
        } else {
          figureTable
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
      // trait; the heads are hidden because the row's own sentence speaks the
      // long phrases the short heads stand for.
      GridRow(alignment: .firstTextBaseline) {
        CardTitle("Your averages")
          .frame(maxWidth: .infinity, alignment: .leading)
          .gridColumnAlignment(.leading)
        ComparisonTable.columnHead(Text("Drinks"))
          .accessibilityHidden(true)
        ComparisonTable.columnHead(Text("No drinks"))
          .accessibilityHidden(true)
      }
      .padding(.bottom, GlassTokens.Spacing.tight)

      Divider()

      // One VoiceOver stop, its label on the name cell and the figure cells
      // hidden — the weekday table's lesson: a modifier on a `GridRow` lands
      // on every cell.
      GridRow(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Resting heart rate")
            .font(.subheadline)
            .foregroundStyle(.primary)
          nightsCaption
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gridColumnAlignment(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel)

        figureCell(figures.drinks.average)
          .accessibilityHidden(true)
        figureCell(figures.noDrinks.average)
          .accessibilityHidden(true)
      }
      .padding(.vertical, GlassTokens.Spacing.tight)
    }
  }

  /// "18 and 31 nights" — the counts that let a reader weigh the two averages,
  /// which is the honest alternative to the app weighing them. The numerals a
  /// step darker, as the ratio cell's are; one key with both, so a translation
  /// can reorder them.
  private var nightsCaption: some View {
    Text(
      "\(Text(verbatim: String(figures.drinks.nights)).font(GlassTokens.Typography.rowCount).foregroundColor(.primary)) and \(Text(verbatim: String(figures.noDrinks.nights)).font(GlassTokens.Typography.rowCount).foregroundColor(.primary)) nights"
    )
    .font(.caption)
    .monospacedDigit()
    .foregroundStyle(.secondary)
  }

  /// The figure in the reader's numeral face, its unit beside it in default
  /// SF. A subject change crossfades (the range switched); a value never
  /// rolls here, because a roll between two ranges would draw a direction.
  private func figureCell(_ average: Double) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 3) {
      Text(verbatim: HealthPairingCopy.beatsPerMinute(average))
        .font(GlassTokens.Typography.rowFigure)
        .monospacedDigit()
        .foregroundStyle(.primary)
        .contentTransition(.opacity)
      Text("bpm")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .animation(.smooth(duration: 0.22), value: average)
  }

  /// From `.xLarge` up, the fold the weekday table takes: the name, then one
  /// line per column with its label written out — the same sentences VoiceOver
  /// speaks, so nothing a reader meets at a large size is newly worded.
  private var stackedFigures: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      CardTitle("Your averages")
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        Text("Resting heart rate")
          .font(.subheadline)
          .foregroundStyle(.primary)
        Text(HealthPairingCopy.drinksSentence(figures.drinks))
        Text(HealthPairingCopy.noDrinksSentence(figures.noDrinks))
      }
      .font(.body)
      .foregroundStyle(.primary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(rowLabel)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// "Resting heart rate. On nights you logged drinks, 62 beats per minute,
  /// over 18 nights. On nights recorded as no alcohol, 58 beats per minute,
  /// over 31 nights." The long phrases, not the heads; no comparative word.
  private var rowLabel: Text {
    Text(HealthPairingCopy.rowSentence(figures))
  }
}

// MARK: - The one-time offer

/// The table's own shape with its figure cells empty, the drink log's counts
/// as the only real numbers on it, one sentence saying what it is, and one
/// primary action (ADR-0050). It shows before it asks: what the reader is
/// agreeing to is on screen rather than described. It appears once — the
/// section decides when — and both answers are final and silent.
struct HealthPairingOffer: View {
  let buckets: NightBuckets
  let range: TrendRange
  let onAccept: () -> Void
  let onDecline: () -> Void

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var isStacked: Bool { ComparisonTable.folds(dynamicTypeSize) }

  var body: some View {
    SUCard(model: .glass) {
      VStack(alignment: .leading, spacing: 0) {
        if isStacked {
          stackedOffer
        } else {
          offerTable
        }

        // Its own VoiceOver stop, after the row it counts for; the
        // placeholders above say nothing, so this is where the numbers are.
        Text(HealthPairingCopy.offerCounts(buckets, range: range))
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, GlassTokens.Spacing.tight)
          .accessibilitySortPriority(1)

        Divider()
          .opacity(0.7)
          .padding(.vertical, GlassTokens.Spacing.regular)

        // The card's label, first for VoiceOver: what it is, then the row it
        // shows, then the two actions.
        Text(HealthPairingCopy.offerBody)
          .font(.body)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilitySortPriority(2)

        VStack(spacing: GlassTokens.Spacing.tight) {
          SUButton(model: .primary(String(localized: "Show this on Trends"))) {
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
  /// may not reach its children. Title and name at 1, so with the counts
  /// (also 1) they follow the body (2) in layout order, ahead of the buttons.
  private var offerTable: some View {
    Grid(alignment: .trailing, horizontalSpacing: GlassTokens.Spacing.tight, verticalSpacing: 0) {
      GridRow(alignment: .firstTextBaseline) {
        CardTitle("Your averages")
          .frame(maxWidth: .infinity, alignment: .leading)
          .gridColumnAlignment(.leading)
          .accessibilitySortPriority(1)
        ComparisonTable.columnHead(Text("Drinks"))
          .accessibilityHidden(true)
        ComparisonTable.columnHead(Text("No drinks"))
          .accessibilityHidden(true)
      }
      .padding(.bottom, GlassTokens.Spacing.tight)

      Divider()

      GridRow(alignment: .firstTextBaseline) {
        Text("Resting heart rate")
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

  /// The empty figure cell. Tertiary ink, the figure's own face and width, so
  /// the real table lands in the same place; nothing for VoiceOver, which the
  /// design asks for by name — an empty cell read aloud is a value withheld.
  private var placeholder: some View {
    Text(verbatim: "– –")
      .font(GlassTokens.Typography.rowFigure)
      .monospacedDigit()
      .foregroundStyle(.tertiary)
      .accessibilityHidden(true)
  }

  private var stackedOffer: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      CardTitle("Your averages")
        .accessibilitySortPriority(1)
      Text("Resting heart rate")
        .font(.subheadline)
        .foregroundStyle(.primary)
        .accessibilitySortPriority(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Copy

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

  /// "On nights you logged drinks, 62 beats per minute, over 18 nights." The
  /// long phrase the short head stands for; spoken, and shown at the sizes
  /// where the table folds. The count is never below the gate, so the noun is
  /// the plural.
  static func drinksSentence(_ figure: PairedFigures.Figure) -> LocalizedStringKey {
    "On nights you logged drinks, \(beatsPerMinute(figure.average)) beats per minute, over \(figure.nights) nights."
  }

  /// "On nights recorded as no alcohol, 58 beats per minute, over 31 nights."
  /// Recorded, not "other": the column holds the nights the reader marked, and
  /// a night with nothing logged is in neither (ADR-0048).
  static func noDrinksSentence(_ figure: PairedFigures.Figure) -> LocalizedStringKey {
    "On nights recorded as no alcohol, \(beatsPerMinute(figure.average)) beats per minute, over \(figure.nights) nights."
  }

  /// The row as VoiceOver speaks it, in one key: the name, then the two
  /// sentences above. Whole, rather than the two joined, so a translation
  /// orders the spoken sentence as its own language does — and so the label
  /// needs no `+` between `Text`s, which iOS 26 deprecates.
  static func rowSentence(_ figures: PairedFigures) -> LocalizedStringKey {
    "Resting heart rate. On nights you logged drinks, \(beatsPerMinute(figures.drinks.average)) beats per minute, over \(figures.drinks.nights) nights. On nights recorded as no alcohol, \(beatsPerMinute(figures.noDrinks.average)) beats per minute, over \(figures.noDrinks.nights) nights."
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

  /// The disclosure's note: what the two figures are, what each column holds
  /// — the definition the short heads need, written to match the domain
  /// exactly — and what happens to the data.
  static let sourceNote: LocalizedStringKey =
    "Two averages of your own Health data over the nights counted here, read from Apple Health on this device. Drinks means nights you logged drinks. No drinks means nights you recorded as no alcohol; a night with nothing logged is in neither column. A night without a reading is not counted. Tallyist keeps none of it."

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

  /// What the offer is, in three sentences: who records the figure, what the
  /// app would do with it, and what it does not do. "Apple Watch records",
  /// not "your watch": the offer is shown on the strength of the log alone,
  /// and a reader without a watch is a reader too.
  static let offerBody: LocalizedStringKey =
    "Apple Watch records this every day. Tallyist can show it here, beside your log. It is read from Apple Health on this device and never stored."
}
