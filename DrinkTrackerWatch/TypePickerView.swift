import DrinkTrackerCore
import SwiftUI

/// The watch's one screen beyond the counter (ADR-0042; the design's screen
/// 5): the five drink types as glyph over name, reached by holding ＋. A tap
/// logs that type at the type's defaults and returns. No size, no strength —
/// those are refinements, and refinements happen on the phone.
///
/// Iterates `DrinkType.selectableCases`, never `allCases`: `.unspecified` is
/// the absence of the question and no picker offers it (ADR-0023). The glyphs
/// are the shared catalog's symbols, loaded with `Image(decorative:)` — a
/// catalog image otherwise speaks its asset name to VoiceOver, and the name
/// beneath it is the label. The fifth tile sits under the fold; the crown
/// scrolls to it.
struct TypePickerView: View {
  let onPick: (DrinkType) -> Void

  private let columns = [
    GridItem(.flexible(), spacing: WatchLayout.pickerGap),
    GridItem(.flexible(), spacing: WatchLayout.pickerGap),
  ]

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: WatchLayout.pickerGap) {
        ForEach(DrinkType.selectableCases) { type in
          tile(type)
        }
      }
      .padding(.horizontal, WatchLayout.pickerMargin)
      .padding(.bottom, WatchLayout.pickerMargin)
    }
  }

  private func tile(_ type: DrinkType) -> some View {
    let shape = RoundedRectangle(cornerRadius: WatchLayout.pickerTileRadius, style: .continuous)
    return Button {
      onPick(type)
    } label: {
      VStack(spacing: WatchLayout.pickerGlyphToName) {
        Image(decorative: type.symbolName)
          .font(.system(size: WatchLayout.pickerGlyphSize))
          .foregroundStyle(Color.accentColor)
        Text(verbatim: type.displayName)
          .font(.system(size: WatchLayout.pickerNameSize))
          .foregroundStyle(.primary)
      }
      // The whole tile is the target, with the hit shape inside the label.
      .frame(maxWidth: .infinity, minHeight: WatchLayout.pickerTileHeight)
      .contentShape(shape)
    }
    .buttonStyle(.plain)
    .background(shape.fill(Color.primary.opacity(0.10)))
    .accessibilityLabel(Text(verbatim: type.displayName))
  }
}
