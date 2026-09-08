import DrinkTrackerCore
import SwiftUI

/// The drink sheet's type control: one segment per selectable type, each its
/// glyph over its name (ADR-0036).
///
/// Built from real Buttons in a track rather than a native segmented `Picker`,
/// for the reason `PlusModePill` gives and one more: `UISegmentedControl`
/// holds a title *or* an image per segment, never both, and the owner's
/// drawing stacks the glyph above the label. So the control is a row of
/// buttons that look like a segmented control, with the selection owned by
/// the sheet's binding — which is what resets size and strength on a change,
/// exactly as before.
///
/// Every segment stays for the whole presentation (`DrinkDetailSheet.asksType`);
/// this view never hides one. At accessibility sizes the row folds into the
/// region picker's rows — glyph, name, a check — because five stacked
/// glyph-over-label segments at those sizes truncate every label to a
/// syllable. The fold is at `isAccessibilitySize` by measurement, not habit:
/// "Cocktail" at caption2 semibold is 64.8pt at the largest non-accessibility
/// size against a 64.2pt segment on a 393pt screen, so it fits there only by
/// the 0.8 scale floor, and fails it one step up.
struct DrinkTypePicker: View {
  @Binding var selection: DrinkType
  let types: [DrinkType]

  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var highlight
  /// The glyph's slot. A symbol image lays out at its own drawn height, and
  /// the vessels differ in height by design (the shot glass is shorter than
  /// the mug), so without a fixed slot the labels beneath them sat at five
  /// different heights — measured on the first render. Scaled with the body
  /// text the glyph is set in.
  @ScaledMetric(relativeTo: .body) private var glyphSlot: CGFloat = 20

  init(selection: Binding<DrinkType>, types: [DrinkType] = DrinkType.selectableCases) {
    _selection = selection
    self.types = types
  }

  var body: some View {
    Group {
      if typeSize.isAccessibilitySize {
        VStack(spacing: GlassTokens.Spacing.tight) {
          ForEach(types) { type in
            row(type)
          }
        }
      } else {
        HStack(spacing: 2) {
          ForEach(types) { type in
            segment(type)
          }
        }
        .padding(2)
        // `tertiarySystemFill`, as the plus-mode pill: the system fill whose
        // alpha (0.12) the drawing specifies outright, and the groove a native
        // segmented control sits in.
        .background(
          RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(.tertiarySystemFill))
        )
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Drink")
  }

  /// Writes the binding only on a change. A native segmented control never
  /// re-selects the selected segment; these are plain Buttons, and an
  /// unconditional write would re-run the sheet's setter — which re-formats
  /// the Custom field from the draft, turning a half-typed "2." into "2"
  /// under the user's thumb.
  private func select(_ type: DrinkType) {
    guard selection != type else { return }
    selection = type
  }

  /// One segment of the row: the glyph over the name.
  private func segment(_ type: DrinkType) -> some View {
    let isSelected = selection == type
    return Button {
      select(type)
    } label: {
      VStack(spacing: 4) {
        glyph(type, isSelected: isSelected)
          .frame(height: glyphSlot)
        // The type's own name, already localized by the package — a key here
        // would be "%@" and nothing else.
        Text(verbatim: type.displayName)
          .font(.caption2.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(.primary)
          .lineLimit(1)
          // Five segments share the sheet's width; "Cocktail" at the larger
          // non-accessibility sizes shrinks a little rather than truncating
          // to "Cockt…", which would read as a different word.
          .minimumScaleFactor(0.8)
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 2)
      // Equal widths, and minHeight, never height: a fixed control height
      // under Dynamic Type is the fault that disqualified SUSegmentedControl
      // (ADR-0026). Measured at 68×49pt per segment at the default size.
      .frame(maxWidth: .infinity, minHeight: GlassTokens.Layout.minimumTouchTarget)
      .background {
        if isSelected {
          let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
          // The system background, as the plus-mode pill's selected segment:
          // the measured accent pair (5.26:1 light, 4.79:1 dark) holds on it,
          // and the drawing's dark tile (#1c1c1e) would take accent 400 to
          // 4.46:1. No shadow: depth is the material's (design-system §4).
          if reduceMotion {
            shape.fill(Color(.systemBackground))
          } else {
            // One highlight that slides between segments under the sheet's
            // `withAnimation`, the way a native control's does.
            shape.fill(Color(.systemBackground))
              .matchedGeometryEffect(id: "selection", in: highlight)
          }
        }
      }
      // Inside the label, so the target is the whole segment: a frame on the
      // Button itself grows the layout without growing the target.
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    // A real Button, not an onTapGesture on a styled shape (the SUCard and
    // SUSegmentedControl lessons, both recorded in CLAUDE.md).
    .accessibilityLabel(Text(verbatim: type.displayName))
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  /// The accessibility-size fold: the region picker's row, so the two folds
  /// in the app read as one pattern (ADR-0026 names it for exactly this).
  /// Interactive glass with nothing painted inside it — a filled tile inside
  /// glass is glass on glass, which the design system's composition rules
  /// forbid.
  private func row(_ type: DrinkType) -> some View {
    let isSelected = selection == type
    return Button {
      select(type)
    } label: {
      HStack(spacing: GlassTokens.Spacing.regular) {
        glyph(type, isSelected: isSelected)
        Text(verbatim: type.displayName)
          .font(.body.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(.primary)
        Spacer()
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(maxWidth: .infinity, minHeight: 60)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    .accessibilityLabel(Text(verbatim: type.displayName))
    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
  }

  /// The catalog glyph, never `systemName:`, and `decorative` because the name
  /// beside it is the label: a catalog `Image` otherwise speaks its asset
  /// name, and "tally dot cocktail" is not a word a reader chose. Accent when
  /// selected, the secondary label colour otherwise — the drawing's pairing.
  private func glyph(_ type: DrinkType, isSelected: Bool) -> some View {
    Image(decorative: type.symbolName)
      .font(.body)
      .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
  }
}
