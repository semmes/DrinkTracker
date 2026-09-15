import DrinkTrackerCore
import SwiftUI

/// The sitting's dots (watch Phase 5, ADR-0044), shared by the watch's counter
/// and its complication so the two cannot draw a session differently:
/// `count` dots in `band`'s dark fill, or 1pt rings in the secondary label
/// colour when `ringed` — no band (the window is under `.medium`), or the
/// count concealed. Sizes default to the design's 9pt at 5pt gaps; the
/// complication passes its own.
///
/// `.secondary` for the ring rather than the tile border's 35% primary: at
/// this size a 1pt ring needs its own 3:1, and secondary label ink on black is
/// 6.4:1 where white at 35% sits on the line — 3.01:1 unquantised, 2.998:1 as
/// the `#595959` it renders as (ADR-0044).
struct SessionDots: View {
  let count: Int
  let band: DayIntensity?
  let ringed: Bool
  var size: CGFloat = 9
  var gap: CGFloat = 5

  var body: some View {
    HStack(spacing: gap) {
      ForEach(0..<max(0, count), id: \.self) { _ in
        if let band, !ringed {
          Circle()
            .fill(IntensityPalette.fill(band, scheme: .dark))
            .frame(width: size, height: size)
        } else {
          Circle()
            .strokeBorder(.secondary, lineWidth: 1)
            .frame(width: size, height: size)
        }
      }
    }
  }

  /// The rolling two-hour window's band, or nil for the ring — the phone
  /// card's rule with a different floor: `.medium` and above tint the dots,
  /// because a dot needs 3:1 against its ground and the dark ramp's `.low`
  /// measures 2.59:1 on black (ADR-0044's table). One rule for the counter
  /// and the complication — `nonisolated`, because a `View`'s members inherit
  /// the main actor and the complication's timeline provider calls this off
  /// it.
  nonisolated static func band(in drinks: [LoggedDrink], now: Date, region: Region) -> DayIntensity? {
    let total = SessionPace.rollingStandardDrinks(in: drinks, now: now, region: region)
    let band = DayIntensity.bucket(standardDrinks: total, isMarkedAlcoholFree: false, hasEntries: true)
    switch band {
    case .medium, .high, .veryHigh: return band
    case .unlogged, .alcoholFree, .low: return nil
    }
  }
}
