import DrinkTrackerCore
import SwiftUI

/// One of today's drinks (ADR-0034).
///
/// Deliberately not `DrinkRow`. History and the day sheet are *reading*
/// surfaces, where the per-entry standard-drink figure is the point of the
/// column; Today already prints the day's total twice above this list, so a
/// third copy of the same arithmetic per row is noise. What Today needs instead
/// is the time and a way in, which is what the trailing pair carries.
///
/// The figure is not lost — it stays in the accessibility label, which is the
/// only place a VoiceOver reader ever gets the region lens per entry.
struct TodayDrinkRow: View {
  let drink: LoggedDrink
  let region: Region
  /// False for an imported Health entry that cannot be adopted: nothing to
  /// open, so no chevron and no button trait (ADR-0014).
  var isTappable: Bool = true
  /// Marks the entry the counter just wrote, and the one − would take back.
  var isMostRecent: Bool = false

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    let layout = typeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
      : AnyLayout(HStackLayout(spacing: GlassTokens.Spacing.regular))

    return layout {
      HStack(spacing: GlassTokens.Spacing.regular) {
        // A catalog symbol, never `systemName:`, and decorative — the row
        // speaks its own label below (ADR-0036).
        Image(decorative: symbolName)
          .font(.body)
          .foregroundStyle(iconStyle)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 1) {
          title
            .font(.callout)
            .foregroundStyle(drink.recordsSizeAndStrength ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
          subtitle
            .font(.caption)
        }
      }

      if !typeSize.isAccessibilitySize { Spacer(minLength: GlassTokens.Spacing.tight) }

      HStack(spacing: GlassTokens.Spacing.tight) {
        Text(drink.loggedAt.formatted(date: .omitted, time: .shortened))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .monospacedDigit()

        if isTappable {
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
      }
      .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
    }
    .padding(.vertical, 4)
    .listRowBackground(recencyTint)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityHint(drink.isTypeUnspecified && isTappable ? Text("Add what it was") : Text(verbatim: ""))
    .accessibilityAddTraits(isTappable ? [.isButton] : [])
  }

  /// A wash, not the calendar's 0.15 selection wash: that value means "a bulk
  /// action will write to this day" (ADR-0011), and reusing it here would
  /// import its meaning along with its alpha.
  private var recencyTint: some View {
    RoundedRectangle(cornerRadius: GlassTokens.Radius.control, style: .continuous)
      .fill(isMostRecent ? Color.accentColor.opacity(0.08) : .clear)
  }

  private var symbolName: String {
    drink.isImportedFromHealth ? DrinkType.Symbol.health : drink.type.symbolName
  }

  /// Secondary rather than the drawn 40%-black: that value measures 2.14:1 and
  /// falls under the 3:1 floor for a meaningful glyph.
  private var iconStyle: AnyShapeStyle {
    drink.recordsSizeAndStrength ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary)
  }

  /// `Text`, not a key, for the same reason `DrinkRow` gives: one branch is a
  /// real sentence, the other is a name the package already localized.
  ///
  /// The untyped row keeps the package's own "One standard drink" rather than
  /// the drawing's "Standard drink". That key is worded the way it is to avoid
  /// an `xcstringstool generate-symbols` case collision with the region unit
  /// name, and it is simultaneously the CSV entry, the summary line and Siri's
  /// reply — renaming it on Today alone would make one entry read two ways
  /// across four surfaces.
  private var title: Text {
    drink.isImportedFromHealth
      ? Text("From Apple Health")
      : Text(verbatim: drink.type.displayName)
  }

  @ViewBuilder
  private var subtitle: some View {
    if drink.recordsSizeAndStrength {
      Text(verbatim: "\(LoggedDrink.displayOunces(drink.volumeOunces))oz · \(LoggedDrink.displayPercent(drink.abvPercent))%")
        .foregroundStyle(.secondary)
    } else if let counted = drink.countedDrinks {
      // Read-only mirror of another app's row: there is nothing to add here,
      // so it must not offer to (ADR-0014, ADR-0016).
      //
      // Bound here rather than guarded inside a helper: a helper returning ""
      // for the impossible branch puts an *empty key* in the catalog, which is
      // what the first sync of this file actually produced.
      Text(countedLine(counted))
        .foregroundStyle(.secondary)
    } else {
      // The one row that invites a tap, so the one row whose subtitle is an
      // action rather than a fact. Accent, because it is the affordance.
      Text("Tap to say what it was")
        .foregroundStyle(Color.accentColor)
    }
  }

  private func countedLine(_ counted: Double) -> LocalizedStringKey {
    let count = LoggedDrink.displayOunces(counted)
    return counted == 1 ? "counted as 1 drink" : "counted as \(count) drinks"
  }

  /// Everything the visible row drops, spoken: the time, the fact that size and
  /// strength were never recorded, and the entry's own contribution in the
  /// current region's unit — the only per-entry statement of the lens a
  /// VoiceOver reader gets on this screen.
  ///
  /// Composed verbatim because every part arrives translated; written as a key
  /// it would extract as "%@, %@, %@ %@" and ask a translator to localize
  /// commas.
  private var accessibilityLabel: Text {
    let value = drink.standardDrinks(in: region)
    let count = StandardDrink.formatted(value)
    let name = drink.isImportedFromHealth
      ? String(localized: "From Apple Health")
      : drink.type.displayName
    let time = drink.loggedAt.formatted(date: .omitted, time: .shortened)
    let detail: String
    if let counted = drink.countedDrinks {
      let counts = LoggedDrink.displayOunces(counted)
      detail = counted == 1
        ? String(localized: "\(time) · counted as 1 drink")
        : String(localized: "\(time) · counted as \(counts) drinks")
    } else if drink.isTypeUnspecified {
      detail = String(localized: "\(time) · no size or strength recorded")
    } else {
      detail = String(
        localized: "\(time) · \(LoggedDrink.displayOunces(drink.volumeOunces))oz · \(LoggedDrink.displayPercent(drink.abvPercent))% ABV"
      )
    }
    return Text(verbatim: "\(name), \(detail), \(count) \(region.unitName(for: value))")
  }
}
