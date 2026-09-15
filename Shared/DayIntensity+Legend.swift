import DrinkTrackerCore
import SwiftUI

extension DayIntensity {
  /// Legend order, shared by the in-app legend and the share cards'
  /// `ShareCardLegend` (ADR-0027) so the two cannot drift. "Not logged" is
  /// drawn as nothing, so naming it last is what tells a reader that a blank
  /// cell means absence of data, not a zero.
  static let legendOrder: [DayIntensity] = [.alcoholFree, .low, .medium, .high, .veryHigh, .unlogged]

  /// The legend label as a catalog key.
  ///
  /// `legendLabel` is the package's plain String, and `Text(String)` is the
  /// verbatim initializer — so the in-app legend never reached the catalog.
  /// The words are the same six. They live here rather than behind the
  /// package's `localized()` because `xcstringstool generate-symbols` derives
  /// a Swift identifier from every package key, and keys made of digits and
  /// punctuation ("1–2", "6+") are the ones it has no good answer for; the
  /// targets that compile this file generate no symbols and tolerate them.
  /// Localizing the package's own labels is ADR-0020's question, deferred with
  /// the rest of translation.
  ///
  /// In `Shared/` since the watch's Phase 3, because the wrist's legend under
  /// its counter names the same four bands (ADR-0034's argument, and the
  /// design's): one home for the words, one key per band in every catalog.
  var legendKey: LocalizedStringKey {
    switch self {
    case .unlogged: "Not logged"
    case .alcoholFree: "No alcohol"
    case .low: "1–2"
    case .medium: "3–5"
    case .high: "6–9"
    case .veryHigh: "10+"
    }
  }
}
