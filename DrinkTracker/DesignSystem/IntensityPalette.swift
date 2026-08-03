import DrinkTrackerCore
import SwiftUI

/// The calendar's intensity ramp — the one place this app defines literal colours.
///
/// `GlassTokens` deliberately defines none, so that everything inherits Liquid
/// Glass's automatic light/dark and vibrancy behaviour. This is the documented
/// exception, and it is narrow on purpose: a heatmap encodes magnitude *in* colour,
/// so the colour is data rather than styling, and data has to be specified rather
/// than inherited. Nothing outside the calendar surfaces may draw from it.
///
/// ## Why one hue rather than a red-to-green scale
///
/// A green→yellow→orange→red ramp is the obvious choice and the wrong one, twice
/// over.
///
/// **It fails for colourblind readers.** Under protanopia and deuteranopia — around
/// 8% of men — those four hues collapse toward the same yellow-brown, and because
/// they sit at similar lightness there is nothing left to separate them. The worst
/// pair in it is exactly the one that matters most here: no-alcohol green against
/// one-to-two-drinks yellow, adjacent in hue and near-identical in lightness.
///
/// **It also delivers a verdict.** Red for a heavy day and green for a clear one
/// tells the user what to think about their own week. `QuickLogWidget` already
/// commits to "no colour that reads as a verdict", and that holds here.
///
/// A single hue stepped light→dark fixes both. Lightness survives every form of
/// colour vision deficiency *and* greyscale printing, so the information rides a
/// channel that cannot collapse; and a darker blue reads as *more*, not as *worse*.
///
/// ## Why alcohol-free is not a step in the ramp
///
/// Encoding zero as the palest blue would say *a small amount of drinking*. It is
/// the absence of the measured quantity, not the bottom of it, so it takes its own
/// neutral treatment. That also puts the maximum possible distance between it and
/// the 1–2 bucket, which is the distinction the ramp most needs to carry.
///
/// ## Provenance
///
/// Steps are from the documented sequential blue ramp, validated rather than
/// chosen by eye — monotone lightness, adjacent ΔL ≥ 0.06, light end ≥ 2:1 against
/// the surface, single hue. Both modes pass. Dark is stepped independently against
/// the dark surface rather than being an inversion of light, because an inverted
/// ramp lands outside the band at both ends.
///
/// **Any change to these values must be re-validated, not eyeballed.**
enum IntensityPalette {

  /// Fill for a calendar cell at the given intensity.
  static func fill(_ intensity: DayIntensity, scheme: ColorScheme) -> Color {
    switch intensity {
    case .unlogged:
      // No fill at all. An unlogged day is absence of information, and absence is
      // best drawn as absence — any fill invites reading it as a value.
      return .clear
    case .alcoholFree:
      // Off the ramp entirely: a neutral that reads as "recorded, nothing in it".
      return Color.primary.opacity(scheme == .dark ? 0.16 : 0.10)
    case .low:
      return scheme == .dark ? Self.darkLow : Self.lightLow
    case .medium:
      return scheme == .dark ? Self.darkMedium : Self.lightMedium
    case .high:
      return scheme == .dark ? Self.darkHigh : Self.lightHigh
    }
  }

  /// Ink for anything drawn on top of that fill.
  ///
  /// The ramp's dark end is dark enough in light mode — and light enough in dark
  /// mode — that a single ink colour would drop below contrast at one end. This
  /// flips with the fill rather than hoping one value covers both.
  static func ink(_ intensity: DayIntensity, scheme: ColorScheme) -> Color {
    switch intensity {
    case .unlogged:
      return .secondary
    case .alcoholFree:
      return .primary
    case .low:
      return scheme == .dark ? .white : .black
    case .medium, .high:
      return scheme == .dark ? .black : .white
    }
  }

  /// Whether this intensity carries a stroke instead of, or as well as, a fill.
  ///
  /// The second encoding channel. A reader who cannot separate the fills still gets
  /// an outline on recorded-but-empty days, so "no alcohol" is distinguishable from
  /// "not logged" by shape alone.
  static func isOutlined(_ intensity: DayIntensity) -> Bool {
    intensity == .alcoholFree
  }

  // Light mode — steps 250 / 450 / 700.
  private static let lightLow = Color(red: 0.525, green: 0.714, blue: 0.937)     // #86b6ef
  private static let lightMedium = Color(red: 0.165, green: 0.471, blue: 0.839)  // #2a78d6
  private static let lightHigh = Color(red: 0.051, green: 0.212, blue: 0.420)    // #0d366b

  // Dark mode — steps 600 / 400 / 200, stepped against the dark surface.
  private static let darkLow = Color(red: 0.094, green: 0.310, blue: 0.584)      // #184f95
  private static let darkMedium = Color(red: 0.224, green: 0.529, blue: 0.898)   // #3987e5
  private static let darkHigh = Color(red: 0.620, green: 0.773, blue: 0.957)     // #9ec5f4
}
