import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Records a past day from the calendar: how many drinks, or none at all.
///
/// This is a *backfill* surface, not the fast path. Today's logging stays one tap
/// through `TodayView`'s counter; this exists for the evening you didn't log at the
/// time, and for saying out loud that a day had nothing in it.
///
/// **The counter is the day's log, same as Today's (ADR-0013).** Plus logs a seeded
/// drink dated this day the moment it is tapped; minus removes the day's most recent
/// entry through the same path as a swipe-delete, undo bar included. The number can
/// never disagree with the list above because they are the same data.
///
/// Deliberately coarser than `DrinkDetailSheet`: a count, not a size and a strength.
/// Reconstructing exact volumes days later is guesswork, and asking for precision
/// the user doesn't have produces worse data than asking for the number they do
/// remember. Anything logged here stays individually editable afterwards.
///
/// **Zero is a statement, not a resting value.** An empty day shows "Record no
/// alcohol" below the counter — the marker stays an explicit claim, and minus-to-zero
/// deliberately does not make it (deleting your last entry says nothing about
/// abstinence, same rule as Today).
struct DayLogSheet: View {
  let day: Date
  let existingDrinks: [LoggedDrink]
  let isMarkedAlcoholFree: Bool
  /// Type and defaults seeded from what's usually logged.
  let seed: LoggedDrink?
  /// Owned by the calendar so an undo stays available after this sheet closes.
  let deletion: DeletionCoordinator

  var onAddDrink: () -> Void
  var onRemoveMostRecent: () -> Void
  var onUndoDelete: () -> Void
  var onMarkAlcoholFree: () -> Void
  var onClearAlcoholFree: () -> Void
  var onEditDrink: (LoggedDrink) -> Void

  @Environment(AppSettings.self) private var settings
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        // Counter first, list second: the sheet opens to change the day, so the
        // controls sit where the thumb already is and the record reads below.
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
          counterSection
          if existingDrinks.isEmpty {
            zeroState
          } else {
            loggedSection
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
      .safeAreaInset(edge: .bottom) {
        // Gated to this sheet's own day: the coordinator is calendar-scoped, and
        // a bar for another day's removal would read as a failed undo here.
        if let drink = deletion.recentlyDeleted,
           Calendar.current.isDate(drink.loggedAt, inSameDayAs: day) {
          UndoDeleteBar(drink: drink, onUndo: onUndoDelete)
            .padding(.bottom, GlassTokens.Spacing.tight)
        }
      }
      .animation(.smooth(duration: 0.25), value: deletion.recentlyDeleted)
    }
    .presentationDetents([.medium, .large])
  }

  // MARK: - Counter

  private var counterSection: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      // The stepper below carries the accessible name; reading the label too
      // would announce it twice back-to-back.
      SectionLabel("Drinks")
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)

      // Upper bound keeps one tap of headroom past the count, so the thirteenth
      // drink of a heavy night is still recordable (12 is a soft floor, not a cap).
      CountStepper(
        value: liveCount,
        range: 0...max(12, existingDrinks.count + 1),
        style: .prominent,
        unitLabel: "Drinks on this day"
      )

      // The precise figure, one line down — same demotion as Today's counter.
      if total > 0 {
        Text(verbatim: StandardDrink.liveEstimate(total, region: settings.effectiveRegion))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      countCaption
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .animation(nil, value: existingDrinks.count)
    }
  }

  /// The counter's binding writes straight to the log, exactly as on Today: an
  /// increment logs a seeded drink dated this day, a decrement removes the day's
  /// most recent entry. The getter re-reads what the calendar's query passed in,
  /// so there is no separate counter state to fall out of sync.
  private var liveCount: Binding<Int> {
    Binding(
      get: { existingDrinks.count },
      set: { newValue in
        let current = existingDrinks.count
        if newValue > current {
          onAddDrink()
        } else if newValue < current {
          onRemoveMostRecent()
        }
      }
    )
  }

  private var total: Double {
    existingDrinks.reduce(0) { $0 + $1.standardDrinks(in: settings.effectiveRegion) }
  }

  /// `Text`, not `String`: a `String` would reach `Text` through the verbatim
  /// initializer and never enter the string catalog. Each sentence is its own
  /// literal, so translators get whole sentences rather than glued fragments.
  private var countCaption: Text {
    let adds: Text
    // "a other" is not a sentence; Other falls back to the generic noun.
    if let seed, seed.type != .other {
      adds = Text("Plus logs a \(seed.type.displayName.lowercased()), \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — editable afterwards.")
    } else if let seed {
      adds = Text("Plus logs a drink, \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — editable afterwards.")
    } else {
      adds = Text("Plus logs a drink at the default size and strength — editable afterwards.")
    }
    guard !existingDrinks.isEmpty else { return adds }
    // Interpolation rather than `+`: concatenating would leave the second
    // sentence in the catalog with a leading space, which a translator will
    // silently drop. (`+` is also deprecated in iOS 26.)
    return Text("\(adds) Minus removes the day's most recent drink.")
  }

  // MARK: - The empty day

  /// Factual in both directions. "Record no alcohol" states what happened; it
  /// doesn't congratulate anyone for it.
  @ViewBuilder
  private var zeroState: some View {
    if isMarkedAlcoholFree {
      markedState
    } else {
      SUButton(model: .primary("Record no alcohol")) {
        onMarkAlcoholFree()
      }
    }
  }

  private var markedState: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      Label("Recorded as no alcohol", systemImage: "checkmark.circle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("Remove that record") {
        onClearAlcoholFree()
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
          // Imported Health entries are read-only (ADR-0014); only the app's
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
