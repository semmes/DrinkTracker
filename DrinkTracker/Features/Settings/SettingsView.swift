import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Settings: appearance, the region, sync and Health status, and export.
///
/// A page of its own in the tab bar since ADR-0040 — it was a sheet over Today
/// with a Done button — so it has no dismissal of its own, and the stack it
/// pushes the privacy policy and the tip jar onto belongs to `AppTabs`.
///
/// The region picked during onboarding persists here and can be changed at any
/// time, which is what the onboarding copy ("you can set this later") promises.
struct SettingsView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.modelContext) private var modelContext

  @AppStorage(AppearancePreference.storageKey)
  private var appearanceRaw = AppearancePreference.system.rawValue

  var body: some View {
    ScrollView {
      VStack(spacing: GlassTokens.Spacing.section) {
        appearanceSection
        counterSeedSection
        sessionPaceSection
        comparisonsSection
        regionSection
        iCloudSection
        healthSection
        exportSection
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
  }

  // MARK: - Appearance

  /// A display preference only (1.2 spec, Feature A). The widget deliberately
  /// keeps following the device — see `AppearancePreference`.
  private var appearanceSection: some View {
    SettingsSection(
      title: "Appearance",
      footnote: "The widget follows the device's appearance either way."
    ) {
      Picker("Appearance", selection: $appearanceRaw) {
        ForEach(AppearancePreference.allCases) { preference in
          Text(preference.label).tag(preference.rawValue)
        }
      }
      .pickerStyle(.segmented)
      .padding(GlassTokens.Spacing.tight)
      // interactive: the same rule as the toggle below — a control on
      // non-interactive glass can lose its taps.
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    }
  }

  // MARK: - What the counter logs

  /// The seed rule, as a setting rather than a decision taken for the user
  /// (ADR-0023). Defaults to the standard drink.
  ///
  /// A segmented picker rather than a toggle: neither answer is the "on"
  /// state, and a switch labelled "log a standard drink" would imply the
  /// other option is the absence of something. The footnote states what each
  /// one records, without recommending either.
  private var counterSeedSection: some View {
    SettingsSection(
      title: "What the counter logs",
      footnote: counterSeedFootnote
    ) {
      @Bindable var settings = settings
      Picker("What the counter logs", selection: $settings.counterSeed) {
        Text("Standard drink").tag(DrinkDraft.CountSeed.standardDrink)
        Text("My usual drink").tag(DrinkDraft.CountSeed.usualDrink)
      }
      .pickerStyle(.segmented)
      .padding(GlassTokens.Spacing.tight)
      // interactive: the same rule as the toggle below — a control on
      // non-interactive glass can lose its taps.
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    }
  }

  private var counterSeedFootnote: LocalizedStringKey {
    switch settings.counterSeed {
    case .standardDrink:
      return "One tap records one standard drink, with no type — add the type and size later or skip them, it counts either way. Once you describe a drink, the next taps record another of it for the rest of the day. Each day starts back at a standard drink."
    case .usualDrink:
      return "One tap records the type you log most, at the size and strength you last logged it. Tap the entry to change any of it."
    }
  }

  // MARK: - Session pace

  /// Off by default (1.2 spec: every new behavioral surface ships optional
  /// and off). The footnote is the whole sales pitch — a description, not an
  /// invitation (ADR-0017).
  private var sessionPaceSection: some View {
    SettingsSection(
      title: "Session pace",
      footnote: "Shows how many drinks you've logged in the current sitting."
    ) {
      @Bindable var settings = settings
      Toggle("Show session pace", isOn: $settings.showsSessionPace)
        .font(.body)
        .tint(Color("AccentFill"))
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        // interactive: a control on non-interactive glass loses taps (the
        // switch only answered drags in testing); every tappable control in
        // the app sits on interactive glass for this reason.
        .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    }
  }

  // MARK: - Comparisons

  /// Which of the published comparisons appear, and which of the survey's
  /// columns the weekly average is placed against (ADR-0038, ADR-0039).
  ///
  /// Three toggles, each naming its source. The weekly average's carries,
  /// inside its own card and only while it is on, the segmented picker for
  /// the column — under the switch it depends on, so the picker appearing and
  /// disappearing reads as that switch's own effect (owner's review,
  /// 2026-09-10; it had been a separate block after all three switches, which
  /// looked as if it governed all three). The picker's segments are the three
  /// columns the source prints and no more: a fourth that read the total under
  /// another name would be a question asked to no effect, so the default,
  /// "All adults", is what a reader who is neither of the other two, or who
  /// would rather not say, already has. Every control sits on interactive
  /// glass, the session-pace lesson.
  private var comparisonsSection: some View {
    SettingsSection(title: "Comparisons", footnote: comparisonsFootnote) {
      @Bindable var settings = settings
      VStack(spacing: GlassTokens.Spacing.tight) {
        ComparisonToggle(
          title: "Weekly average",
          source: "Alcohol Research Group, 2020 National Alcohol Survey",
          isOn: $settings.showsWeeklyAverageComparison
        ) {
          if settings.showsWeeklyAverageComparison {
            VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
              Divider()
              Text("Compare with")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
              Picker("Compare with", selection: $settings.comparisonColumn) {
                Text("All adults").tag(PopulationReference.Column.allAdults)
                Text("Men").tag(PopulationReference.Column.men)
                Text("Women").tag(PopulationReference.Column.women)
              }
              .pickerStyle(.segmented)
            }
            .padding(.horizontal, GlassTokens.Spacing.cardPadding)
            .padding(.bottom, GlassTokens.Spacing.regular)
            .transition(.opacity)
          }
        }
        ComparisonToggle(
          title: "Drinking days",
          source: "NIAAA, NESARC-III, 2012–13",
          isOn: $settings.showsDrinkingDaysComparison
        )
        ComparisonToggle(
          title: "Weekend and weekdays",
          source: "Liang and Chikritzhs, 2015 (NHANES 2005–10)",
          isOn: $settings.showsWeekendComparison
        )
      }
      .animation(.smooth(duration: 0.22), value: settings.showsWeeklyAverageComparison)
    }
  }

  /// One footnote for the section, in two forms: with the column picker on
  /// screen it says what the picker is and is not; without it, what turning
  /// a comparison off does. Neither recommends a setting.
  private var comparisonsFootnote: LocalizedStringKey {
    settings.showsWeeklyAverageComparison
      ? "Published US statistics your own figures are shown beside, each bundled with its source and year — never data from other Tallyist users, and nothing about your log leaves this device. The survey behind the weekly average prints its table for all adults, for men and for women; Compare with picks the column your average is placed against. It is a choice of reference, not a question about you, and it stays on this device. The other two figures are published for all adults only."
      : "Published US statistics your own figures are shown beside, each bundled with its source and year — never data from other Tallyist users, and nothing about your log leaves this device. A comparison that is off no longer appears on Trends or the year view."
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

  private var regionFootnote: LocalizedStringKey {
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

  private var iCloudStatusText: LocalizedStringKey {
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

  private var iCloudFootnote: LocalizedStringKey {
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

  private var healthStatusText: LocalizedStringKey {
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

  private var healthFootnote: LocalizedStringKey {
    switch health.authorization {
    case .authorized:
      "Your log is written to Health as alcoholic beverages, and what other apps record in Health appears here: their drinks, counted as logged, and a day they recorded as zero drinks, shown as no alcohol. Change access in the Health app under Sharing."
    case .denied, .notDetermined:
      "Your log is kept in the app either way. Turn access on in the Health app under Sharing to save to Health and to see what other apps have recorded there."
    case .unavailable:
      "Your log is kept in the app."
    }
  }

  // MARK: - Export

  /// The log as a file the user can hand to anyone — the natural answer to
  /// "show this to my doctor" (ADR-0015). A share sheet, so where it goes is
  /// entirely the user's choice; the app never sends anything anywhere.
  private var exportSection: some View {
    SettingsSection(
      title: "Export",
      // No per-type clause: since ADR-0037 a cocktail's two columns are the
      // whole drink's volume and its mixed strength, the same shape as every
      // other typed drink, so the sentence ADR-0035 added for the spirit-pour
      // model is gone again and the 2026-09-02 wording stands.
      footnote: "Saves your whole log as a CSV file spreadsheets can open — every drink, drinks counted from Apple Health, and the days recorded as no alcohol, here or in Apple Health. Totals are in your current unit. Size and strength are included for every drink you described; a standard drink logged without a type carries only its count."
    ) {
      ShareLink(
        item: LogExportFile(
          container: modelContext.container,
          region: settings.effectiveRegion,
          fileName: LogExportFile.defaultFileName()
        ),
        preview: SharePreview(LogExportFile.defaultFileName())
      ) {
        HStack {
          Label("Export log", systemImage: "square.and.arrow.up")
            .font(.body)
            .foregroundStyle(.primary)
          Spacer()
        }
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
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

  /// Plain `String` on purpose: the breadcrumb *values* are diagnostics, not
  /// product copy. The section's own title and footnote do go through the
  /// shared `SettingsSection`, so those two land in the catalog — a couple of
  /// keys a translator can skip, which beat a second verbatim code path.
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
        aboutLink("Privacy Policy", symbol: "hand.raised") { PrivacyPolicyView() }

        // The tip jar. Lives quietly at the bottom of Settings — support is
        // offered, never pushed (ADR-0012).
        aboutLink("Buy me a drink", symbol: "gift") { SupportView() }

        // Apple's standard EULA. Required to be reachable in-app once the app
        // sells auto-renewing subscriptions (guideline 3.1.2(a)); it also
        // appears beside the subscription controls themselves.
        Link(destination: SupportView.termsOfUseURL) {
          HStack {
            Label("Terms of Use", systemImage: "doc.text")
              .font(.body)
              .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
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

  private func aboutLink<Destination: View>(
    _ title: LocalizedStringKey,
    symbol: String,
    @ViewBuilder destination: @escaping () -> Destination
  ) -> some View {
    NavigationLink {
      destination()
    } label: {
      HStack {
        Label(title, systemImage: symbol)
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

// MARK: - Pieces

/// One published comparison's switch: its name over its source, and the
/// toggle. The source is the caption because the section's rule is that a
/// figure is never shown without saying where it came from, and that holds
/// for the switch that shows it.
///
/// A switch may carry a dependent control beneath it, inside the same glass —
/// the weekly average's "Compare with" picker (ADR-0039). One card rather than
/// a block of its own, because the control exists only while that switch is
/// on: placed under it, its appearing and disappearing reads as the switch's
/// own effect. The accessory is the caller's, including its `if`, so this view
/// never reads the setting it is bound to.
private struct ComparisonToggle<Accessory: View>: View {
  let title: LocalizedStringKey
  let source: LocalizedStringKey
  @Binding var isOn: Bool
  let accessory: Accessory

  init(
    title: LocalizedStringKey,
    source: LocalizedStringKey,
    isOn: Binding<Bool>,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.source = source
    self._isOn = isOn
    self.accessory = accessory()
  }

  var body: some View {
    VStack(spacing: 0) {
      Toggle(isOn: $isOn) {
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.body)
            .foregroundStyle(.primary)
          Text(source)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .tint(Color("AccentFill"))
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .padding(.vertical, GlassTokens.Spacing.tight)
      .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)

      accessory
    }
    // interactive: a control on non-interactive glass loses taps — the rule
    // every tappable control in the app follows.
    .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
  }
}

extension ComparisonToggle where Accessory == EmptyView {
  /// A switch with nothing beneath it — the shape two of the three take.
  init(title: LocalizedStringKey, source: LocalizedStringKey, isOn: Binding<Bool>) {
    self.init(title: title, source: source, isOn: isOn) { EmptyView() }
  }
}

private struct SettingsSection<Content: View>: View {
  // Keys, not Strings: a `String` here would reach `Text` through its verbatim
  // initializer and never appear in the catalog.
  let title: LocalizedStringKey
  let footnote: LocalizedStringKey?
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
  private var subtitle: LocalizedStringKey {
    let grams = region.gramsPureAlcoholPerStandardDrink
    let examplePint = StandardDrink.count(volumeOunces: 16, abvPercent: 5, region: region)
    return "One \(region.unitName) = \(String(format: "%.0f", grams))g · a 16oz 5% beer is \(StandardDrink.formatted(examplePint))"
  }
}
