import DrinkTrackerCore
import SwiftData
import SwiftUI

/// The session pace card (1.2 spec, Feature B; ADR-0017).
///
/// Appears on Today only while both are true: the user turned it on in
/// Settings, and a drink was logged within the gap threshold. When the
/// session ends it simply stops rendering — nothing is written, recorded, or
/// remembered, which is the difference between a measurement and a streak.
///
/// Three facts, flat, no judgment. The optional fourth line (the rolling
/// two-hour count) carries weight and a quiet background — never color, an
/// icon, or urgency styling: the number is the signal, and urgency would
/// turn a report into a coach.
///
/// Update discipline, per the spec: the whole card sits in a 60-second
/// `TimelineView` so session existence and the rolling count recompute on a
/// slow clock, while "Last drink … ago" is a self-updating
/// `Text(_:style:.relative)` that costs nothing between ticks. No `Timer`,
/// no one-second wakeups.
struct SessionPaceCard: View {
  @Environment(AppSettings.self) private var settings

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

    return VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Text(sessionLine(session.count))
        .font(.body.weight(.medium))
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
      .font(.caption)
      .foregroundStyle(.secondary)

      if rolling >= SessionPace.rollingDisplayMinimum {
        Text(rollingLine(rolling))
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)
          .padding(.horizontal, GlassTokens.Spacing.regular)
          .padding(.vertical, GlassTokens.Spacing.tight)
          .background(
            Capsule().fill(.quaternary)
          )
          .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GlassTokens.Spacing.cardPadding)
    .glassSurface(cornerRadius: GlassTokens.Radius.control)
    .accessibilityElement(children: .combine)
  }

  private func lastDrinkLine(_ date: Date, now: Date) -> LocalizedStringKey {
    let elapsed = now.timeIntervalSince(date)
    guard elapsed >= 60 else { return "Last drink just now" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return "Last drink \(formatter.localizedString(for: date, relativeTo: now))"
  }

  /// Both branches are whole keys carrying the count, so a translation can
  /// reorder them. The count still arrives as a string, because the session
  /// total is fractional when Apple Health contributed to it and no numeric
  /// specifier preserves `formatted`'s variable decimals — so a catalog can hold
  /// these two source phrases but not per-language plural variations on top of
  /// them. Same limit `Region.unitName(for:)` documents, for the same reason.
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
