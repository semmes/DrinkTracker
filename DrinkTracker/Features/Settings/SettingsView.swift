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
          iCloudSection
          healthSection
          aboutSection
          if Diagnostics.isVisible {
            diagnosticsSection
          }
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

  // MARK: - iCloud

  /// Release-visible sync state — the answer to a question the diagnostics used
  /// to keep to themselves. Modeled on the Health row: an icon, a factual status,
  /// and a footnote saying what it means for the user's data. No alarm styling;
  /// the words carry it. The in-memory case is the one exception, because "nothing
  /// is being saved" is the single most important sentence this screen can say.
  private var iCloudSection: some View {
    SettingsSection(title: "iCloud", footnote: iCloudFootnote) {
      HStack {
        Label {
          Text(iCloudStatusText)
            .font(.body)
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: iCloudStatusSymbol)
            .foregroundStyle(iCloudStatusIsHealthy ? Color.accentColor : Color.secondary)
        }
        Spacer()
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
      .glassSurface(cornerRadius: GlassTokens.Radius.control)
    }
  }

  private var iCloudStatusIsHealthy: Bool {
    !Diagnostics.isStoreInMemory && Diagnostics.cloudKitStatusCode == "available"
  }

  private var iCloudStatusText: String {
    if Diagnostics.isStoreInMemory {
      return "Not saving — storage unavailable"
    }
    switch Diagnostics.cloudKitStatusCode {
    case "available": return "Syncing with iCloud"
    case "noAccount": return "Not syncing — no iCloud account"
    case "restricted": return "Not syncing — iCloud is restricted"
    case "temporarilyUnavailable": return "Sync temporarily unavailable"
    default: return "Sync status not checked yet"
    }
  }

  private var iCloudStatusSymbol: String {
    if Diagnostics.isStoreInMemory { return "exclamationmark.triangle" }
    switch Diagnostics.cloudKitStatusCode {
    case "available": return "checkmark.icloud"
    case "noAccount", "restricted": return "icloud.slash"
    default: return "icloud"
    }
  }

  private var iCloudFootnote: String {
    if Diagnostics.isStoreInMemory {
      return "The app couldn't open its storage, so drinks logged in this session won't be kept. Restarting the app usually resolves this."
    }
    switch Diagnostics.cloudKitStatusCode {
    case "available":
      return "Your log follows your iCloud account across your devices."
    case "noAccount":
      return "Your log is kept on this device. Sign into iCloud in the Settings app to sync it across devices."
    case "restricted":
      return "Your log is kept on this device. iCloud access is restricted on this device, for example by Screen Time or a device profile."
    case "temporarilyUnavailable":
      return "Your log is kept on this device and will sync when iCloud is available again."
    default:
      return "Your log is kept on this device either way."
    }
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

  // MARK: - Diagnostics

  /// Debug and TestFlight builds only — see `Diagnostics.isVisible`.
  ///
  /// Exists for one job: telling you why a widget tap did nothing. On a device you
  /// can't read the App Group's container, and the extension's console output is
  /// largely unreadable, so the breadcrumb it leaves is surfaced here instead.
  private var diagnosticsSection: some View {
    SettingsSection(
      title: "Diagnostics (test build)",
      footnote: "Tap the widget's log button, then come back here. \"never ran\" means the tap didn't reach the intent at all; anything starting \"failed\" means the write itself broke. Store mode is what was asked for when the store opened; iCloud sync is what actually happened, and they can disagree — a store opens fine with CloudKit requested and no iCloud account, then simply never syncs. \"IN MEMORY\" means nothing is being saved at all."
    ) {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
        diagnosticRow(
          "App Group",
          value: AppGroup.isAvailable ? "shared" : "UNAVAILABLE"
        )
        diagnosticRow("Group ID", value: AppGroup.identifier)
        diagnosticRow(
          "Store mode",
          value: Diagnostics.storeMode ?? "not opened yet"
        )
        diagnosticRow(
          "iCloud sync",
          value: Diagnostics.cloudKitStatus ?? "not checked yet"
        )
        diagnosticRow(
          "Intent last built by",
          value: Diagnostics.lastIntentBuild ?? "never built"
        )
        diagnosticRow(
          "Last widget tap",
          value: Diagnostics.lastWidgetLog ?? "never ran"
        )
      }
      .padding(GlassTokens.Spacing.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassSurface(cornerRadius: GlassTokens.Radius.control)
    }
  }

  private func diagnosticRow(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.monospaced())
        .foregroundStyle(.primary)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - About

  private var aboutSection: some View {
    SettingsSection(title: "About", footnote: nil) {
      VStack(spacing: GlassTokens.Spacing.tight) {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text("Tallyist keeps a record of what you drink so you can see your own pattern. It doesn't set goals, keep streaks, or offer advice.")
            .font(GlassTokens.Typography.supporting)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GlassTokens.Spacing.cardPadding)
        .glassSurface(cornerRadius: GlassTokens.Radius.control)

        // Guideline 5.1.1: the policy has to be reachable inside the app, not
        // only from the App Store listing. It's also simply owed to the user.
        NavigationLink {
          PrivacyPolicyView()
        } label: {
          HStack {
            Label("Privacy Policy", systemImage: "hand.raised")
              .font(.body)
              .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, GlassTokens.Spacing.cardPadding)
          .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
      }
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
