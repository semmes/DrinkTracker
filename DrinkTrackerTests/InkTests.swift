import Foundation
import Testing

/// The app target's text takes the flat ink tokens (`.secondaryInk`,
/// `.tertiaryInk` in `GlassTokens.swift`), never the hierarchical `.secondary`
/// and `.tertiary` styles: on glass those are drawn with vibrancy, and against
/// the app's black dark ground that left every card title and caption at
/// 2.5:1 (the owner's device report of 2026-09-22; design-system §2). No test
/// tier reaches a rendered view, so the guard reads the source instead — the
/// way the core package's catalog tests read the catalog — and fails on the
/// first hierarchical text style that comes back. The share cards' own
/// `ink.secondary` is a different thing (the literal-colour site, ADR-0027)
/// and is not matched; nor is a fill, which this rule is not about.
@Suite("Ink on glass")
struct InkTests {
  /// `DrinkTracker/`, found from this file's own path, so the test reads the
  /// tree it was built from and needs no bundle resource.
  private var appSources: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()  // DrinkTrackerTests
      .deletingLastPathComponent()  // the repository
      .appendingPathComponent("DrinkTracker")
  }

  private static let hierarchicalTextStyles = [
    ".foregroundStyle(.secondary)",
    ".foregroundStyle(.tertiary)",
    ".foregroundColor(.secondary)",
    ".foregroundColor(.tertiary)",
    "AnyShapeStyle(.secondary)",
    "AnyShapeStyle(.tertiary)",
    ": Color.secondary)",
    ": Color.tertiary)",
    ": .secondary\n",
    ": .tertiary\n",
  ]

  @Test("No hierarchical secondary or tertiary text style in the app target")
  func appTextTakesTheFlatInks() throws {
    let files = try #require(
      FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil)
    )
    var swiftFiles = 0
    var offenders: [String] = []
    for case let url as URL in files where url.pathExtension == "swift" {
      swiftFiles += 1
      let source = try String(contentsOf: url, encoding: .utf8)
      // Comments may name the styles they warn against; code may not use them.
      let code = source.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n") + "\n"
      for style in Self.hierarchicalTextStyles where code.contains(style) {
        offenders.append("\(url.lastPathComponent): \(style.trimmingCharacters(in: .newlines))")
      }
    }
    // The walk found the app target, not an empty or wrong directory.
    #expect(swiftFiles > 50)
    #expect(offenders.isEmpty, "\(offenders)")
  }

  @Test("The ink tokens exist where the rule says they do")
  func tokensAreDefined() throws {
    let tokens = try String(
      contentsOf: appSources.appendingPathComponent("DesignSystem/GlassTokens.swift"), encoding: .utf8)
    #expect(tokens.contains("static var secondaryInk: Color { Color(.secondaryLabel) }"))
    #expect(tokens.contains("static var tertiaryInk: Color { Color(.tertiaryLabel) }"))
  }
}
