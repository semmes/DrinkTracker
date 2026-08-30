import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Applies one answer to a run of days selected by dragging on the calendar.
///
/// Exists for the infrequent logger: someone who opens the app once a week and
/// mostly has the same thing to say about most days — usually "nothing". Selecting
/// nine days and answering once beats nine round-trips through the day sheet.
///
/// The counter here is a staged batch — the model `DayLogSheet` had before
/// ADR-0013 made it a live log — because a batch is the point of this surface:
/// zero records each day as alcohol-free, N logs N drinks on each, applied once
/// on confirm. **Days that already
/// have a record — entries or an alcohol-free marker — are never touched.** A bulk
/// gesture is a coarse instrument, and overwriting an evening someone logged
/// deliberately with a swept-over default would destroy their most precise data
/// with their least precise input. The sheet says how many days it will skip; the
/// day sheet remains the way to change a recorded day, one day at a time.
struct BulkFillSheet: View {
  /// The dragged-over run, chronological, already filtered to past days.
  let days: [CalendarDay]
  /// Type and defaults seeded from what's usually logged.
  let seed: LoggedDrink?
  /// Called with the count and the days that will actually be written.
  var onApply: (Int, [Date]) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var count = 0

  /// Days with no record in either direction — the only ones bulk fill writes to.
  private var fillableDays: [CalendarDay] {
    days.filter { !$0.hasEntries && !$0.isMarkedAlcoholFree }
  }

  private var skippedCount: Int { days.count - fillableDays.count }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
          counterSection
          primaryAction
          if skippedCount > 0 { skippedNote }
        }
        .screenMargin()
        .padding(.vertical, GlassTokens.Spacing.section)
      }
      .navigationTitle(rangeTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Cancel") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  /// Formatted dates and a dash — the locale already handles both, and a key
  /// here would extract as an empty string or a bare "%@".
  private var rangeTitle: String {
    guard let first = days.first?.date, let last = days.last?.date else { return "" }
    guard days.count > 1 else {
      return first.formatted(.dateTime.month(.wide).day())
    }
    return "\(first.formatted(.dateTime.month().day())) – \(last.formatted(.dateTime.month().day()))"
  }

  // MARK: - Counter

  private var counterSection: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      SectionLabel(days.count == 1 ? "For this day" : "For each of these days")
        .frame(maxWidth: .infinity, alignment: .leading)

      CountStepper(
        value: $count,
        range: 0...12,
        style: .prominent,
        unitLabel: "Drinks per day"
      )

      Text(countCaption)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .animation(nil, value: count)
    }
  }

  private var countCaption: LocalizedStringKey {
    if count == 0 {
      return "Records each day as having no alcohol."
    }
    guard let seed else {
      return "Logged at the default size and strength — edit any of them afterwards."
    }
    if seed.isTypeUnspecified {
      return "Each logged as one standard drink, with no type — edit any of them afterwards."
    }
    return "Each logged as \(seed.type.displayName.lowercased()), \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — edit any of them afterwards."
  }

  // MARK: - Action

  private var primaryAction: some View {
    SUButton(model: .primary(actionTitle, isEnabled: !fillableDays.isEmpty)) {
      onApply(count, fillableDays.map(\.date))
      dismiss()
    }
  }

  /// Factual in both directions, and always says how many days it touches — the
  /// number on the button is the write about to happen, not the selection size.
  ///
  /// Still `String`, unlike the rest of the sheet's copy: `ButtonVM.title` takes
  /// one, so these literals cannot reach the string catalog until it doesn't.
  private var actionTitle: String {
    let dayCount = fillableDays.count
    guard dayCount > 0 else { return "Nothing to record" }
    let dayPhrase = dayCount == 1 ? "1 day" : "\(dayCount) days"
    if count == 0 {
      return "Record no alcohol for \(dayPhrase)"
    }
    let drinkPhrase = count == 1 ? "1 drink" : "\(count) drinks"
    return dayCount == 1
      ? "Log \(drinkPhrase) on 1 day"
      : "Log \(drinkPhrase) on each of \(dayPhrase)"
  }

  private var skippedNote: some View {
    Label(skippedText, systemImage: "checkmark.circle")
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// Factual about the gap between what was selected and what will be written.
  private var skippedText: LocalizedStringKey {
    if fillableDays.isEmpty {
      return "Every selected day already has a record. Tap a day to change it."
    }
    return skippedCount == 1
      ? "1 day already has a record and will be kept."
      : "\(skippedCount) days already have a record and will be kept."
  }
}
