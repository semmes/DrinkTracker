import DrinkTrackerCore
import SwiftUI

/// The calendar's intensity ramp — where this app defines its literal colours.
///
/// `GlassTokens` deliberately defines none, so that everything inherits Liquid
/// Glass's automatic light/dark and vibrancy behaviour. This is the documented
/// exception, and it is narrow on purpose: a heatmap encodes magnitude *in* colour,
/// so the colour is data rather than styling, and data has to be specified rather
/// than inherited. Nothing outside the calendar surfaces may draw from it, with
/// three named exceptions: `liveFigure(scheme:)` below, **Today's hero band**
/// (ADR-0034), which paints the day's own count behind the counter using
/// `fill`/`ink`/`isOutlined` unchanged. The band is the same quantity through
/// the same fold — `DayIntensity.bucket` over the region-lensed total — so a day
/// can never read one amount on Today and another on the calendar. Reached by
/// name, exactly as `liveFigure` is; no value is copied. The third is the
/// **session-pace chip**, from `.high` upward, which paints the rolling
/// window's own bucket the same way — the argument for that one lives in
/// ADR-0017's amendment, because it is the one that reverses a refusal.
/// The one other literal-colour site is `ShareCardInk` — the ground and inks
/// of an exported image, which has no host surface to inherit from — and it
/// takes every day-cell fill and outline decision from here (ADR-0027,
/// invariant 10); a share card's chart bars are the `AccentFill` token
/// (ADR-0029), a named asset rather than a literal.
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
/// ### The fourth step (1.3, ADR-0034)
///
/// `.veryHigh` splits the old open-ended "6+" into 6–9 and 10+. Re-validated,
/// not eyeballed — CIE L\* computed from sRGB, contrast by WCAG relative
/// luminance:
///
/// | | L\* | ΔL\*/100 from the step below | ink | ink contrast |
/// |---|---|---|---|---|
/// | light 700 `#0d366b` | 22.95 | 0.275 | white | 11.95:1 |
/// | light 800 `#05172e` | 7.61 | **0.153** | white | **17.97:1** |
/// | dark 200 `#9ec5f4` | 78.30 | 0.224 | black | 11.75:1 |
/// | dark 100 `#cde2fb` | 89.08 | **0.108** | black | **15.87:1** |
///
/// Hue stays inside the family (light 800 sits at 278.1°, within the ramp's own
/// 262.6–283.0° span), lightness stays monotone, and the pale end is unchanged
/// so the ≥ 2:1 surface gate is inherited.
///
/// Two things worth knowing before touching this again. The **dark** step is
/// step 100 of the documented family, not a new value: step 150 `#b7d3f6` was
/// the obvious choice and fails, at ΔL 0.053. And `#05172e` is the ramp's
/// **floor** — at L\* 7.6 there is no room for a fifth step below it, so a
/// future "20+" bucket would have to re-space the whole ramp rather than extend
/// it. Luminance contrast between the two deepest fills is 1.50:1 (light) and
/// 1.35:1 (dark), lower than the 2.04–2.71 of the pairs above them, because
/// luminance compresses at both ends of a lightness ramp; the gate the ADR
/// states is the perceptual one, ΔL\*, and the outline channel that separates
/// "recorded as none" from "not logged" is untouched.
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
    case .veryHigh:
      return scheme == .dark ? Self.darkVeryHigh : Self.lightVeryHigh
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
    case .medium, .high, .veryHigh:
      return scheme == .dark ? .black : .white
    }
  }

  /// The Trends readout figure while a bar is being touched — step 700 / 200 of
  /// the same hue, reached by name rather than by copy (ADR-0028's second
  /// amendment). Deliberately *not* moved to the ramp's new floor when
  /// `.veryHigh` arrived: this is interaction state, not magnitude, so it has
  /// no reason to track the deepest data step.
  ///
  /// The owner's ruling (2026-09-05) is that this tint is **the interaction
  /// pattern for the bar under your finger, not a reference to how many drinks
  /// are logged**. That is what makes a ramp step legitimate here: nothing
  /// teaches a reader to decode the colour of a numeral, the two readout states
  /// never coexist, and the figure prints its own value in digits an inch high —
  /// so the hue carries emphasis, while lightness still carries magnitude only
  /// where a legend explains it.
  ///
  /// It is an accessor and not a second literal — and deliberately not a new
  /// asset-catalog colour — because these values are *validated*, and a copy in
  /// the asset catalog would decouple silently the next time the ramp is
  /// re-validated: same colour, two homes, no compiler and no test between them.
  /// Routed through here, PRD invariant 10's "only place in the app that defines
  /// literal colours" stays literally true, and design-system.md's "the brand
  /// layer lives in the asset catalog (`AccentColor`) and `IntensityPalette`
  /// only" needs no edit.
  ///
  /// Measured, not eyeballed (invariant 10): light `#0d366b` is 11.95:1 on the
  /// card's white and 10.71:1 on the grouped background; dark `#9ec5f4` is
  /// 9.52:1 on `#1C1C1E` and 11.75:1 on black.
  static func liveFigure(scheme: ColorScheme) -> Color {
    scheme == .dark ? Self.darkHigh : Self.lightHigh
  }

  /// Whether this intensity carries a stroke instead of, or as well as, a fill.
  ///
  /// The second encoding channel. A reader who cannot separate the fills still gets
  /// an outline on recorded-but-empty days, so "no alcohol" is distinguishable from
  /// "not logged" by shape alone.
  static func isOutlined(_ intensity: DayIntensity) -> Bool {
    intensity == .alcoholFree
  }

  // Light mode — steps 250 / 450 / 700 / 800.
  private static let lightLow = Color(red: 0.525, green: 0.714, blue: 0.937)     // #86b6ef
  private static let lightMedium = Color(red: 0.165, green: 0.471, blue: 0.839)  // #2a78d6
  private static let lightHigh = Color(red: 0.051, green: 0.212, blue: 0.420)    // #0d366b
  private static let lightVeryHigh = Color(red: 0.020, green: 0.090, blue: 0.180) // #05172e

  // Dark mode — steps 600 / 400 / 200 / 100, stepped against the dark surface.
  private static let darkLow = Color(red: 0.094, green: 0.310, blue: 0.584)      // #184f95
  private static let darkMedium = Color(red: 0.224, green: 0.529, blue: 0.898)   // #3987e5
  private static let darkHigh = Color(red: 0.620, green: 0.773, blue: 0.957)     // #9ec5f4
  private static let darkVeryHigh = Color(red: 0.804, green: 0.886, blue: 0.984) // #cde2fb
}
