import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// The drink-detail bottom sheet.
///
/// Presented as a native sheet over Today rather than a full-screen push, and
/// loggable the instant it opens — every control below the title is optional
/// refinement, never a gate. That is what keeps the fast path at two taps.
struct DrinkDetailSheet: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.modelContext) private var context

  @State private var draft: DrinkDraft
  @State private var customVolumeText: String
  @State private var isSaving = false
  @FocusState private var isCustomVolumeFocused: Bool

  private let onLogged: (LoggedDrink) -> Void
  private let onCancel: () -> Void
  /// Whether to offer a time picker.
  ///
  /// Off for the quick-add path, which must stay at two taps — the time is simply
  /// "now". On when editing an entry or adding one you forgot, where the whole
  /// point is that it didn't happen just now.
  private let showsTimeControl: Bool
  /// Set when this presentation adopts an imported Health drink (ADR-0016):
  /// the entry whose typed-in facts the sheet is collecting.
  private let adopting: LoggedDrink?

  init(
    draft: DrinkDraft,
    showsTimeControl: Bool = false,
    onLogged: @escaping (LoggedDrink) -> Void,
    onCancel: @escaping () -> Void
  ) {
    _draft = State(initialValue: draft)
    _customVolumeText = State(
      initialValue: LoggedDrink.displayOunces(draft.customVolumeOunces)
    )
    // Editing an existing entry always exposes the time, however it was opened.
    self.showsTimeControl = showsTimeControl || draft.editingEntryID != nil
    self.adopting = nil
    self.onLogged = onLogged
    self.onCancel = onCancel
  }

  /// Adoption: collect a type, size, and strength for an imported drink.
  ///
  /// The draft seeds from beer's defaults — the import's zeros are the absence
  /// of facts, not facts to edit. No time control: the sample's timestamp is
  /// the one thing the import already knows, and adoption adds facts rather
  /// than revising them (change the time in the app that recorded it).
  init(
    adopting imported: LoggedDrink,
    onLogged: @escaping (LoggedDrink) -> Void,
    onCancel: @escaping () -> Void
  ) {
    let draft = DrinkDraft(type: .beer, loggedAt: imported.loggedAt)
    _draft = State(initialValue: draft)
    _customVolumeText = State(
      initialValue: LoggedDrink.displayOunces(draft.customVolumeOunces)
    )
    self.showsTimeControl = false
    self.adopting = imported
    self.onLogged = onLogged
    self.onCancel = onCancel
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
          typeSection
          sizeSection
          abvSection
          if showsTimeControl { timeSection }
        }
        .screenMargin()
        .padding(.top, GlassTokens.Spacing.regular)
      }
      .scrollBounceBehavior(.basedOnSize)

      // The estimate and the action stay pinned together outside the scroll
      // area. Expanding the ABV slider otherwise pushes the live figure under
      // the button — hiding the number exactly while the user is changing it.
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        liveEstimate
        SUButton(model: .primary(logButtonTitle, isEnabled: canLog && !isSaving)) {
          logDrink()
        }
      }
      .screenMargin()
      .padding(.top, GlassTokens.Spacing.regular)
      .padding(.bottom, GlassTokens.Spacing.section)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(GlassTokens.Radius.sheet)
    .presentationBackground(.regularMaterial)
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(draft.type.displayName)
          .font(GlassTokens.Typography.sheetTitle)
          .foregroundStyle(.primary)
        if let adopting {
          // Where this entry came from, and the one fact it already carries.
          Text("From Apple Health, \(adopting.loggedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Button(action: onCancel) {
        Image(systemName: "xmark")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 30, height: 30)
          .contentShape(.circle)
      }
      .buttonStyle(.plain)
      .glassSurface(cornerRadius: 15, interactive: true)
      .accessibilityLabel("Close")
    }
    .screenMargin()
    .padding(.top, GlassTokens.Spacing.section)
  }

  // MARK: - Type

  /// Only shown alongside the time control — in the quick-add path the type came
  /// from the button that opened the sheet, and a picker there would be a second
  /// way to do something already done.
  @ViewBuilder
  private var typeSection: some View {
    // Adoption must ask the type — the import doesn't know it.
    if showsTimeControl || adopting != nil {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        SectionLabel("Drink")
        Picker("Drink", selection: typeBinding) {
          ForEach(DrinkType.allCases) { type in
            Text(type.displayName).tag(type)
          }
        }
        .pickerStyle(.segmented)
      }
    }
  }

  /// Changing type resets size and ABV to that type's defaults, so the estimate
  /// never shows a wine volume at spirit strength.
  private var typeBinding: Binding<DrinkType> {
    Binding(
      get: { draft.type },
      set: { newType in
        withAnimation(.snappy) {
          draft.changeType(to: newType)
          customVolumeText = LoggedDrink.displayOunces(draft.customVolumeOunces)
        }
      }
    )
  }

  // MARK: - Time

  private var timeSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("When")
      DatePicker(
        "When",
        selection: $draft.loggedAt,
        // Future drinks aren't a thing worth supporting; everything else is open
        // so a forgotten night can still be recorded.
        in: ...Date(),
        displayedComponents: [.date, .hourAndMinute]
      )
      .labelsHidden()
      .datePickerStyle(.compact)
    }
  }

  // MARK: - Size

  private var sizeSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("Size")

      // Wrapping layout so a four-pill type (Beer, Spirit) doesn't squeeze
      // labels below legibility on narrower devices or at large Dynamic Type.
      FlowLayout(spacing: GlassTokens.Spacing.tight) {
        ForEach(draft.type.sizeOptions) { option in
          SizePill(
            label: option.label,
            isSelected: draft.selectedSize == option
          ) {
            draft.selectedSize = option
            if option.isCustom {
              isCustomVolumeFocused = true
            }
          }
        }
      }

      if draft.selectedSize.isCustom {
        customVolumeField
      }
    }
  }

  private var customVolumeField: some View {
    HStack(spacing: GlassTokens.Spacing.tight) {
      TextField("Ounces", text: $customVolumeText)
        .keyboardType(.decimalPad)
        .focused($isCustomVolumeFocused)
        .font(.body)
        .onChange(of: customVolumeText) { _, newValue in
          // An unparseable or empty field leaves the last good volume in place
          // rather than dropping the estimate to zero mid-typing.
          if let parsed = Double(newValue.replacingOccurrences(of: ",", with: ".")),
             parsed > 0 {
            draft.customVolumeOunces = parsed
          }
        }
      Text("oz")
        .font(.body)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, GlassTokens.Spacing.cardPadding)
    .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
    .glassSurface(cornerRadius: GlassTokens.Radius.control)
    .transition(.opacity.combined(with: .move(edge: .top)))
    .animation(.smooth(duration: 0.25), value: draft.selectedSize)
  }

  // MARK: - ABV

  /// Always visible. It was collapsed behind a disclosure row until the quantity
  /// section's removal freed the space — strength is the control this sheet
  /// exists for, and hiding it behind a tap was friction with no payoff left.
  private var abvSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      HStack {
        SectionLabel("Strength")
        Spacer()
        Text("\(LoggedDrink.displayPercent(draft.abvPercent))% ABV")
          .font(.body.weight(.medium))
          .foregroundStyle(.primary)
          .contentTransition(.numericText(value: draft.abvPercent))
          .animation(.snappy, value: draft.abvPercent)
      }

      VStack(spacing: GlassTokens.Spacing.tight) {
        SUSlider(
          currentValue: abvBinding,
          model: .abv(range: draft.type.abvRange)
        )
        .frame(height: 24)

        HStack {
          Text("\(LoggedDrink.displayPercent(draft.type.abvRange.lowerBound))%")
          Spacer()
          Text("\(LoggedDrink.displayPercent(draft.type.abvRange.upperBound))%")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      .padding(.horizontal, GlassTokens.Spacing.tight)
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Alcohol by volume")
      .accessibilityValue("\(LoggedDrink.displayPercent(draft.abvPercent)) percent")
    }
  }

  /// ComponentsKit's slider works in `CGFloat`; the domain model uses `Double`.
  private var abvBinding: Binding<CGFloat> {
    Binding(
      get: { CGFloat(draft.abvPercent) },
      set: { draft.abvPercent = Double($0) }
    )
  }

  // MARK: - Live estimate

  /// Updates on any size or ABV change. Approximate by design — the "≈" is doing
  /// real work here, since ABV is almost always an estimate.
  private var liveEstimate: some View {
    Text(StandardDrink.liveEstimate(currentCount, region: settings.effectiveRegion))
      .font(GlassTokens.Typography.cardValue)
      .foregroundStyle(.primary)
      .contentTransition(.numericText(value: currentCount))
      .animation(.snappy, value: currentCount)
      .frame(maxWidth: .infinity, alignment: .leading)
      // Composed verbatim because the package already translated it. Built by
      // hand this label appended a literal "s" to a localized noun, so a French
      // build would have spoken the translated singular with an English plural
      // welded on.
      .accessibilityLabel(
        Text(verbatim: StandardDrink.accessibleEstimate(currentCount, region: settings.effectiveRegion))
      )
  }

  private var currentCount: Double {
    draft.standardDrinks(region: settings.effectiveRegion)
  }

  // MARK: - Logging

  private var canLog: Bool { draft.volumeOunces > 0 }

  private var logButtonTitle: String {
    if adopting != nil { return "Save details" }
    return draft.editingEntryID == nil ? "Log drink" : "Save changes"
  }

  private func logDrink() {
    isSaving = true
    let store = DrinkStore(context: context, health: health)

    // Adoption bypasses store.save on purpose: the entry's Health sample is
    // another app's, and must be neither retired nor duplicated (ADR-0016).
    if let adopting {
      let adopted = adopting.adopting(
        type: draft.type,
        volumeOunces: draft.volumeOunces,
        abvPercent: draft.abvPercent,
        region: settings.effectiveRegion
      )
      store.adopt(adopted)
      isSaving = false
      onLogged(adopted)
      return
    }

    let drinks = draft.makeLoggedDrinks(region: settings.effectiveRegion)
    Task {
      let saved = await store.save(drinks)
      isSaving = false
      if let saved { onLogged(saved) }
    }
  }
}

