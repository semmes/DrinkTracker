import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0046's second amendment of 2026-09-18, pinned: the rectangular card's
/// row keeps the 46mm exactly as it was, and on every narrower card gives the
/// words a column their longest word fits.
///
/// Most of these contexts cannot be rendered — a simulator's Smart Stack opens
/// only under a hand — so this table is what stands in for a render of them.
@Suite("Complication card row")
struct ComplicationCardTests {

  private struct Context {
    let name: String
    let width: Double
    let height: Double
  }

  /// What the system gives the rectangular family on every case size: the
  /// family's size less its safe-area insets, read from chronod's own host
  /// metrics on watchOS 26.5 simulators (2026-09-18) — the face's host and
  /// the Smart Stack's. A logging build measured the two face rows it could
  /// reach, 150 × 57 and 181 × 65.5, and they agree with the metrics exactly.
  private let contexts: [Context] = [
    Context(name: "40mm face", width: 150, height: 57),
    Context(name: "40mm Smart Stack", width: 138, height: 55.5),
    Context(name: "41mm face", width: 158.5, height: 60),
    Context(name: "41mm Smart Stack", width: 151, height: 55.5),
    Context(name: "42mm face", width: 163, height: 59.5),
    Context(name: "42mm Smart Stack", width: 162, height: 55.5),
    Context(name: "44mm face", width: 171, height: 65),
    Context(name: "44mm Smart Stack", width: 158, height: 58.5),
    Context(name: "45mm face", width: 179, height: 68),
    Context(name: "45mm Smart Stack", width: 165, height: 58.5),
    Context(name: "46mm face", width: 181, height: 65.5),
    Context(name: "46mm Smart Stack", width: 175, height: 58.5),
    Context(name: "49mm face", width: 184, height: 69.5),
    Context(name: "49mm Smart Stack", width: 176, height: 60),
  ]

  private var wide: [Context] { contexts.filter { !ComplicationCard.isNarrow(contentWidth: $0.width) } }
  private var narrow: [Context] { contexts.filter { ComplicationCard.isNarrow(contentWidth: $0.width) } }

  // The words at the card's 11pt, as ink measured from renders (2026-09-18)
  // and rounded up to the half point. English, the one language the card
  // ships in; a translation re-measures these.

  /// "drinks today" on one line: 58.0 on the 46mm.
  private let unitWordsOnOneLine = 58.0
  /// "drinks", the longer of the two unit words: 28.5.
  private let longestUnitWord = 28.5
  /// "Recorded", the longest word of the no-alcohol sentence and the one
  /// thing on the card that cannot wrap: 45.0 on the 40mm once it had the
  /// room (35.5 at the floor before, cut short beneath it).
  private let longestMarkerWord = 45.0
  /// "Recorded as no", the longer line of the sentence's two-line break: 67.5
  /// at the 0.93 the 46mm draws it, so 72.4 at full size.
  private let markerTwoLineBreak = 72.5

  @Test("The tile and the ＋ keep their 44 on every card")
  func touchTargetsHold() {
    #expect(ComplicationCard.plusSide == 44)
    #expect(ComplicationTile.cardSide == 44)
  }

