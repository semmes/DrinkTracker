import Foundation
import Testing

@testable import DrinkTrackerCore

/// ADR-0057, pinned: the home-screen widget's words take the whole column
/// beside the ＋ and may take a second line, and on every iPhone iOS 26
/// supports that holds them whole, at the size the phone draws them.
///
/// Most of these widths can only be seen on a phone of that size, so this
/// table is what stands in for a render of each.
@Suite("Home-screen widget row")
struct QuickLogWidgetRowTests {

  /// How big a phone draws the widget's caption2 at the default text size.
  /// The Plus and Pro Max phones draw it larger — 1.158 times, measured, with
  /// the environment still reporting the default size — and the others at
  /// its 11pt. The count is a fixed size and is the same on all of them.
  private enum Text { case plain, larger }

  private struct Phones {
    let names: String
    /// The small family's content width: its size less its content margins.
    let width: Double
    let text: Text
  }

  /// What iOS 26 gives the small family on every iPhone it supports: the
  /// family's size less its content margins, read from chronod's own host
  /// metrics (`chrono.sql`, `HostConfigs`, the SpringBoard home screen's
  /// host) on an iOS 26.5 simulator of each of the 31 (2026-09-24). iOS 27.0
  /// gives the same eleven. The margins are 9/82 of the side on every one, so
  /// the content is square: the width is also the height. Floored to the
  /// hundredth.
  private let small: [Phones] = [
    Phones(names: "iPhone SE (2nd and 3rd generation)", width: 113.95, text: .plain),
    Phones(names: "iPhone 11 Pro, 12 mini, 13 mini", width: 124.09, text: .plain),
    Phones(names: "iPhone 12, 12 Pro, 13, 13 Pro, 14, 16e, 17e", width: 126.43, text: .plain),
    Phones(names: "iPhone 14 Pro, 15, 15 Pro, 16", width: 126.95, text: .plain),
    Phones(names: "iPhone 16 Pro, 17, 17 Pro", width: 128.26, text: .plain),
    Phones(names: "iPhone 11", width: 129.95, text: .plain),
    Phones(names: "iPhone 11 Pro Max", width: 133.72, text: .larger),
    Phones(names: "iPhone Air", width: 134.76, text: .plain),
    Phones(names: "iPhone 12 Pro Max, 13 Pro Max, 14 Plus", width: 136.06, text: .larger),
    Phones(names: "iPhone 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus", width: 136.32, text: .larger),
    Phones(names: "iPhone 16 Pro Max, 17 Pro Max", width: 137.88, text: .larger),
  ]

  /// The narrowest medium family, the iPhone SE's, for the same reason.
  private let narrowestMedium = 286.95

  // The words as the widget lays them out, measured from renders of both
  // kinds of phone (2026-09-24) and rounded up to the half point. English, the
  // one language the widget ships in; a translation re-measures these.

  /// "drinks today" on one line.
  private func plural(_ text: Text) -> Double { text == .plain ? 65.0 : 75.0 }
  /// "drink today" on one line.
  private func singular(_ text: Text) -> Double { text == .plain ? 59.0 : 68.0 }
  /// "drinks", the longer of the two words: what a column must hold for two
  /// lines to be enough.
  private func longerWord(_ text: Text) -> Double { text == .plain ? 32.0 : 37.5 }
  /// Two lines of the words, as tall as they draw.
  private func twoLines(_ text: Text) -> Double { text == .plain ? 24.5 : 32.0 }
  /// The count's line at 44pt, and the stack's 2pt between it and the words.
  private let countLine = 53.0
  private let stackSpacing = 2.0

  // Larger text. The words follow the reader's text size, but only so far:
  // on both kinds of phone "drinks today" stopped growing at 93.5pt on one
  // line — the same on each, reached at AX1 on the SE and at xxLarge on the
  // 17 Pro Max, and unchanged up to AX5 (measured 2026-09-24). The count and
  // the ＋ are fixed sizes and do not grow at all.

  /// "drinks today" on one line at the largest size the widget draws it.
  private let pluralAtLargest = 93.5
  /// "drinks" at that size: its 11pt width scaled as the line scaled, rounded
  /// up.
  private let longerWordAtLargest = 47.0
  /// Two lines at that size, as tall as they drew.
  private let twoLinesAtLargest = 40.5

  private func newColumn(_ phones: Phones) -> Double {
    QuickLogWidgetRow.wordsColumn(forContentWidth: phones.width, isSmall: true)
  }

  private func oldColumn(_ phones: Phones) -> Double {
    QuickLogWidgetRow.spacerRowColumn(forContentWidth: phones.width, isSmall: true)
  }

  /// The widths are hundredths, so what is derived from them is compared to
  /// a ten-thousandth rather than for bit equality.
  private func close(_ a: Double, _ b: Double) -> Bool {
    abs(a - b) < 0.0001
  }