// MARK: - Pieces

/// Shared by the drink sheet and the calendar's day sheet, so the two read as the
/// same surface rather than two takes on one.
struct SectionLabel: View {
  /// A key rather than a `String`: `Text(String)` is the verbatim initializer,
  /// so typing this as `String` silenced every section heading in the app at
  /// once — including a singular/plural pair in the bulk-fill sheet.
  let text: LocalizedStringKey

  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(.footnote.weight(.medium))
      .foregroundStyle(.secondary)
      .textCase(.uppercase)
  }
}

private struct SizePill: View {
  let label: String
  let isSelected: Bool
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      Text(label)
        .font(.subheadline)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .background {
      if isSelected {
        // AccentFill, not accentColor: the asset accent is the TEXT pair
        // (500 light / 400 dark), and white on the dark 400 is only 3.64:1.
        // Fills are 500 in both modes — design review R2.
        Capsule().fill(Color("AccentFill"))
      }
    }
    .glassSurface(cornerRadius: GlassTokens.Radius.pill, interactive: !isSelected)
    .animation(.snappy(duration: 0.2), value: isSelected)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }
}

// MARK: - Display helpers

extension LoggedDrink {
  /// Shared number formatting so the sheet, the "last logged" line, and the
  /// trend screens all render the same value identically.
  static func displayOunces(_ value: Double) -> String {
    value == value.rounded()
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
  }

  static func displayPercent(_ value: Double) -> String {
    value == value.rounded()
      ? String(format: "%.0f", value)
      : String(format: "%.1f", value)
  }
}
