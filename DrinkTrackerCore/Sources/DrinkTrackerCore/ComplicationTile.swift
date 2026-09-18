import Foundation

/// The geometry of the count's tile on the watch face (ADR-0046, amended
/// 2026-09-18): the rectangular card draws it at 44 with a 13pt continuous
/// corner, and the circular family draws the same tile as large as its round
/// slot can hold without the system's mask taking a corner off.
///
/// Arithmetic only, and here rather than in the complication so the rule that
/// keeps the corners inside the mask is pinned at tier 1 instead of being
/// checked by eye on a face. Points throughout.
public enum ComplicationTile {
  /// The rectangular card's tile, which the circular one is a smaller copy of.
  public static let cardSide: Double = 44

  /// The corner as the card's own 13 on 44, so a smaller tile keeps the
  /// card's *shape* rather than the card's radius.
  public static func cornerRadius(forSide side: Double) -> Double {
    side * 13 / 44
  }

  /// The tile's side in a circular slot: 0.83 of the diameter, floored to the
  /// half point — a whole pixel at the watch's 2x.
  ///
  /// Why 0.83. A square with this corner reaches 0.585 of its side from its
  /// centre, along the diagonal. A copy of the card's 44pt tile would reach
  /// 25.75 in the 46mm watch's 51pt slot, whose radius is 25.5, and lose all
  /// four corners to the mask. At 0.83 the corner clears the mask by more than
  /// half a point — a pixel — at every slot the system asks for, 37 to 51pt,
  /// so antialiasing never touches it (measured against SwiftUI's own
  /// continuous path; the tests restate it against the arc).
  public static func side(forSlotDiameter diameter: Double) -> Double {
    guard diameter.isFinite, diameter > 0 else { return 0 }
    return (diameter * slotShare * 2).rounded(.down) / 2
  }

  /// The share of a circular slot's diameter the tile takes.
  public static let slotShare = 0.83
}