  @Test("The count's neighbours keep their sizes: the ＋ at 52 and 60, the gap at 12")
  func touchTargetsHold() {
    let smallPlus: Double = 52
    let mediumPlus: Double = 60
    let gap: Double = 12
    let floor: Double = 0.8
    #expect(QuickLogWidgetRow.plusSide(isSmall: true) == smallPlus)
    #expect(QuickLogWidgetRow.plusSide(isSmall: false) == mediumPlus)
    #expect(QuickLogWidgetRow.gap == gap)
    #expect(QuickLogWidgetRow.minimumScale == floor)
    #expect(QuickLogWidgetRow.wordsLineLimit == 2)
  }

  @Test("What the old row left the words: the content less the ＋ and two gaps, never enough for one line")
  func whatTheOldRowLeft() {
    let smallest: Double = 37.95
    let largest: Double = 61.88
    #expect(close(oldColumn(small[0]), smallest))
    #expect(close(oldColumn(small[10]), largest))
    for phones in small {
      // Under "drinks today" at full size on every phone, so no phone drew
      // the plural whole at the size it draws everything else.
      #expect(oldColumn(phones) < plural(phones.text), "\(phones.names)")
    }
  }

  @Test("The new column is the old one and one gap more, on every phone")
  func neverTighter() {
    let gap: Double = 12
    for phones in small {
      #expect(close(newColumn(phones) - oldColumn(phones), gap), "\(phones.names)")
    }
  }

  @Test("Every phone's column holds \"drinks\" at full size, so two lines always hold the words whole")
  func twoLinesAreEnough() {
    for phones in small {
      #expect(newColumn(phones) >= longerWord(phones.text), "\(phones.names) leaves \(newColumn(phones))")
    }
    // The tightest is the SE's: 49.95 for a 32pt word.
    let seColumn: Double = 49.95
    #expect(close(newColumn(small[0]), seColumn))
  }

  @Test("Where the words stay on one line at full size")
  func oneLine() {
    // The plural on two phones only; everywhere else it takes the second line.
    let pluralOnOneLine = small.filter { newColumn($0) >= plural($0.text) }
    #expect(pluralOnOneLine.map(\.names) == ["iPhone 11", "iPhone Air"])
    // The singular on every phone but the SE — so on most phones the words
    // change shape between 1 and 2.
    let singularOnTwoLines = small.filter { newColumn($0) < singular($0.text) }
    #expect(singularOnTwoLines.map(\.names) == ["iPhone SE (2nd and 3rd generation)"])
  }

  @Test("Two lines of words under the count fit every small widget's height")
  func twoLinesFitTheHeight() {
    for phones in small {
      let block = countLine + stackSpacing + twoLines(phones.text)
      #expect(block <= phones.width, "\(phones.names): \(block) in \(phones.width)")
    }
  }

  @Test("At the largest text the widget draws, two lines still hold the words on every phone")
  func largestText() {
    for phones in small {
      #expect(newColumn(phones) >= longerWordAtLargest, "\(phones.names) leaves \(newColumn(phones))")
      let block = countLine + stackSpacing + twoLinesAtLargest
      #expect(block <= phones.width, "\(phones.names): \(block) in \(phones.width)")
    }
  }

  @Test("The medium family never needs the second line, even at the largest text")
  func mediumIsOneLine() {
    let column = QuickLogWidgetRow.wordsColumn(forContentWidth: narrowestMedium, isSmall: false)
    let expected: Double = 214.95
    #expect(close(column, expected))
    #expect(column >= pluralAtLargest)
  }

  // MARK: - The count (ADR-0057's amendment of 2026-09-26)

  // The count shares the words' column, at a fixed 44pt (40 on the medium),
  // SF Rounded semibold with proportional digits — the owner kept them — and
  // the same on every phone: the Plus and Pro Max phones' larger text is the
  // text styles', not a fixed size's.

  /// Each digit's advance at 44pt, measured with CoreText (2026-09-26) — it
  /// agrees with the simulator's frames to the hundredth ("0" 28.42, "16"
  /// 48.84, "100" 77.74) — and rounded up. Some pairs kern tighter, by up to
  /// 3.4pt, and none looser, so a count is never wider than its digits'
  /// sum: what fits by the sum fits on screen.
  private let digitAdvance: [Double] = [
    28.43, 20.90, 26.31, 27.47, 28.17, 27.23, 27.95, 25.14, 28.22, 28.00,
  ]

  private func countWidthAtMost(_ count: Int, numeralSize: Double = 44) -> Double {
    let atFortyFour = String(count).reduce(0.0) { width, digit in
      width + digitAdvance[digit.wholeNumberValue ?? 0]
    }
    return atFortyFour * numeralSize / 44
  }

