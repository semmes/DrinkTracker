import DrinkTrackerCore
import SwiftUI

/// One sentence saying what ＋ will log.
///
/// Lifted verbatim out of `DayLogSheet.countCaption` so Today and the day sheet
/// state the same rule in the same words (ADR-0034). Every branch is already
/// through the 1.4.3 tone review, which is the other reason to move the code
/// rather than write a second sentence: the drawing's "Or tap + — one tap is
/// one standard drink." is true only under the standard-drink seed, and a
/// caption under a counter that lies in one of its two modes is worse than no
/// caption at all.
struct CounterSeedCaption: View {
  /// The drink ＋ would log right now — build it with
  /// `DrinkDraft.countSeedPreview`, never by hand, so this cannot drift from
  /// what the write actually does.
  let seed: LoggedDrink?
  /// The day sheet's counter caption also describes −; Today's pill caption
  /// leaves − unexplained by design (ADR-0034). Today's empty day shows no
  /// caption at all since the owner's 2026-09-08 review.
  var includesMinus: Bool = false

  var body: some View {
    caption
  }

  /// `Text`, not `String`: a `String` would reach `Text` through the verbatim
  /// initializer and never enter the string catalog. Each sentence is its own
  /// literal, so translators get whole sentences rather than glued fragments.
  private var caption: Text {
    let adds: Text
    // An untyped seed says what it logs and stops: printing its stored
    // 0.6oz/100% would hand the standard-drink definition back as a serving
    // (ADR-0023).
    if let seed, seed.isTypeUnspecified {
      adds = Text("Plus logs one standard drink, with no type — editable afterwards.")
    // "a other" is not a sentence; Other falls back to the generic noun.
    } else if let seed, seed.type != .other {
      adds = Text("Plus logs a \(seed.type.displayName.lowercased()), \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — editable afterwards.")
    } else if let seed {
      adds = Text("Plus logs a drink, \(LoggedDrink.displayOunces(seed.volumeOunces))oz at \(LoggedDrink.displayPercent(seed.abvPercent))% — editable afterwards.")
    } else {
      adds = Text("Plus logs a drink at the default size and strength — editable afterwards.")
    }
    guard includesMinus else { return adds }
    // Interpolation rather than `+`: concatenating would leave the second
    // sentence in the catalog with a leading space, which a translator will
    // silently drop. (`+` is also deprecated in iOS 26.)
    return Text("\(adds) Minus removes the day's most recent drink.")
  }
}
