import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0042's 2026-09-19 amendment, pinned: the watch counter's row fits every
/// case, both discs keep their 44, and on the cases the design was drawn for
/// every value is the drawn one.
@Suite("Watch counter row")
struct CounterRowTests {

  private struct Case {
    let name: String
    /// The screen's width in points.
    let screen: Double
    /// What the counter's view is given: the screen less what watchOS keeps
    /// clear of the glass on each side.
    var width: Double { screen - 2 * CounterRowTests.edgeInset }
  }

  /// What watchOS 26.5 keeps clear on each side before the app lays anything
  /// out, measured on every case below (2026-09-19): the full-width button
  /// under the row stands 10pt from the glass on a 46mm, inside an 8pt margin.
  private static let edgeInset = 2.0

  /// Every case watchOS 26 runs on, by its screen's width in points — read
  /// from each simulator's own screenshot (2026-09-19), not from memory, which
  /// had the Ultra 3 at the earlier Ultras' 205. The SE 2's two sizes and the
  /// Series 10's were read too and are the SE 3's and the Series 11's.
  private let cases: [Case] = [
    Case(name: "40mm", screen: 162),
    Case(name: "41mm", screen: 176),
    Case(name: "44mm", screen: 184),
    Case(name: "42mm", screen: 187),
    Case(name: "45mm", screen: 198),
    Case(name: "49mm Ultra 2", screen: 205),
    Case(name: "46mm", screen: 208),
    Case(name: "49mm Ultra 3", screen: 211),
  ]

  private func side(_ c: Case) -> Double {
    CounterRow.tileSide(forWidth: c.width, edgeInset: Self.edgeInset)
  }

  private func margin(_ c: Case) -> Double {
    CounterRow.margin(forWidth: c.width, edgeInset: Self.edgeInset)
  }

  private func rowWidth(tile: Double) -> Double {
    2 * CounterRow.discSide + 2 * CounterRow.gap + tile
  }

  @Test("Both discs are 44 on every case: the touch target is what never gives")
  func discsKeepTheirTarget() {
    #expect(CounterRow.discSide == 44)
    #expect(CounterRow.gap == 4)
  }

  @Test("What the drawn row did: 182pt is wider than a 40mm's screen, and a 41mm's")
  func whatTheDrawnRowDid() {
    #expect(CounterRow.drawnRowWidth == 182)
    // Off the glass by ten points a side on the 40mm and three on the 41mm —
    // rendered, 2026-09-18 — and a column is as wide as its widest child, so
    // the button and the copy beneath went with it. On the 44 and 42mm it
    // fitted the glass with a point and two and a half to spare.
    #expect((CounterRow.drawnRowWidth - 162) / 2 == 10)
    #expect((CounterRow.drawnRowWidth - 176) / 2 == 3)
    #expect((184 - CounterRow.drawnRowWidth) / 2 == 1)
    #expect((187 - CounterRow.drawnRowWidth) / 2 == 2.5)
  }

  @Test("The row and its margins fit every case's view, and stand a gap from the glass")
  func fitsEveryCase() {
    for c in cases {
      #expect(rowWidth(tile: side(c)) + 2 * margin(c) <= c.width, "\(c.name)")
      #expect(margin(c) + Self.edgeInset >= CounterRow.gap, "\(c.name)")
    }
  }

  @Test("The 45, 46 and 49mm are as drawn, to the point")
  func drawnWhereItFits() {
    for name in ["46mm", "49mm Ultra 2", "49mm Ultra 3"] {
      let c = cases.first { $0.name == name }!
      #expect(side(c) == 86, "\(name)")
      #expect(margin(c) == 8, "\(name)")
    }
    // The design's own canvas. Its 182pt row inside 8pt margins is the whole
    // 198pt screen, and the view is 194 — so the row always overflowed its
    // padding there by two points a side, which put it, and the column it
    // stretched, the drawn eight from the glass. The rule reaches the same
    // place on purpose: the six that is left, and the system's two. Rendered,
    // the 45mm is pixel-identical before and after.
    let drawnOn = cases.first { $0.name == "45mm" }!
    #expect(side(drawnOn) == 86)
    #expect(margin(drawnOn) == 6)
    #expect(margin(drawnOn) + Self.edgeInset == CounterRow.drawnMargin)

    #expect(CounterRow.cornerRadius(forSide: 86) == 25)
    #expect(CounterRow.numeralSize(forSide: 86) == 46)
    #expect(CounterRow.bareNumeralSize(forSide: 86) == 56)
    #expect(CounterRow.glyphSize(forSide: 86) == 34)
    #expect(CounterRow.hiddenBarWidth(forSide: 86) == 40)
    #expect(CounterRow.hiddenBarHeight(forSide: 86) == 8)
    #expect(CounterRow.hiddenBarRadius(forSide: 86) == 4)
  }

  @Test("The margins give first, until the row stands its own gap from the glass, and then the tile")
  func smallCases() {
    let expected: [(String, Double)] = [("40mm", 58), ("41mm", 72), ("44mm", 80), ("42mm", 83)]
    for (name, tile) in expected {
      let c = cases.first { $0.name == name }!
      #expect(side(c) == tile, "\(name)")
      #expect(margin(c) == 2, "\(name)")
      // Four points from the glass, the row's own gap: no tighter to the edge
      // than it is to itself.
      #expect(margin(c) + Self.edgeInset == CounterRow.gap, "\(name)")
      // Nothing to spare and nothing over.
      #expect(rowWidth(tile: tile) + 2 * margin(c) == c.width, "\(name)")
    }
  }