  // Where a claim is that a count does *not* fit, its own measured width,
  // rounded down, rather than the sum.
  private let twentyAtLeast = 54.65
  private let oneHundredAtLeast = 77.74

  /// What a count must clear the floor by to be claimed whole. SwiftUI sizes
  /// a shrunk count on a quarter-point grid with about 0.1pt to spare and
  /// never under 26.5pt (measured 2026-09-26: 80 at 38.75 in the SE's
  /// column, 199 at 28.25, 250 at 26.5, and 200, which needs 26.43, cut
  /// short), so the rule's floor alone would over-claim near the edge.
  private let wholeAtLeast = 0.62

  private func countScale(_ width: Double, _ phones: Phones) -> Double? {
    QuickLogWidgetRow.countScale(forWidth: width, inColumn: newColumn(phones))
  }

  @Test("The count takes one line and may shrink to 0.6, the floor of every count numeral in the app")
  func countConstants() {
    let floor: Double = 0.6
    #expect(QuickLogWidgetRow.countLineLimit == 1)
    #expect(QuickLogWidgetRow.countMinimumScale == floor)
  }

  @Test("Full size where it fits, smaller where it must be, cut short only past the floor")
  func countScaleRule() {
    let full: Double = 1
    let threeQuarters: Double = 0.75
    let floor: Double = 0.6
    #expect(QuickLogWidgetRow.countScale(forWidth: 40, inColumn: 50) == full)
    #expect(QuickLogWidgetRow.countScale(forWidth: 50, inColumn: 50) == full)
    #expect(QuickLogWidgetRow.countScale(forWidth: 80, inColumn: 60) == threeQuarters)
    #expect(QuickLogWidgetRow.countScale(forWidth: 100, inColumn: 60) == floor)
    #expect(QuickLogWidgetRow.countScale(forWidth: 100, inColumn: 59) == nil)
  }

  @Test("Every two-digit count is full size on every phone but the SE, where 20 is the first to shrink")
  func twoDigitsAtFullSize() {
    let full: Double = 1
    for phones in small.dropFirst() {
      for count in 10...99 {
        #expect(countScale(countWidthAtMost(count), phones) == full, "\(count) on \(phones.names)")
      }
    }
    let se = small[0]
    for count in 10...19 {
      #expect(countScale(countWidthAtMost(count), se) == full, "\(count) on the SE")
    }
    #expect(twentyAtLeast > newColumn(se))
  }

  @Test("On the SE a two-digit count shrinks no further than 0.88")
  func seTwoDigits() {
    let least: Double = 0.88
    let se = small[0]
    for count in 20...99 {
      let scale = countScale(countWidthAtMost(count), se) ?? 0
      #expect(scale >= least, "\(count) draws at \(scale)")
    }
  }

  @Test("Every count to 199 is whole on the SE, and every count to 999 on every other phone")
  func nothingCutShort() {
    let se = small[0]
    for count in 0...199 {
      let scale = countScale(countWidthAtMost(count), se) ?? 0
      #expect(scale >= wholeAtLeast, "\(count) on the SE draws at \(scale)")
    }
    for phones in small.dropFirst() {
      for count in 0...999 {
        let scale = countScale(countWidthAtMost(count), phones) ?? 0
        #expect(scale >= wholeAtLeast, "\(count) on \(phones.names) draws at \(scale)")
      }
    }
  }

  @Test("100 shrinks on every small widget: to about 0.64 on the SE and 0.95 on the largest")
  func oneHundred() {
    let seAbout: Double = 0.64
    let largestAbout: Double = 0.95
    let tolerance: Double = 0.01
    for phones in small {
      let scale = countScale(oneHundredAtLeast, phones) ?? 0
      #expect(scale >= wholeAtLeast, "\(phones.names)")
      #expect(scale < 1, "\(phones.names)")
    }
    #expect(abs((countScale(oneHundredAtLeast, small[0]) ?? 0) - seAbout) < tolerance)
    #expect(abs((countScale(oneHundredAtLeast, small[10]) ?? 0) - largestAbout) < tolerance)
  }

  @Test("The medium family never shrinks the count, to four digits")
  func mediumCountAtFullSize() {
    let full: Double = 1
    let column = QuickLogWidgetRow.wordsColumn(forContentWidth: narrowestMedium, isSmall: false)
    // 8000 is the widest four-digit count by the sum: 8 is the widest
    // leading digit, 0 the widest digit.
    for count in [9999, 8888, 8000, 999, 800, 80] {
      let width = countWidthAtMost(count, numeralSize: 40)
      #expect(QuickLogWidgetRow.countScale(forWidth: width, inColumn: column) == full, "\(count)")
    }
  }
}
