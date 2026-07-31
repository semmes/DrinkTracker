import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Screen 3 — optional region setting. Skipping is a first-class option, not a
/// dismissal, so it gets its own control rather than a small "×".
struct RegionView: View {
  /// `nil` means the user skipped; the app falls back to the US definition.
  var onFinish: (Region?) -> Void

  @State private var selection: Region?

  var body: some View {
    OnboardingScaffold {
      OnboardingHeadline(text: "One quick setting")
      OnboardingSubtext(
        text: "This helps size a standard drink correctly for you. Skip if you're not sure, you can set this later."
      )
      VStack(spacing: GlassTokens.Spacing.tight) {
        ForEach(Region.allCases) { region in
          RegionOptionRow(
            region: region,
            isSelected: selection == region
          ) {
            selection = region
          }
        }
      }
      .padding(.top, GlassTokens.Spacing.regular)
    } actions: {
      SUButton(model: .primary("Continue")) { onFinish(selection) }
      SUButton(model: .subtle("Skip")) { onFinish(nil) }
    }
  }
}

private struct RegionOptionRow: View {
  let region: Region
  let isSelected: Bool
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(region.displayName)
            .font(.body)
            .foregroundStyle(.primary)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(minHeight: 60)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  /// Naming the actual size keeps the choice concrete rather than abstract.
  private var subtitle: String {
    let grams = region.gramsPureAlcoholPerStandardDrink
    return "One \(region.unitName) = \(String(format: "%.0f", grams))g of alcohol"
  }
}

#Preview {
  RegionView { _ in }
}
