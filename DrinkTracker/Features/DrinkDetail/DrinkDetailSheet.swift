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
      Text(draft.type.displayName)
        .font(GlassTokens.Typography.sheetTitle)
        .foregroundStyle(.primary)
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
    if showsTimeControl {
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
    .frame(height: GlassTokens.Layout.minimumTouchTarget)
    .glassSurface(cornerRadius: GlassTokens.Radius.control)
    .transition(.opacity.combined(with: .move(edge: .top)))
    .animation(.smooth(duration: 0.25), value: draft.selectedSize)
  }

  // MARK: - ABV

  /// Collapsed by default. The row reads as a value, not an empty control, so
  /// the default is visible without the slider taking up space.
  private var abvSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      Button {
        withAnimation(.smooth(duration: 0.25)) {
          draft.isABVExpanded.toggle()
        }
      } label: {
        HStack {
          Text("ABV: \(LoggedDrink.displayPercent(draft.abvPercent))%")
            .font(.body)
            .foregroundStyle(.primary)
          Spacer()
          Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(draft.isABVExpanded ? 180 : 0))
        }
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(height: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
      .accessibilityLabel("Alcohol by volume, \(LoggedDrink.displayPercent(draft.abvPercent)) percent")
      .accessibilityHint(draft.isABVExpanded ? "Collapses the slider" : "Expands a slider to adjust")

      if draft.isABVExpanded {
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
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
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

  /// Updates on any size or ABV change. Approximate by design — the "≈" is
  /// doing real work here, since ABV is almost always an estimate.
  private var liveEstimate: some View {
    Text(StandardDrink.liveEstimate(currentCount, region: settings.effectiveRegion))
      .font(GlassTokens.Typography.cardValue)
      .foregroundStyle(.primary)
      .contentTransition(.numericText(value: currentCount))
      .animation(.snappy, value: currentCount)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityLabel(
        "Approximately \(StandardDrink.formatted(currentCount)) \(settings.effectiveRegion.unitName)s"
      )
  }

  private var currentCount: Double {
    draft.standardDrinks(region: settings.effectiveRegion)
  }

  // MARK: - Logging

  private var canLog: Bool { draft.volumeOunces > 0 }

  private var logButtonTitle: String {
    draft.editingEntryID == nil ? "Log drink" : "Save changes"
  }

  private func logDrink() {
    isSaving = true
    let drink = draft.makeLoggedDrink(region: settings.effectiveRegion)
    let store = DrinkStore(context: context, health: health)
    Task {
      let saved = await store.save(drink)
      isSaving = false
      onLogged(saved)
    }
  }
}

// MARK: - Pieces

private struct SectionLabel: View {
  let text: String

  init(_ text: String) { self.text = text }

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
        .frame(height: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .background {
      if isSelected {
        Capsule().fill(Color.accentColor)
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
