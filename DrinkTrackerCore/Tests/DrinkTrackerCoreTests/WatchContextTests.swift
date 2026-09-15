import Foundation
import Testing

@testable import DrinkTrackerCore

/// The settings bridge's codec (watch Phase 2, ADR-0041), pinned at tier 1 so
/// the phone and the watch cannot disagree about the wire form, and so the
/// one rule that matters — an unreadable payload decodes to nothing, never to
/// a default — is a test rather than a comment.
@Suite("Watch context")
struct WatchContextTests {

  private let sentAt = Date(timeIntervalSince1970: 1_700_000_000)

  private func valid() -> [String: Any] {
    WatchContext(region: .unitedKingdom, counterSeed: .usualDrink, sentAt: sentAt).dictionary
  }

  @Test(
    "Every region and every seed round-trip through the dictionary form",
    arguments: Region.allCases, DrinkDraft.CountSeed.allCases
  )
  func roundTrip(region: Region, seed: DrinkDraft.CountSeed) {
    let context = WatchContext(region: region, counterSeed: seed, sentAt: sentAt)
    #expect(WatchContext(dictionary: context.dictionary) == context)
  }

  @Test("The wire form holds only property-list types, which is all an application context may carry")
  func propertyListTypesOnly() {
    for (key, value) in valid() {
      #expect(value is String || value is Int || value is Double, "\(key) is \(type(of: value))")
    }
  }

  @Test("The version is 1, and a missing or foreign version means keep what you have")
  func version() {
    #expect(WatchContext.version == 1)
    var payload = valid()
    payload["version"] = 2
    #expect(WatchContext(dictionary: payload) == nil)
    payload["version"] = "1"
    #expect(WatchContext(dictionary: payload) == nil)
    payload.removeValue(forKey: "version")
    #expect(WatchContext(dictionary: payload) == nil)
  }

  @Test("A missing or unknown region is refused, never defaulted to the US")
  func region() {
    var payload = valid()
    payload["region"] = "mars"
    #expect(WatchContext(dictionary: payload) == nil)
    payload["region"] = 7
    #expect(WatchContext(dictionary: payload) == nil)
    payload.removeValue(forKey: "region")
    #expect(WatchContext(dictionary: payload) == nil)
  }

  @Test("A missing or unknown counter seed is refused, never defaulted")
  func counterSeed() {
    var payload = valid()
    payload["counterSeed"] = "favouriteDrink"
    #expect(WatchContext(dictionary: payload) == nil)
    payload.removeValue(forKey: "counterSeed")
    #expect(WatchContext(dictionary: payload) == nil)
  }

  @Test("A missing or non-numeric sentAt is refused")
  func sentAtField() {
    var payload = valid()
    payload["sentAt"] = "yesterday"
    #expect(WatchContext(dictionary: payload) == nil)
    payload.removeValue(forKey: "sentAt")
    #expect(WatchContext(dictionary: payload) == nil)
  }

  @Test("An empty context — what a watch reads before the phone has ever sent one — is nothing, not a default")
  func emptyContext() {
    #expect(WatchContext(dictionary: [:]) == nil)
  }

  @Test("Extra keys are ignored, so a newer phone can add fields an older watch does not read")
  func extraKeysIgnored() {
    var payload = valid()
    payload["sessionSnapshot"] = ["someday": true]
    #expect(WatchContext(dictionary: payload)?.region == .unitedKingdom)
  }
}
