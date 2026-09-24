import DrinkTrackerCore
import SwiftUI

// The parts the Comparisons card's three segments share (ADR-0038's 2026-09-23
// amendment): the segment header, the row label, and the bar with its figure
// and its track. One copy of each, so the three segments cannot drift apart in
// size or ink.
//
// What every bar here obeys, and why:
//
// - **It shows a reviewed sentence's figure and says nothing the sentence does
//   not.** The sentences are what VoiceOver reads and what the accessibility
//   sizes show; the bars are how the default sizes show the same facts. The
//   lengths come from `ComparisonFigures` in the core package, which pins them
//   to the printed, rounded figures.
// - **A bar is its figure's share of its own days, over a track that is all of
//   them.** The track is the owner's ruling (2026-09-23): it shows where the
//   scale ends and how much of it a figure fills, drawn as the Trends chart's
//   selection rail draws its wash. The 1.4.3 copy review's second finding took
//   a progress bar off Trends' day count because a filled container has a full
//   state; what keeps these from being that bar is that no segment draws one
//   alone — the reader's figure and a published one share every track's scale.
// - **The reader's figure is the accent, a published figure is secondary
//   ink,** and each track is its own bar's ink as a wash. The accent already
//   marks the reader's own data on Trends — the chart's bars, and the rail
//   behind a touched one — so nothing new enters the palette (invariant 10),
//   and the distinction never rests on colour alone: every bar has its row
//   label, and the reader's numerals stay rounded where a published one stays
//   default SF.

/// The hairline between two segments. The source line above it is a 44pt row
/// with its text centred, so the gap above the rule is that row's own (14pt
/// under the text at the default size); the gap below is the card's inset, so
/// a segment reads as starting at its title. An open note keeps the same gap
/// through `SourceDisclosure.openNoteInset` — without it the note's last line
/// sat on the rule (the first render drew them touching).
struct SegmentDivider: View {
  /// What a closed source row leaves under its text at the default size,
  /// (44 − 16) / 2 — the gap an open note keeps above the rule.
  static let gapAbove: CGFloat = 14

  var body: some View {
    Divider()
      .padding(.bottom, GlassTokens.Spacing.cardPadding)
  }
}

/// A segment's header: its title — the Settings switch's words, or the card's
/// measure — and the span its figures cover. Side by side at the default
/// sizes; the span under the title where the card folds to sentences, so the
/// title is never squeezed to make room for it.
struct ComparisonSegmentHeader: View {
  let title: LocalizedStringKey
  let span: Text

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    if ComparisonTable.folds(dynamicTypeSize) {
      VStack(alignment: .leading, spacing: 2) {
        CardTitle(title)
        spanLabel
      }
    } else {
      HStack(alignment: .firstTextBaseline, spacing: GlassTokens.Spacing.tight) {
        CardTitle(title)
          .layoutPriority(1)
        Spacer(minLength: GlassTokens.Spacing.tight)
        spanLabel
      }
    }
  }

  private var spanLabel: some View {
    span
      .font(.caption)
      .foregroundStyle(.secondaryInk)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// Whose figure a row holds: "Your log", or the published population by its
/// own name. A fixed, scaled width shared by every segment, so the bars of the
/// drinking-days and weekend segments start on one edge; "US adults who drink"
/// breaks after "adults" onto a second line rather than taking the bars' room
/// (measured at the default size: "US adults" 65.9pt, "who drink" 66.9pt).
struct ComparisonRowLabel: View {
  /// The label column's width at the default size, scaled with subheadline by
  /// each segment's `@ScaledMetric` — one number, so the two segments that
  /// draw bars cannot put them on different edges.
  static let defaultWidth: CGFloat = 72

  let text: LocalizedStringKey
  let width: CGFloat

  init(_ text: LocalizedStringKey, width: CGFloat) {
    self.text = text
    self.width = width
  }

  var body: some View {
    Text(text)
      .font(.subheadline)
      .foregroundStyle(.primary)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: width, alignment: .leading)
  }
}

/// A figure over its bar. The figure is the text the row states; the bar is
/// that figure's share of its own days, from `ComparisonBars.share`, and
/// nothing else.
struct ComparisonBarCell<Figure: View>: View {
  /// 0 to 1 of the track, from `ComparisonBars.share`.
  let length: Double
  /// The reader's own figure takes the accent; a published one, secondary ink.
  let isReaders: Bool
  @ViewBuilder let figure: () -> Figure

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      figure()
      ComparisonBar(length: length, isReaders: isReaders)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The bar itself: a capsule over a track the full width of its column — all
/// of the figure's days — so the reader sees where the scale ends and how much
/// of it the figure fills (the owner's ruling, 2026-09-23). A figure of zero
/// draws the track alone, and a figure too small to see draws as a dot rather
/// than vanishing, since the figure above it is not zero.
struct ComparisonBar: View {
  let length: Double
  let isReaders: Bool

  @Environment(\.colorScheme) private var colorScheme

  static let thickness: CGFloat = 8

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(ink.opacity(trackOpacity))
        if length > 0 {
          Capsule(style: .continuous)
            .fill(ink)
            .frame(width: max(Self.thickness, geometry.size.width * min(1, length)))
        }
      }
    }
    .frame(height: Self.thickness)
    .accessibilityHidden(true)
  }

  private var ink: Color { isReaders ? .accentColor : .secondaryInk }

  /// The wash the Trends chart's selection rail draws behind a touched bar at
  /// its strongest — the owner's reference for this track — so the two read as
  /// one idiom: the bar's own ink, faint, over the whole of its scale.
  private var trackOpacity: Double { colorScheme == .dark ? 0.22 : 0.14 }
}

extension ComparisonTable {
  /// A column head set on the leading edge, for a column whose cells start
  /// there — the weekend segment's bars grow from the left. The same type,
  /// case, tracking and primary ink as `columnHead`.
  static func leadingColumnHead(_ text: Text) -> some View {
    text
      .font(GlassTokens.Typography.columnHead)
      .textCase(.uppercase)
      .tracking(0.6)
      .foregroundStyle(.primary)
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
