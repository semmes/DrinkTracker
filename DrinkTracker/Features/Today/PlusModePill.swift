import DrinkTrackerCore
import SwiftUI

/// What ＋ logs, and the one tap that changes it (ADR-0034; ADR-0023's
/// revision, amended).
///
/// Two segments: a plain standard drink, and the drink the day is currently
/// following. The highlighted one is what ＋ would log right now, and the
/// caption underneath states it in words.
///
/// **Neither segment stores a mode.** Tapping one logs that drink immediately,
/// and the selection is *derived* from `DrinkDraft.dayTemplate` — the day's own
/// most recent repeatable entry. That is the whole mechanism, and it is what
/// keeps three separate promises without any code to enforce them: midnight
/// resets it, deleting the drink undoes it, and the widget's ＋
/// (`LogOneDrinkIntent`) stays in lockstep because there is no app-local state
/// for it to be out of step with (PRD invariant 1). A stored mode would fail
/// silently and late — as "the widget logged a beer when the app said standard
/// drink", days afterwards, on a device.
///
/// So the pill is not a mode switch drawn as one; it is the two log actions
/// this screen already had — ADR-0023's "Record a standard drink instead" and
/// ADR-0001's repeat — put side by side with the current one marked.
struct PlusModePill: View {
  /// The typed drink the day is following. Non-nil is the whole condition for
  /// showing this control.
  let template: LoggedDrink
  /// The drink ＋ would log right now, for the caption.
  let seed: LoggedDrink
  var onRecordStandardDrink: () -> Void
  var onRepeatTemplate: () -> Void

  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      if typeSize.isAccessibilitySize {
        // At accessibility sizes two capsules side by side truncate to
        // initials. Stacked full-width rows are the shape Settings' region
        // picker already uses for the same problem (ADR-0026 names this
        // fold as a fix, not a redesign).
        VStack(spacing: GlassTokens.Spacing.tight) {
          standardSegment
          typedSegment
        }
      } else {
        HStack(spacing: 3) {
          standardSegment
          typedSegment
        }
        .padding(3)
        // `tertiarySystemFill`, not `.quaternary`: the bare hierarchical style
        // resolves against *content*, which paints a mid-grey track rather than
        // the faint groove a segmented control sits in. This is the system fill
        // whose alpha (0.12) the drawing specifies outright.
        .background(Capsule().fill(Color(.tertiarySystemFill)))
      }

      CounterSeedCaption(seed: seed)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var standardSegment: some View {
    segment(
      isSelected: false,
      symbol: DrinkType.unspecified.symbolName,
      label: Text("Standard drink"),
      action: onRecordStandardDrink
    )
  }

  private var typedSegment: some View {
    segment(
      isSelected: true,
      symbol: template.type.symbolName,
      // The type's own name, already localized by the package — a key here
      // would be "%@" and nothing else.
      label: Text(verbatim: template.type.displayName),
      action: onRepeatTemplate
    )
  }

  private func segment(
    isSelected: Bool,
    symbol: String,
    label: Text,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: symbol)
          .font(.caption)
          .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
        label
          .font(.subheadline.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(.primary)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.85)
      .padding(.horizontal, 15)
      // minHeight, never height: a fixed control height under Dynamic Type is
      // exactly the fault that disqualified SUSegmentedControl (ADR-0026).
      .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil, minHeight: 32)
      // Drawn at 32pt...
      .background {
        if isSelected {
          Capsule().fill(Color(.systemBackground))
        }
      }
      // ...and tappable at 44. Both inside the label, because a Button's
      // gesture is attached to its label — a frame applied to the Button grows
      // the layout without growing the target.
      .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil,
             minHeight: GlassTokens.Layout.minimumTouchTarget)
      .contentShape(.capsule)
    }
    .buttonStyle(.plain)
    // A real Button, not an onTapGesture on a styled shape: SUCard's tap
    // gesture never fires and SUSegmentedControl has no button trait for
    // VoiceOver — both recorded gotchas, both the same lesson.
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    // Both segments write. The selected trait says which drink ＋ is following;
    // without this, activating either one reads as merely picking a mode —
    // which is exactly the thing this control is not (ADR-0023's amendment).
    .accessibilityHint("Logs one now")
  }
}