  @Test("With nothing kept clear by the system, the app keeps the whole gap itself")
  func noSystemInset() {
    #expect(CounterRow.margin(forWidth: 162) == 4)
    #expect(CounterRow.tileSide(forWidth: 162) == 58)
    // And where the system keeps more than a gap, the app adds nothing.
    #expect(CounterRow.margin(forWidth: 150, edgeInset: 6) == 0)
    #expect(CounterRow.tileSide(forWidth: 150, edgeInset: 6) == 54)
    // A nonsense inset is no inset.
    #expect(CounterRow.margin(forWidth: 162, edgeInset: -3) == 4)
    #expect(CounterRow.margin(forWidth: 162, edgeInset: .nan) == 4)
  }

  @Test("Inside the tile, the design's two ratios: corner 36 and numeral 68 on the phone's 126")
  func ratios() {
    // side → corner, numeral, bare numeral, glyph, bar width, bar height
    let expected: [(Double, Double, Double, Double, Double, Double, Double)] = [
      (58, 17, 31, 38, 23, 27, 5.5),
      (72, 21, 39, 47, 28, 33.5, 6.5),
      (80, 23, 43, 52, 32, 37, 7.5),
      (83, 24, 45, 54, 33, 38.5, 7.5),
      (86, 25, 46, 56, 34, 40, 8),
    ]
    for (side, corner, numeral, bare, glyph, barWidth, barHeight) in expected {
      #expect(CounterRow.cornerRadius(forSide: side) == corner, "corner at \(side)")
      #expect(CounterRow.numeralSize(forSide: side) == numeral, "numeral at \(side)")
      #expect(CounterRow.bareNumeralSize(forSide: side) == bare, "bare numeral at \(side)")
      #expect(CounterRow.glyphSize(forSide: side) == glyph, "glyph at \(side)")
      #expect(CounterRow.hiddenBarWidth(forSide: side) == barWidth, "bar width at \(side)")
      #expect(CounterRow.hiddenBarHeight(forSide: side) == barHeight, "bar height at \(side)")
    }
  }

  @Test("On the narrowest case the count is still the largest thing on the screen, and the tile a target")
  func narrowestCase() {
    let tile = side(cases[0])
    // The tile is tapped to hide the count: over the 44pt floor with room.
    #expect(tile >= 44 + 12)
    // The unit word beneath it is 12pt.
    #expect(CounterRow.numeralSize(forSide: tile) >= 2.5 * 12)
    // The bare numeral and the bar stay inside the tile's frame.
    #expect(CounterRow.bareNumeralSize(forSide: tile) < tile)
    #expect(CounterRow.hiddenBarWidth(forSide: tile) < tile)
  }

  @Test("The tile only ever grows with the view, never past 86, and the row never overflows it")
  func sweep() {
    for inset in [0.0, 2, 4] {
      var width = 110.0
      var previous = 0.0
      while width <= 240 {
        let tile = CounterRow.tileSide(forWidth: width, edgeInset: inset)
        let margin = CounterRow.margin(forWidth: width, edgeInset: inset)
        #expect(tile >= previous, "\(width)")
        #expect(tile <= CounterRow.drawnTileSide, "\(width)")
        #expect(margin >= 0 && margin <= CounterRow.drawnMargin, "\(width)")
        #expect(rowWidth(tile: tile) + 2 * margin <= width, "\(width)")
        // Never a pixel wasted either: within half a point of the room there is.
        if tile < CounterRow.drawnTileSide {
          #expect(rowWidth(tile: tile) + 2 * margin > width - 0.5, "\(width)")
        }
        previous = tile
        width += 0.25
      }
    }
  }

  @Test("Between the two: a view that holds the drawn row with less than the drawn margin keeps the tile")
  func marginGivesBeforeTheTile() {
    #expect(CounterRow.tileSide(forWidth: 194, edgeInset: 2) == 86)
    #expect(CounterRow.margin(forWidth: 194, edgeInset: 2) == 6)
    #expect(CounterRow.tileSide(forWidth: 186, edgeInset: 2) == 86)
    #expect(CounterRow.margin(forWidth: 186, edgeInset: 2) == 2)
    #expect(CounterRow.tileSide(forWidth: 185, edgeInset: 2) == 85)
  }

  @Test("A width that is not a whole point floors the tile to the half point, a pixel")
  func halfPoint() {
    #expect(CounterRow.tileSide(forWidth: 172.3, edgeInset: 2) == 72)
    #expect(CounterRow.tileSide(forWidth: 172.7, edgeInset: 2) == 72.5)
  }

  @Test("Nothing to measure draws the row as drawn")
  func noWidth() {
    for width in [0.0, -162, .nan, .infinity] {
      #expect(CounterRow.tileSide(forWidth: width, edgeInset: 2) == 86)
      #expect(CounterRow.margin(forWidth: width, edgeInset: 2) == 8)
    }
  }
}
