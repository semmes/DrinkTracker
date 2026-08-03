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

  @State private var count: Int = 1

  private static let countRange = 1...12

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
          if existingDrinks.isEmpty {
            countSection
            actions
          } else {
            loggedSection
            addMoreSection
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

  // MARK: - Nothing logged yet

  private var countSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("How many drinks")

      HStack {
        Text(countDescription)
          .font(.body)
          .foregroundStyle(.primary)
          .contentTransition(.numericText(value: Double(count)))
        Spacer()
        Stepper("How many drinks", value: $count, in: Self.countRange)
          .labelsHidden()
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(height: GlassTokens.Layout.minimumTouchTarget)
      .glassSurface(cornerRadius: GlassTokens.Radius.control)
      .animation(.snappy, value: count)

      if let seed {
        Text("Logged as \(seed.type.displayName.lowercased()), \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — edit any of them afterwards.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var countDescription: String {
    count == 1 ? "Just the one" : "\(count) drinks"
  }

  private var actions: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      SUButton(model: .primary("Log \(count == 1 ? "1 drink" : "\(count) drinks")")) {
        onLogDrinks(count)
        dismiss()
      }

      // The zero case. Phrased as a statement of fact rather than as an
      // achievement — it records what happened, it doesn't award anything.
      if isMarkedAlcoholFree {
        VStack(spacing: GlassTokens.Spacing.tight) {
          Label("Recorded as no alcohol", systemImage: "checkmark.circle")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Button("Remove that") {
            onClearAlcoholFree()
            dismiss()
          }
          .font(.footnote)
        }
        .frame(maxWidth: .infinity)
      } else {
        Button {
          onMarkAlcoholFree()
          dismiss()
        } label: {
          Text("I didn't drink that day")
            .font(.body)
            .frame(maxWidth: .infinity)
            .frame(height: GlassTokens.Layout.minimumTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
      }
    }
  }

  // MARK: - Already has entries

  private var loggedSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("Logged that day")
      VStack(spacing: GlassTokens.Spacing.tight) {
        ForEach(existingDrinks) { drink in
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

  /// No alcohol-free option here: the day plainly wasn't. Removing the entries is
  /// the way to change that, and it happens in the list above.
  private var addMoreSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      HStack {
        Text(countDescription)
          .font(.body)
        Spacer()
        Stepper("How many more", value: $count, in: Self.countRange)
          .labelsHidden()
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(height: GlassTokens.Layout.minimumTouchTarget)
      .glassSurface(cornerRadius: GlassTokens.Radius.control)

      SUButton(model: .primary("Add \(count == 1 ? "1 more" : "\(count) more")")) {
        onLogDrinks(count)
        dismiss()
      }
    }
  }
}
