import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Records a past day from the calendar: how many drinks, or none at all.
///
/// This is a *backfill* surface, not the fast path. Today's logging stays two taps
/// through `TodayView`; this exists for the evening you didn't log at the time, and
/// for saying out loud that a day had nothing in it.
///
/// Deliberately coarser than `DrinkDetailSheet`: a count, not a size and a strength.
/// Reconstructing exact volumes days later is guesswork, and asking for precision
/// the user doesn't have produces worse data than asking for the number they do
/// remember. Anything logged here stays individually editable afterwards.
///
/// **Zero is a value on the counter, not a separate button.** "I had none" and "I
/// had three" are the same question answered differently, so they take the same
/// control — which also means the answer "none" costs exactly as many taps as any
/// other, rather than being tucked away as a special case.
struct DayLogSheet: View {
  let day: Date
  let existingDrinks: [LoggedDrink]
  let isMarkedAlcoholFree: Bool
  /// Type and defaults seeded from what's usually logged.
  let seed: LoggedDrink?

  var onLogDrinks: (Int) -> Void
  var onMarkAlcoholFree: () -> Void
  var onClearAlcoholFree: () -> Void
  var onEditDrink: (LoggedDrink) -> Void

  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss

  @State private var count: Int

  init(
    day: Date,
    existingDrinks: [LoggedDrink],
    isMarkedAlcoholFree: Bool,
    seed: LoggedDrink?,
    onLogDrinks: @escaping (Int) -> Void,
    onMarkAlcoholFree: @escaping () -> Void,
    onClearAlcoholFree: @escaping () -> Void,
    onEditDrink: @escaping (LoggedDrink) -> Void
  ) {
    self.day = day
    self.existingDrinks = existingDrinks
    self.isMarkedAlcoholFree = isMarkedAlcoholFree
    self.seed = seed
    self.onLogDrinks = onLogDrinks
    self.onMarkAlcoholFree = onMarkAlcoholFree
    self.onClearAlcoholFree = onClearAlcoholFree
    self.onEditDrink = onEditDrink
    // Opens on nothing-yet-decided for an empty day, and on one for a day that
    // already has drinks — where the question is how many to add, and adding none
    // isn't an answer.
    _count = State(initialValue: existingDrinks.isEmpty ? 0 : 1)
  }

  private var countRange: ClosedRange<Int> {
    existingDrinks.isEmpty ? 0...12 : 1...12
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
          if !existingDrinks.isEmpty {
            loggedSection
          }
          counterSection
          primaryAction
          if existingDrinks.isEmpty && isMarkedAlcoholFree {
            markedState
          }
        }
        .screenMargin()
        .padding(.vertical, GlassTokens.Spacing.section)
      }
      .navigationTitle(day.formatted(.dateTime.weekday(.wide).month().day()))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  // MARK: - Counter

  private var counterSection: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      SectionLabel(existingDrinks.isEmpty ? "How many drinks" : "How many more")
        .frame(maxWidth: .infinity, alignment: .leading)

      CountStepper(
        value: $count,
        range: countRange,
        style: .prominent,
        unitLabel: "Drinks"
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

  private var countCaption: String {
    if count == 0 {
      return "Records the day as having no alcohol."
    }
    guard let seed else {
      return "Logged at the default size and strength — edit any of them afterwards."
    }
    return "Logged as \(seed.type.displayName.lowercased()), \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — edit any of them afterwards."
  }

  // MARK: - Action

  private var primaryAction: some View {
    SUButton(model: .primary(actionTitle)) {
      if count == 0 {
        onMarkAlcoholFree()
      } else {
        onLogDrinks(count)
      }
      dismiss()
    }
  }

  /// Factual in both directions. "Record no alcohol" states what happened; it
  /// doesn't congratulate anyone for it.
  private var actionTitle: String {
    switch count {
    case 0: "Record no alcohol"
    case 1: existingDrinks.isEmpty ? "Log 1 drink" : "Add 1 more"
    default: existingDrinks.isEmpty ? "Log \(count) drinks" : "Add \(count) more"
    }
  }

  private var markedState: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      Label("Already recorded as no alcohol", systemImage: "checkmark.circle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("Remove that record") {
        onClearAlcoholFree()
        dismiss()
      }
      .font(.footnote)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Already has entries

  private var loggedSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("Logged that day")
      VStack(spacing: GlassTokens.Spacing.tight) {
        ForEach(existingDrinks) { drink in
          // Imported Health entries are read-only (ADR-0013); only the app's
          // own entries open the editor.
          if drink.isImportedFromHealth {
            DrinkRow(drink: drink, region: settings.effectiveRegion)
          } else {
            Button {
              onEditDrink(drink)
            } label: {
              DrinkRow(drink: drink, region: settings.effectiveRegion)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}
