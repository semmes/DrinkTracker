import Foundation
import Testing

/// `.tertiaryInk` is the system's tertiary label, and that colour is too faint
/// for text a reader needs: 1.72:1 on white and 2.23:1 on black, measured on
/// the iOS 27 simulator on 2026-09-26, and no flat token lifts it, because it
/// is the colour's own value rather than vibrancy (design-system §2). The two
/// tips that used it, Trends' and the calendar's, took `.secondaryInk` then.
/// What is left is three sites a reader loses nothing by not seeing, each
/// named here with its reason, so a new use of the token is a decision written
/// down rather than a default reached for. No test tier reaches a rendered
/// view, so this reads the source, the way `InkTests` does.
@Suite("Tertiary ink")
struct TertiaryInkTests {
  /// `DrinkTracker/`, found from this file's own path, as in `InkTests`.
  private var appSources: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // DrinkTrackerTests
      .deletingLastPathComponent()  // the repository
      .appendingPathComponent("DrinkTracker")
  }

  /// Every file allowed to use `.tertiaryInk`, and how many times.
  private static let allowed: [String: Int] = [
    // A logged row's disclosure chevron, on Today and the day sheet. It is the
    // colour the system draws its own chevron in (the Settings app measured
    // the same #C5C5C7 on white), a glyph rather than text, and the row is a
    // button that says so to VoiceOver. On Today the list's footer also says
    // "Tap a drink to change what it was."; on the day sheet the chevron is
    // the visible cue for a described drink, as it is in Settings.
    "TodayDrinkRow.swift": 1,
    // The Health offer's "– –" where a figure would be: hidden from
    // VoiceOver, and the offer's own sentence says what the figures will be.
    "HealthPairingSection.swift": 1,
    // "(that's five)" under onboarding's tally mark: decoration, hidden from
    // VoiceOver, with the headline below carrying the meaning.
    "WelcomeView.swift": 1,
  ]

  @Test("Tertiary ink only where a reader needs nothing from it")
  func tertiaryInkStaysOffTextThatInforms() throws {
    let files = try #require(
      FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil)
    )
    var swiftFiles = 0
    var uses: [String: Int] = [:]
    for case let url as URL in files where url.pathExtension == "swift" {
      swiftFiles += 1
      let source = try String(contentsOf: url, encoding: .utf8)
      // Comments may name the token; only code counts.
      var count = 0
      for line in source.split(separator: "\n", omittingEmptySubsequences: false)
      where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
        count += line.components(separatedBy: ".tertiaryInk").count - 1
      }
      if count > 0 { uses[url.lastPathComponent] = count }
    }
    // The walk found the app target, not an empty or wrong directory.
    #expect(swiftFiles > 50)
    #expect(
      uses == Self.allowed,
      """
      .tertiaryInk is used in \(uses), expected \(Self.allowed). Text a reader \
      needs takes .secondaryInk (design-system §2); a use that is not text of \
      that kind goes in `allowed` with its reason.
      """
    )
  }
}
