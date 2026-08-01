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
      Image(systemName: drink.type.symbolName)
        .font(.body)
        .foregroundStyle(Color.accentColor)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(drink.type.displayName)
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
    .accessibilityLabel(accessibilityDescription)
  }

  private var detail: String {
    let time = drink.loggedAt.formatted(date: .omitted, time: .shortened)
    return "\(time) · \(LoggedDrink.displayOunces(drink.volumeOunces))oz · \(LoggedDrink.displayPercent(drink.abvPercent))% ABV"
  }

  private var accessibilityDescription: String {
    let count = StandardDrink.formatted(drink.standardDrinks(in: region))
    let noun = drink.standardDrinks(in: region) == 1 ? region.unitName : region.unitName + "s"
    return "\(drink.type.displayName), \(detail), \(count) \(noun)"
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
