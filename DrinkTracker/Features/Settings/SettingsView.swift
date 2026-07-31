import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Settings. Currently one real setting — the region — plus Health status.
///
/// The region picked during onboarding persists here and can be changed at any
/// time, which is what the onboarding copy ("you can set this later") promises.
struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: GlassTokens.Spacing.section) {
          regionSection
          healthSection
          aboutSection
        }
        .screenMargin()
        .padding(.vertical, GlassTokens.Spacing.section)
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  // MARK: - Region

  private var regionSection: some View {
    SettingsSection(
      title: "Standard drink size",
      footnote: regionFootnote
    ) {
      VStack(spacing: GlassTokens.Spacing.tight) {
        ForEach(Region.allCases) { region in
          RegionRow(
            region: region,
            isSelected: settings.region == region
          ) {
            withAnimation(.snappy) { settings.region = region }
          }
        }
      }
    }
  }

  private var regionFootnote: String {
    if settings.isUsingFallbackRegion {
      return "You skipped this during setup, so totals currently use the US definition. Pick one to change it."
    }
    return "This is the unit your totals are shown in. Changing it re-expresses everything, including past days — what you drank doesn't change, only how it's counted."
  }

  // MARK: - Health

  private var healthSection: some View {
    SettingsSection(title: "Apple Health", footnote: healthFootnote) {
      HStack {
        Label {
          Text(healthStatusText)
            .font(.body)
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: healthStatusSymbol)
            .foregroundStyle(healthStatusColor)
        }
        Spacer()
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
      .glassSurface(cornerRadius: GlassTokens.Radius.control)
    }
  }

  private var healthStatusText: String {
    switch health.authorization {
    case .authorized: "Saving to Health"
    case .denied: "Not saving to Health"
    case .notDetermined: "Not set up"
    case .unavailable: "Health unavailable on this device"
    }
  }

  private var healthStatusSymbol: String {
    switch health.authorization {
    case .authorized: "checkmark.circle.fill"
    case .denied, .notDetermined: "circle.dashed"
    case .unavailable: "xmark.circle"
    }
  }

  private var healthStatusColor: Color {
    health.authorization == .authorized ? .accentColor : .secondary
  }

  private var healthFootnote: String {
    switch health.authorization {
    case .authorized:
      "Your log is written to Health as alcoholic beverages. Change access in the Health app under Sharing."
    case .denied, .notDetermined:
      "Your log is kept in the app either way. Turn access on in the Health app under Sharing if you want it in Health too."
    case .unavailable:
      "Your log is kept in the app."
    }
  }

  // MARK: - About

  private var aboutSection: some View {
    SettingsSection(title: "About", footnote: nil) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        Text("Drink Tracker keeps a record of what you drink so you can see your own pattern. It doesn't set goals, keep streaks, or offer advice.")
          .font(GlassTokens.Typography.supporting)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(GlassTokens.Spacing.cardPadding)
      .glassSurface(cornerRadius: GlassTokens.Radius.control)
    }
  }
}

// MARK: - Pieces

private struct SettingsSection<Content: View>: View {
  let title: String
  let footnote: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      Text(title)
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      content

      if let footnote {
        Text(footnote)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct RegionRow: View {
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

  /// Naming the actual size keeps the choice concrete, and shows the swap is real:
  /// a 16 oz 5% beer is 1.3 US standard drinks but 2.3 UK units.
  private var subtitle: String {
    let grams = region.gramsPureAlcoholPerStandardDrink
    let examplePint = StandardDrink.count(volumeOunces: 16, abvPercent: 5, region: region)
    return "One \(region.unitName) = \(String(format: "%.0f", grams))g · a 16oz 5% beer is \(StandardDrink.formatted(examplePint))"
  }
}
