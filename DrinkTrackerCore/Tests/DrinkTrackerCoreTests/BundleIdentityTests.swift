import Foundation
import Testing

@testable import DrinkTrackerCore

/// PRD invariant 4, pinned: the four processes that open the shared store —
/// the app, its widget, the watch app and its complication — must derive one
/// App Group and one iCloud container from their four bundle identifiers.
/// The derivation used to strip `.Widget` alone; the two watch identifiers
/// would have yielded two more groups, and the only symptom would have been a
/// complication stuck on zero.
@Suite("Bundle identity")
struct BundleIdentityTests {

  private let host = "com.shawnsemmes.DrinkTracker"

  @Test(
    "Every process derives the same host, App Group and iCloud container",
    arguments: ["", ".Widget", ".watchkitapp", ".watchkitapp.Widget"]
  )
  func everyProcessAgrees(suffix: String) {
    let derived = BundleIdentity.hostBundleID(from: host + suffix)
    #expect(derived == host)
    #expect(BundleIdentity.appGroupIdentifier(hostBundleID: derived) == "group.com.shawnsemmes.DrinkTracker")
    #expect(BundleIdentity.iCloudContainerIdentifier(hostBundleID: derived) == "iCloud.com.shawnsemmes.DrinkTracker")
  }

  @Test("The suffixes are exactly the ones the project's targets carry")
  func suffixesMatchTheProject() {
    // PRODUCT_BUNDLE_IDENTIFIER, per target, in DrinkTracker.xcodeproj:
    // $(BUNDLE_ID_PREFIX).DrinkTracker.Widget, .watchkitapp, .watchkitapp.Widget.
    #expect(BundleIdentity.embeddedSuffixes == [".Widget", ".watchkitapp"])
  }

  @Test("Stripping is idempotent and order-independent")
  func idempotentAndOrderIndependent() {
    let once = BundleIdentity.hostBundleID(from: host + ".watchkitapp.Widget")
    #expect(BundleIdentity.hostBundleID(from: once) == once)
    // Not an identifier any target carries, but the loop must not depend on
    // the suffixes arriving in declaration order.
    #expect(BundleIdentity.hostBundleID(from: host + ".Widget.watchkitapp") == host)
  }

  @Test("An identifier with no embedded suffix passes through unchanged")
  func hostPassesThrough() {
    #expect(BundleIdentity.hostBundleID(from: host) == host)
    // The test bundle is its own host: it opens in-memory containers and
    // never shares a store, so its own group is the correct answer.
    #expect(BundleIdentity.hostBundleID(from: host + "Tests") == host + "Tests")
  }

  @Test("A missing identifier yields the bare prefixes, which is the historical fallback")
  func emptyIdentifier() {
    // `Bundle.main.bundleIdentifier ?? ""` — the group becomes "group." and
    // UserDefaults(suiteName:) then falls back to .standard in AppGroup.
    #expect(BundleIdentity.hostBundleID(from: "") == "")
    #expect(BundleIdentity.appGroupIdentifier(hostBundleID: "") == "group.")
  }

  // MARK: - Which process wrote a breadcrumb

  @Test(
    "A breadcrumb names its process by what it carries past the host",
    arguments: [
      ("", "app"),
      (".Widget", "Widget"),
      (".watchkitapp", "watchkitapp"),
      (".watchkitapp.Widget", "watchkitapp.Widget"),
    ]
  )
  func processLabels(suffix: String, label: String) {
    #expect(BundleIdentity.processLabel(bundleID: host + suffix) == label)
  }
}
