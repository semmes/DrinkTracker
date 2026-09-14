import Foundation

/// The identities every process of the app derives from its own bundle
/// identifier (PRD invariant 4).
///
/// The App Group and the iCloud container are the host app's identifier under
/// a prefix, and each embedded target's identifier is the host's plus a
/// suffix, so the host is recovered by stripping the suffixes it could carry.
/// A derivation rather than four literals, because a literal that drifts from
/// the entitlement does not fail the build — it hands two processes two
/// stores, and the only symptom is a widget or a complication stuck on a stale
/// zero. This is the pure half of `Shared/AppGroup.swift`, here so it can be
/// pinned at tier 1 without a running bundle.
public enum BundleIdentity {
  /// The suffixes an embedded target adds to its host's identifier, as the
  /// project's targets declare them: `<host>.Widget` for the home-screen
  /// widget, `<host>.watchkitapp` for the watch app, and — because they nest —
  /// `<host>.watchkitapp.Widget` for the watch complication. Stripping repeats
  /// until nothing matches, so the order here is not load-bearing.
  public static let embeddedSuffixes = [".Widget", ".watchkitapp"]

  /// The host app's bundle identifier for any process in the app: the
  /// identifier itself for the app, or with every embedded suffix removed.
  public static func hostBundleID(from bundleID: String) -> String {
    var id = bundleID
    var stripped = true
    while stripped {
      stripped = false
      for suffix in embeddedSuffixes where id.hasSuffix(suffix) {
        id = String(id.dropLast(suffix.count))
        stripped = true
      }
    }
    return id
  }

  /// `group.<host>` — what every target's entitlements declare as
  /// `group.$(BUNDLE_ID_PREFIX).DrinkTracker`.
  public static func appGroupIdentifier(hostBundleID: String) -> String {
    "group." + hostBundleID
  }

  /// `iCloud.<host>` — the container the entitlements declare as
  /// `iCloud.$(BUNDLE_ID_PREFIX).DrinkTracker`.
  public static func iCloudContainerIdentifier(hostBundleID: String) -> String {
    "iCloud." + hostBundleID
  }
}
