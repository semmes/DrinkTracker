import Foundation
import Testing

/// `.tertiaryInk` is the system's tertiary label, and that colour is too faint
/// for text a reader needs: 1.72:1 on white and 2.23:1 on black, measured on
/// the iOS 27 simulator on 2026-09-26, and no flat token lifts it, because it
/// is the colour's own value rather than vibrancy (design-system §2). The two
/// tips that used it, Trends' and the calendar's, took `.secondaryInk` then.
/// What is left is three sites a reader loses nothing by not seeing, each
/// named here with its reason, so a new use of the token is a decision written
/// down rather than a default reached for. The same rule holds outside the app
/// target, where the watch and the widgets write the hierarchical `.tertiary`
/// (the second test). No test tier reaches a rendered view, so this reads the
/// source, the way `InkTests` does.
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

  /// The hierarchical tertiary style used as text ink: the tertiary half of
  /// `InkTests`' list.
  private static let tertiaryTextStyles = [
    ".foregroundStyle(.tertiary)",
    ".foregroundColor(.tertiary)",
    "AnyShapeStyle(.tertiary)",
    ": Color.tertiary)",
    ": .tertiary\n",
  ]

  /// Every file outside the app target allowed that style on text, and how
  /// many times.
  private static let allowedOutsideTheApp: [String: Int] = [
    // The watch counter's diagnostics line under the hint: `#if DEBUG`, so a
    // Release build does not compile it, and it is for whoever is debugging,
    // not the wearer.
    "DrinkTrackerWatch/CounterView.swift": 1,
  ]

  /// The watch app, its complication and the Home Screen widget. The flat
  /// tokens live in the app target (`GlassTokens.swift`), so these targets
  /// write the hierarchical style, and neither `InkTests` nor the test above
  /// reads them. The watch's hint and the widget's ≈ line were the last text
  /// here in tertiary, 2.23:1 on the watch's black and 1.70:1 on the widget's
  /// light ground, and took `.secondary` on 2026-09-26 (design-system §2, §9).
  @Test("Tertiary style only where a reader needs nothing from it, on the watch and the widgets")
  func tertiaryStyleStaysOffTextOutsideTheApp() throws {
    let repository = appSources.deletingLastPathComponent()
    var swiftFiles: [String: Int] = [:]
    var uses: [String: Int] = [:]
    for folder in ["DrinkTrackerWatch", "DrinkTrackerWatchWidget", "DrinkTrackerWidget"] {
      let files = try #require(
        FileManager.default.enumerator(
          at: repository.appendingPathComponent(folder), includingPropertiesForKeys: nil)
      )
      for case let url as URL in files where url.pathExtension == "swift" {
        swiftFiles[folder, default: 0] += 1
        let source = try String(contentsOf: url, encoding: .utf8)
        // Comments may name the style; only code counts.
        let code = source.split(separator: "\n", omittingEmptySubsequences: false)
          .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
          .joined(separator: "\n") + "\n"
        var count = 0
        for style in Self.tertiaryTextStyles {
          count += code.components(separatedBy: style).count - 1
        }
        if count > 0 { uses["\(folder)/\(url.lastPathComponent)"] = count }
      }
    }
    // Each walk found its target, not an empty or wrong directory.
    #expect(swiftFiles.count == 3)
    #expect(
      uses == Self.allowedOutsideTheApp,
      """
      The hierarchical .tertiary is on text in \(uses), expected \
      \(Self.allowedOutsideTheApp). Text a reader needs takes .secondary \
      (design-system §2); a use that is not text of that kind goes in \
      `allowedOutsideTheApp` with its reason.
      """
    )
  }
}
