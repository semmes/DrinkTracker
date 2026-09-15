import Foundation

/// The two settings the phone mirrors to a paired watch (watch Phase 2,
/// ADR-0041): the region every figure is expressed in, and what the counter's
/// ＋ logs. Nothing else crosses this channel — the log itself travels through
/// the user's own CloudKit database, and this payload never carries a row.
///
/// Both values are per device by construction (`AppSettings` stores them in
/// the App Group defaults and deliberately not in iCloud, because two people
/// can share an iCloud account). A paired watch is the same person on the same
/// wrist, so for it the values must cross: without them the wrist computes US
/// standard drinks for a UK user (PRD invariant 3) and its ＋ can log a
/// different drink than the phone's ＋ (invariant 1).
///
/// The wire form is a property-list dictionary, which is what
/// `WCSession.updateApplicationContext` carries. Encoding and decoding live
/// here, in the domain package, so the two sides cannot disagree about the
/// shape and so the codec is tier-1 tested. A payload that fails to decode is
/// `nil`, and the receiver keeps what it has: a watch that briefly read an
/// empty context and reverted to the US default would be a worse failure than
/// one that kept a stale but correct region.
public struct WatchContext: Equatable, Sendable {
  /// Bumped when the dictionary's shape changes. A receiver that sees another
  /// version keeps what it has rather than guessing at the fields.
  public static let version = 1

  /// The region the phone computes with — its explicit choice, or the US
  /// fallback it applies when none was made. The watch mirrors the phone's
  /// arithmetic, not its settings screen, so the fallback crosses as a region.
  public let region: Region
  public let counterSeed: DrinkDraft.CountSeed
  /// When the phone built this payload. Application contexts are
  /// latest-value-wins on the wire; this is for diagnostics and for the
  /// watch's "has a context ever arrived" question, never for ordering.
  public let sentAt: Date

  public init(region: Region, counterSeed: DrinkDraft.CountSeed, sentAt: Date) {
    self.region = region
    self.counterSeed = counterSeed
    self.sentAt = sentAt
  }

  private enum Key {
    static let version = "version"
    static let region = "region"
    static let counterSeed = "counterSeed"
    static let sentAt = "sentAt"
  }

  /// The wire form: only property-list types (`Int`, `String`, `Double`), which
  /// is the whole of what an application context may carry.
  public var dictionary: [String: Any] {
    [
      Key.version: Self.version,
      Key.region: region.rawValue,
      Key.counterSeed: counterSeed.rawValue,
      Key.sentAt: sentAt.timeIntervalSince1970,
    ]
  }

  /// `nil` for a missing key, a foreign version, or a value that does not name
  /// a known region or seed. Extra keys are ignored, so a newer phone can add
  /// fields without breaking an older watch that only reads these.
  public init?(dictionary: [String: Any]) {
    guard
      let version = dictionary[Key.version] as? Int, version == Self.version,
      let regionRaw = dictionary[Key.region] as? String,
      let region = Region(rawValue: regionRaw),
      let seedRaw = dictionary[Key.counterSeed] as? String,
      let counterSeed = DrinkDraft.CountSeed(rawValue: seedRaw),
      let sentAt = dictionary[Key.sentAt] as? Double
    else {
      return nil
    }
    self.init(region: region, counterSeed: counterSeed, sentAt: Date(timeIntervalSince1970: sentAt))
  }
}
