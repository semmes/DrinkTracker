import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0046's 2026-09-18 amendment, pinned: the circular complication draws
/// the rectangular card's tile at 0.83 of its slot, with the card's 13-on-44
/// corner, and at that share the system's circular mask never reaches a
/// corner.
@Suite("Complication tile geometry")
struct ComplicationTileTests {

  /// How far a square with circular-arc corners reaches from its centre: out
  /// along the diagonal to the arc's centre, then the radius.
  private func arcReach(side: Double) -> Double {
    let radius = ComplicationTile.cornerRadius(forSide: side)
    return (side / 2 - radius) * 2.0.squareRoot() + radius
  }

  /// SwiftUI's continuous corner reaches a little past the arc — 25.753
  /// against 25.728 at the card's 44 and 13, measured by flattening
  /// `RoundedRectangle(cornerRadius:style:).path(in:)` — so the mask is
  /// tested against the arc with that ratio added, rounded up.
  private let continuousOverArc = 1.001

  @Test("The card's tile keeps its own corner")
  func cardCorner() {
    #expect(ComplicationTile.cardSide == 44)
    #expect(ComplicationTile.cornerRadius(forSide: ComplicationTile.cardSide) == 13)
  }

  @Test("A smaller tile keeps the card's shape, not the card's radius")
  func cornerIsAProportion() {
    #expect(abs(ComplicationTile.cornerRadius(forSide: 42) - 12.409) < 0.001)
    #expect(abs(ComplicationTile.cornerRadius(forSide: 33) - 9.75) < 0.001)
    #expect(ComplicationTile.cornerRadius(forSide: 0) == 0)
  }

  @Test("The design's slot table: 0.83 of the diameter, floored to the half point")
  func slotTable() {
    #expect(ComplicationTile.slotShare == 0.83)
    #expect(ComplicationTile.side(forSlotDiameter: 51) == 42)
    #expect(ComplicationTile.side(forSlotDiameter: 47) == 39)
    #expect(ComplicationTile.side(forSlotDiameter: 44.5) == 36.5)
    #expect(ComplicationTile.side(forSlotDiameter: 42) == 34.5)
    #expect(ComplicationTile.side(forSlotDiameter: 40) == 33)
    // The two sizes the system asks for beside the faces' own, read from its
    // log on the 46mm and 40mm simulators (2026-09-18).
    #expect(ComplicationTile.side(forSlotDiameter: 46) == 38)
    #expect(ComplicationTile.side(forSlotDiameter: 37) == 30.5)
  }

  @Test("A share that lands exactly on a half point is not floored a pixel short")
  func exactHalfPoint() {
    // 50 × 0.83 is 41.5 exactly, and the nearest double to 0.83 is a hair
    // under it: the one slot in the table where a floor could lose a pixel to
    // binary error, pinned so a rewrite of the expression cannot.
    #expect(ComplicationTile.side(forSlotDiameter: 50) == 41.5)
    #expect(ComplicationTile.side(forSlotDiameter: 100) == 83)
  }

  @Test("Nothing to draw in no slot")
  func noSlot() {
    #expect(ComplicationTile.side(forSlotDiameter: 0) == 0)
    #expect(ComplicationTile.side(forSlotDiameter: -51) == 0)
    #expect(ComplicationTile.side(forSlotDiameter: .nan) == 0)
    #expect(ComplicationTile.side(forSlotDiameter: .infinity) == 0)
  }

  @Test("The card's own 44pt tile would not fit the 46mm slot, which is why the share exists")
  func cardSizeDoesNotFit() {
    #expect(arcReach(side: ComplicationTile.cardSide) > 51.0 / 2)
  }

  @Test("The mask never reaches a corner: a pixel clear at every slot a watch reports, and past both ends")
  func cornersClearTheMask() {
    // The system's requests run 37 to 51pt; swept wider, in quarter points.
    var diameter = 36.0
    while diameter <= 56 {
      let side = ComplicationTile.side(forSlotDiameter: diameter)
      let clearance = diameter / 2 - arcReach(side: side) * continuousOverArc
      // Half a point is one pixel at the watch's 2x.
      #expect(clearance >= 0.5, "a \(diameter)pt slot clears its \(side)pt tile by \(clearance)")
      diameter += 0.25
    }
  }

  @Test("The tile is never wastefully small: within a pixel of the share it is allowed")
  func tileFillsItsShare() {
    var diameter = 36.0
    while diameter <= 56 {
      let side = ComplicationTile.side(forSlotDiameter: diameter)
      #expect(side <= diameter * ComplicationTile.slotShare + 1e-9)
      #expect(side > diameter * ComplicationTile.slotShare - 0.5)
      diameter += 0.25
    }
  }
}
