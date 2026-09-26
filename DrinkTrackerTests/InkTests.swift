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
///
/// A chart's axis labels are text the same rule missed, because a bare
/// `AxisValueLabel()` sets no style at all: Swift Charts supplies its own. And
/// the flat ink is not enough there. The Trends chart's y axis resolves a
/// dynamic colour against the appearance before the current one, so after a
/// live switch to dark its labels drew light mode's secondary label on black,
/// 1.36:1, with or without `.secondaryInk` (2026-09-26; ADR-0028's third
/// amendment). Every axis label takes `axisInk`, the chart's
/// `Color.chartAxisInk` resolved for the current appearance.
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

  /// Every Swift file in the app target, as (file name, code): comment lines
  /// are dropped, since comments may name the styles they warn against and
  /// code may not use them.
  private func appCode() throws -> [(name: String, code: String)] {
    let files = try #require(
      FileManager.default.enumerator(at: appSources, includingPropertiesForKeys: nil)
    )
    var result: [(name: String, code: String)] = []
    for case let url as URL in files where url.pathExtension == "swift" {
      let source = try String(contentsOf: url, encoding: .utf8)
      let code = source.split(separator: "\n", omittingEmptySubsequences: false)
        .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
        .joined(separator: "\n") + "\n"
      result.append((url.lastPathComponent, code))
    }
    return result
  }

  @Test("No hierarchical secondary or tertiary text style in the app target")
  func appTextTakesTheFlatInks() throws {
    let files = try appCode()
    var offenders: [String] = []
    for file in files {
      for style in Self.hierarchicalTextStyles where file.code.contains(style) {
        offenders.append("\(file.name): \(style.trimmingCharacters(in: .newlines))")
      }
    }
    // The walk found the app target, not an empty or wrong directory.
    #expect(files.count > 50)
    #expect(offenders.isEmpty, "\(offenders)")
  }

  /// What must follow every axis label, after its arguments and any trailing
  /// closure.
  private static let axisLabelStyle = ".foregroundStyle(axisInk)"

  /// Every `AxisValueLabel` in `code` not followed by `axisLabelStyle`, as the
  /// label's own text. A label's arguments may nest parentheses
  /// (`format: .dateTime.month(.abbreviated)`) and it may take a trailing
  /// closure, so both are matched to their close rather than assumed to end at
  /// the first `)`; whitespace, newlines included, may sit before the style.
  static func unstyledAxisLabels(in code: String) -> [String] {
    let characters = Array(code)
    let name = Array("AxisValueLabel")
    let style = Array(axisLabelStyle)
    func isIdentifier(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }
    func skipGroup(from index: Int, open: Character, close: Character) -> Int {
      guard index < characters.count, characters[index] == open else { return index }
      var depth = 0
      var cursor = index
      while cursor < characters.count {
        if characters[cursor] == open { depth += 1 }
        if characters[cursor] == close {
          depth -= 1
          if depth == 0 { return cursor + 1 }
        }
        cursor += 1
      }
      return cursor
    }
    func skipSpace(from index: Int) -> Int {
      var cursor = index
      while cursor < characters.count, characters[cursor].isWhitespace { cursor += 1 }
      return cursor
    }

    var offenders: [String] = []
    var index = 0
    while index + name.count <= characters.count {
      guard Array(characters[index..<(index + name.count)]) == name else {
        index += 1
        continue
      }
      let start = index
      var end = index + name.count
      // Part of a longer identifier, not the label itself.
      if (start > 0 && isIdentifier(characters[start - 1]))
        || (end < characters.count && isIdentifier(characters[end])) {
        index = end
        continue
      }
      end = skipGroup(from: end, open: "(", close: ")")
      end = skipGroup(from: skipSpace(from: end), open: "{", close: "}")
      let styleStart = skipSpace(from: end)
      let styleEnd = min(styleStart + style.count, characters.count)
      if Array(characters[styleStart..<styleEnd]) != style {
        offenders.append(String(characters[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines))
      }
      index = end
    }
    return offenders
  }

  @Test("The axis-label scanner finds what it is for")
  func axisLabelScannerCatchesTheShapes() {
    let styled = [
      "AxisValueLabel().foregroundStyle(axisInk)",
      "AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(axisInk)",
      "AxisValueLabel(format: .dateTime.month(.abbreviated))\n    .foregroundStyle(axisInk)",
      "AxisValueLabel { Text(\"x\") }.foregroundStyle(axisInk)",
      "MyAxisValueLabelHelper()",
    ]
    for code in styled {
      #expect(Self.unstyledAxisLabels(in: code).isEmpty, "\(code)")
    }
    let unstyled = [
      "AxisValueLabel()",
      "AxisValueLabel(format: .number)",
      "AxisValueLabel().foregroundStyle(.secondaryInk)",
      "AxisValueLabel(format: .dateTime.month(.abbreviated)).foregroundStyle(.secondary)",
      "AxisValueLabel { Text(\"x\").foregroundStyle(axisInk) }",
    ]
    for code in unstyled {
      #expect(Self.unstyledAxisLabels(in: code).count == 1, "\(code)")
    }
  }

  @Test("Every chart axis label in the app target takes the resolved axis ink")
  func axisLabelsTakeTheResolvedInk() throws {
    var offenders: [String] = []
    for file in try appCode() {
      for label in Self.unstyledAxisLabels(in: file.code) {
        offenders.append("\(file.name): \(label)")
      }
    }
    #expect(offenders.isEmpty, "\(offenders)")
  }

  @Test("The ink tokens exist where the rule says they do")
  func tokensAreDefined() throws {
    let tokens = try String(
      contentsOf: appSources.appendingPathComponent("DesignSystem/GlassTokens.swift"), encoding: .utf8)
    #expect(tokens.contains("static var secondaryInk: Color { Color(.secondaryLabel) }"))
    #expect(tokens.contains("static var tertiaryInk: Color { Color(.tertiaryLabel) }"))
    #expect(tokens.contains("static func chartAxisInk(_ scheme: ColorScheme, contrast: ColorSchemeContrast) -> Color"))
    #expect(tokens.contains("return Color(uiColor: .secondaryLabel.resolvedColor(with: traits))"))
  }
}
