import DrinkTrackerCore
import SwiftUI

/// One logged drink in a list.
///
/// Reads as a record, not a score: time, what it was, and its contribution. No
/// colour coding, because a colour would be a verdict.
struct DrinkRow: View {
  let drink: LoggedDrink
  let region: Region

  var body: some View {
    HStack(spacing: GlassTokens.Spacing.regular) {
      Image(systemName: symbolName)
        .font(.body)
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        title
          .font(.body)
          .foregroundStyle(.primary)
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(StandardDrink.formatted(drink.standardDrinks(in: region)))
        .font(.callout.weight(.medium).monospacedDigit())
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel)
  }

  private var symbolName: String {
    drink.isImportedFromHealth ? "heart.text.square" : drink.type.symbolName
  }

  /// `Text`, not a key: one branch is a real sentence to translate, the other
  /// is a name the package already localized. Wrapping the latter in a key
  /// would add a catalog entry that is nothing but "%@".
  private var title: Text {
    drink.isImportedFromHealth
      ? Text("From Apple Health")
      : Text(verbatim: drink.type.displayName)
  }

  private var detail: LocalizedStringKey {
    let time = drink.loggedAt.formatted(date: .omitted, time: .shortened)
    if let counted = drink.countedDrinks {
      // Size and strength are unknown for another app's entry; saying so beats
      // printing zeros that look like data.
      let count = LoggedDrink.displayOunces(counted)
      return counted == 1
        ? "\(time) · counted as 1 drink"
        : "\(time) · counted as \(count) drinks"
    }
    return "\(time) · \(LoggedDrink.displayOunces(drink.volumeOunces))oz · \(LoggedDrink.displayPercent(drink.abvPercent))% ABV"
  }

  /// Every part is already translated by the time it gets here, so this is
  /// composed verbatim: written as a key it would extract as "%@, %@, %@ %@",
  /// separators with nothing in them, and a translator would be asked to
  /// localize three commas.
  private var accessibilityLabel: Text {
    let value = drink.standardDrinks(in: region)
    let count = StandardDrink.formatted(value)
    let name = drink.isImportedFromHealth
      ? String(localized: "From Apple Health")
      : drink.type.displayName
    return Text(verbatim: "\(name), \(detailText), \(count) \(region.unitName(for: value))")
  }

  /// The same sentence `detail` renders, resolved to a string for the
  /// accessibility label above.
  private var detailText: String {
    let time = drink.loggedAt.formatted(date: .omitted, time: .shortened)
    if let counted = drink.countedDrinks {
      let count = LoggedDrink.displayOunces(counted)
      return counted == 1
        ? String(localized: "\(time) · counted as 1 drink")
        : String(localized: "\(time) · counted as \(count) drinks")
    }
    return String(
      localized: "\(time) · \(LoggedDrink.displayOunces(drink.volumeOunces))oz · \(LoggedDrink.displayPercent(drink.abvPercent))% ABV"
    )
  }
}

// MARK: - Undo

/// Transient "deleted, undo" affordance.
///
/// Deleting is itself something you can do by accident, and the whole point of
/// this feature is forgiving correction — so a delete is never final until this
/// disappears from view.
struct UndoDeleteBar: View {
  let drink: LoggedDrink
  var onUndo: () -> Void

  var body: some View {
    HStack(spacing: GlassTokens.Spacing.regular) {
      Text("Removed \(drink.type.displayName.lowercased())")
        .font(.subheadline)
        .foregroundStyle(.primary)
      Spacer()
      Button("Undo", action: onUndo)
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }
    .padding(.horizontal, GlassTokens.Spacing.cardPadding)
    .frame(height: 48)
    .glassSurface(cornerRadius: GlassTokens.Radius.control)
    .screenMargin()
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }
}
