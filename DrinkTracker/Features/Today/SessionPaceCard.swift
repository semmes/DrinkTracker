import DrinkTrackerCore
import SwiftData
import SwiftUI

/// The session pace card (1.2 spec, Feature B; ADR-0017, amended by ADR-0034).
///
/// Appears on Today only while both are true: the user turned it on in
/// Settings, and a drink was logged within the gap threshold. When the
/// session ends it simply stops rendering — nothing is written, recorded, or
/// remembered, which is the difference between a measurement and a streak.
///
/// Three facts, flat, no judgment. The optional fourth line is the rolling
/// two-hour count.
///
/// **That line now carries the ramp** (the owner's call, 2026-09-06, reversing
/// ADR-0017's "styled with weight, never color"). What makes it a report rather
/// than a coach is that the colour is not urgency styling invented for this
/// card: it is `DayIntensity` over the window's own standard drinks, the same
/// fold and the same palette as the calendar cell for the day it sits inside.
/// A shade here means exactly what that shade means everywhere else in the app
/// — an amount, on one scale.
///
/// Worth stating plainly, because it is the one seam: the chip *prints* a count
/// of entries and is *shaded* by that window's standard drinks, and for typed
/// drinks the two diverge — four large beers print "4" on a `.high` fill. That
/// is the same divergence the hero already shows between its numeral and the
/// "≈ N standard drinks" line beneath it, and the ramp has to stay keyed to the
/// amount or it would mean something different here than on the calendar.
///
/// Two consequences of that, deliberately kept: it escalates only from `.high`
/// upward, because the ramp's ink flips to white at `.medium` and white on
/// `#2a78d6` is 4.42:1 — under AA at this text size (the argument is at
/// `paceBand`) — and nothing about the chip is red, pulsing, or exclamatory.
///
/// Update discipline, per the spec: the whole card sits in a 60-second
/// `TimelineView` so session existence and the rolling count recompute on a
/// slow clock, while "Last drink … ago" is a self-updating
/// `Text(_:style:.relative)` that costs nothing between ticks. No `Timer`,
/// no one-second wakeups.
struct SessionPaceCard: View {
  @Environment(AppSettings.self) private var settings
  @Environment(\.colorScheme) private var scheme

  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var entries: [DrinkEntry]

  var body: some View {
    if settings.showsSessionPace {
      TimelineView(.periodic(from: .now, by: 60)) { context in
        if let session = SessionPace.currentSession(
          in: entries.loggedDrinks, now: context.date
        ) {
          card(for: session, now: context.date)
        }
      }
    }
  }

  private func card(for session: DrinkSession, now: Date) -> some View {
    let rolling = SessionPace.rollingCount(in: entries.loggedDrinks, now: now)

    return VStack(alignment: .leading, spacing: 4) {
      Text(sessionLine(session.count))
        .font(.title3.weight(.semibold))
        .foregroundStyle(.primary)

      Group {
        Text("Started \(session.start.formatted(date: .omitted, time: .shortened))")
        // Formatted against the TimelineView's clock, so it refreshes once a
        // minute — the cadence the value actually changes at. (The
        // self-updating Text(style:.relative) renders "3 min, 0 sec ago",
        // counting seconds at a number that shouldn't feel like a stopwatch.)
        // lastDrinkAt is clamped to now in the domain, so never negative.
        Text(lastDrinkLine(session.lastDrinkAt, now: now))
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)

      if rolling >= SessionPace.rollingDisplayMinimum {
        rollingChip(rolling, band: paceBand(now: now))
          .padding(.top, GlassTokens.Spacing.tight)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GlassTokens.Spacing.cardPadding)
    .glassSurface(cornerRadius: GlassTokens.Radius.card)
    .accessibilityElement(children: .combine)
  }

  /// The chip. A band paints it with that ramp step and its own validated ink;
  /// no band leaves it on the neutral capsule the card has always used.
  private func rollingChip(_ count: Double, band: DayIntensity?) -> some View {
    Text(rollingLine(count))
      .font(.subheadline.weight(.medium))
      .foregroundStyle(band.map { IntensityPalette.ink($0, scheme: scheme) } ?? .primary)
      // Wraps rather than running off the card. At accessibility sizes the
      // sentence is wider than the card, and a capsule sized to its text will
      // happily overflow its parent — the chip clipped mid-word at AX5.
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, GlassTokens.Spacing.regular)
      .padding(.vertical, GlassTokens.Spacing.tight)
      .background {
        if let band {
          Capsule().fill(IntensityPalette.fill(band, scheme: scheme))
        } else {
          Capsule().fill(.quaternary)
        }
      }
      // The shade adds no accessibility value: the count is printed inside the
      // chip and the amount it is keyed to is the same figure the hero states
      // in words. The card is one combined element anyway.
      .animation(.smooth(duration: 0.25), value: band)
  }

  /// The window's band, or nil to stay neutral.
  ///
  /// Only `.high` and `.veryHigh` tint, for a measured reason rather than a
  /// cautious one: the ramp's ink flips to white at `.medium`, and white on
  /// `#2a78d6` is 4.42:1 — under AA for text this size, where the calendar
  /// gets away with the same pair only because a day numeral is large text.
  /// `.high` and `.veryHigh` measure 11.95:1 and 17.97:1 in light, 11.75:1 and
  /// 15.87:1 in dark, and are separated from each other by ΔL\* 0.153 / 0.108
  /// — above the ramp's own gate. So the chip has three states, and each one
  /// is a value that was already validated.
  private func paceBand(now: Date) -> DayIntensity? {
    let total = SessionPace.rollingStandardDrinks(
      in: entries.loggedDrinks, now: now, region: settings.effectiveRegion
    )
    let band = DayIntensity.bucket(
      standardDrinks: total, isMarkedAlcoholFree: false, hasEntries: true
    )
    return band == .high || band == .veryHigh ? band : nil
  }

  private func lastDrinkLine(_ date: Date, now: Date) -> LocalizedStringKey {
    let elapsed = now.timeIntervalSince(date)
    guard elapsed >= 60 else { return "Last drink just now" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return "Last drink \(formatter.localizedString(for: date, relativeTo: now))"
  }

  /// Both branches are whole keys carrying the count, so a translation can
  /// reorder them. The count arrives as a string, so a catalog can hold these two
  /// source phrases but not per-language plural variations on top of them — a
  /// plural rule cannot select a category from a `%@`.
  ///
  /// That is deferred, not permanent: `\(value, specifier: "%g")` emits a numeric
  /// specifier and renders the same digits, given the same pre-rounding
  /// `StandardDrink.formatted` does. Worth doing when a language is actually
  /// chosen, since it cannot be verified before then; the recipe is in
  /// docs/localization-status.md.
  private func sessionLine(_ count: Double) -> LocalizedStringKey {
    let value = StandardDrink.formatted(count)
    return StandardDrink.readsAsOne(count)
      ? "\(value) drink this session"
      : "\(value) drinks this session"
  }

  private func rollingLine(_ count: Double) -> LocalizedStringKey {
    "\(StandardDrink.formatted(count)) in the last 2 hours"
  }
}