  @Test("The 46mm is wide in both of its contexts, with the 45mm's face and the 49mm")
  func wideContexts() {
    #expect(wide.map(\.name) == [
      "45mm face", "46mm face", "46mm Smart Stack", "49mm face", "49mm Smart Stack",
    ])
  }

  @Test("A wide card is the row it always was: three gaps of 8, one line, two for the sentence")
  func wideRowIsUnchanged() {
    #expect(ComplicationCard.gap == 8)
    #expect(ComplicationCard.minimumScale == 0.8)
    for context in wide {
      #expect(ComplicationCard.wordsColumn(forContentWidth: context.width) == context.width - 112, "\(context.name)")
    }
    #expect(ComplicationCard.wordsColumn(forContentWidth: 181) == 69)
    #expect(ComplicationCard.wordsColumn(forContentWidth: 175) == 63)
    #expect(ComplicationCard.lineLimit(isMarker: false, isNarrow: false) == 1)
    #expect(ComplicationCard.lineLimit(isMarker: true, isNarrow: false) == 2)
  }

  @Test("Every wide card holds the unit words on one line at full size, and the sentence on two above the floor")
  func wideRowFits() {
    for context in wide {
      let column = ComplicationCard.wordsColumn(forContentWidth: context.width)
      #expect(column >= unitWordsOnOneLine, "\(context.name) leaves \(column)")
      #expect(column >= markerTwoLineBreak * ComplicationCard.minimumScale, "\(context.name) leaves \(column)")
    }
  }

  @Test("What the old row did: the unit words cut short on the 40mm and in two more Smart Stacks")
  func whatTheOldRowDid() {
    // One line of "drinks today" at the 0.8 floor is 46.4pt of ink. The old
    // column — the wide one — is under that on the 40mm (rendered: "drinks
    // t…") and in the 41mm's and 44mm's Smart Stacks, and a tenth of a point
    // over it on the 41mm's face. The other narrow cards shrank the words
    // without cutting them.
    let floor = unitWordsOnOneLine * ComplicationCard.minimumScale
    let truncated = narrow.filter { ComplicationCard.wideColumn(forContentWidth: $0.width) < floor }
    #expect(truncated.map(\.name) == [
      "40mm face", "40mm Smart Stack", "41mm Smart Stack", "44mm Smart Stack",
    ])
    #expect(ComplicationCard.wideColumn(forContentWidth: 150) == 38)
    #expect(ComplicationCard.wideColumn(forContentWidth: 138) == 26)
  }

  @Test("Narrow, the words take everything between the tile and the ＋: two gaps of 4")
  func narrowRow() {
    #expect(ComplicationCard.narrowGap == 4)
    for context in narrow {
      #expect(ComplicationCard.wordsColumn(forContentWidth: context.width) == context.width - 96, "\(context.name)")
    }
    #expect(ComplicationCard.wordsColumn(forContentWidth: 150) == 54)
    #expect(ComplicationCard.wordsColumn(forContentWidth: 138) == 42)
    #expect(ComplicationCard.lineLimit(isMarker: false, isNarrow: true) == 2)
    #expect(ComplicationCard.lineLimit(isMarker: true, isNarrow: true) == 4)
  }

  @Test("Every narrow card holds \"drinks\" at full size, and \"Recorded\" within a tenth of it")
  func narrowRowFits() {
    for context in narrow {
      let column = ComplicationCard.wordsColumn(forContentWidth: context.width)
      #expect(column >= longestUnitWord, "\(context.name) leaves \(column)")
      // Well clear of the 0.8 floor, not on it: where the column held the
      // word only at the floor, a dots row under it cut the sentence short.
      #expect(column >= longestMarkerWord * 0.9, "\(context.name) leaves \(column)")
    }
  }

  @Test("Only the 40mm shrinks the sentence at all, and only in its Smart Stack")
  func whereTheSentenceShrinks() {
    let shrunk = narrow.filter { ComplicationCard.wordsColumn(forContentWidth: $0.width) < longestMarkerWord }
    #expect(shrunk.map(\.name) == ["40mm Smart Stack"])
  }

  @Test("Where the narrow row brings the unit words back onto one line at full size")
  func oneLineAgain() {
    // Six of the nine narrow cards. The old row shrank the words there, or
    // cut them short; the 40mm's two cards and the 41mm's Smart Stack take
    // the second line instead.
    let oneLine = narrow.filter { ComplicationCard.wordsColumn(forContentWidth: $0.width) >= unitWordsOnOneLine + 1 }
    #expect(oneLine.map(\.name) == [
      "41mm face", "42mm face", "42mm Smart Stack", "44mm face", "44mm Smart Stack", "45mm Smart Stack",
    ])
  }

  @Test("Why the narrow gap is the counter's 4: what 8 and 6 leave \"Recorded\" in the 40mm Smart Stack")
  func whyTheGapTightens() {
    func column(atGap gap: Double) -> Double {
      138 - ComplicationTile.cardSide - ComplicationCard.plusSide - 2 * gap
    }
    // At 8 the word cannot be held even at the floor.
    #expect(column(atGap: 8) == 34)
    #expect(column(atGap: 8) < longestMarkerWord * ComplicationCard.minimumScale)
    // At 6 it can, with nothing to spare: rendered at 0.81, and cut short
    // beside a dots row (emulated on a face, 2026-09-18).
    #expect(column(atGap: 6) == 38)
    #expect(column(atGap: 6) < longestMarkerWord * 0.9)
    // At 4 it draws at 0.90, whole in both.
    #expect(column(atGap: ComplicationCard.narrowGap) == 42)
    #expect(column(atGap: ComplicationCard.narrowGap) >= longestMarkerWord * 0.9)
  }

  @Test("One threshold: narrow below 172pt of content, wide from there")
  func threshold() {
    var width = 100.0
    while width <= 220 {
      #expect(ComplicationCard.isNarrow(contentWidth: width) == (width < 172), "\(width)")
      width += 0.25
    }
    // The 46mm's stack is three points over it. The card a point under it is
    // the 44mm's face, the one card where either row holds the words — the
    // old row left it 59pt — so it is the right card to have beside the line.
    #expect(narrow.map(\.width).max() == 171)
    #expect(wide.map(\.width).min() == 175)
    #expect(ComplicationCard.wideColumn(forContentWidth: 171) >= unitWordsOnOneLine)
    #expect(ComplicationCard.wideColumn(forContentWidth: 171) >= markerTwoLineBreak * ComplicationCard.minimumScale)
  }

  @Test("The narrow row never leaves the words less than the wide one would")
  func narrowIsNeverTighter() {
    var width = 100.0
    while width < 172 {
      // One gap fewer, and the two that remain half as wide: 24 becomes 8.
      #expect(
        ComplicationCard.wordsColumn(forContentWidth: width)
          == ComplicationCard.wideColumn(forContentWidth: width) + 16
      )
      width += 0.5
    }
  }

  @Test("Nothing to measure draws the row as it always was")
  func noWidth() {
    #expect(!ComplicationCard.isNarrow(contentWidth: 0))
    #expect(!ComplicationCard.isNarrow(contentWidth: -150))
    #expect(!ComplicationCard.isNarrow(contentWidth: .nan))
    #expect(!ComplicationCard.isNarrow(contentWidth: .infinity))
  }
}
