import CoreData
import DrinkTrackerCore
import Foundation
import SwiftData

/// The App Group that lets the app, its widget, the watch app and its
/// complication see the same drink log and the same region setting — one group
/// per device, since a group container is per-device.
///
/// Every target carries this identifier in its entitlements. Everything shared
/// between them — the SwiftData store and `AppSettings` — is anchored here rather
/// than in each target's private container.
enum AppGroup {
  /// Derived from the running bundle rather than hardcoded.
  ///
  /// The entitlements declare `group.$(BUNDLE_ID_PREFIX).DrinkTracker`, which is
  /// built from the same prefix as the bundle identifiers in `Signing.xcconfig`.
  /// Computing it here keeps a literal from drifting out of step with that value
  /// — a mismatch wouldn't fail to build, it would just silently give two
  /// processes two different stores.
  ///
  /// Each embedded target's bundle id is its host's plus a suffix (`.Widget`,
  /// `.watchkitapp`, `.watchkitapp.Widget`), so every process strips those to
  /// arrive at the same group as the app. The stripping is `BundleIdentity` in
  /// the core package, pinned at tier 1 for all four identifiers.
  static let identifier: String = BundleIdentity.appGroupIdentifier(hostBundleID: hostBundleID)

  /// The iCloud container, derived the same way the App Group is.
  ///
  /// The entitlement declares `iCloud.$(BUNDLE_ID_PREFIX).DrinkTracker`, which is
  /// the host app's bundle identifier with an `iCloud.` prefix — so this computes
  /// it rather than repeating the literal, for the same reason `identifier` does.
  static var iCloudContainerIdentifier: String {
    BundleIdentity.iCloudContainerIdentifier(hostBundleID: hostBundleID)
  }

  /// The host app's bundle identifier, whichever of its processes is running.
  private static var hostBundleID: String {
    BundleIdentity.hostBundleID(from: Bundle.main.bundleIdentifier ?? "")
  }

  /// Defaults visible to both targets.
  ///
  /// Falls back to `.standard` if the group is unavailable, which happens when the
  /// entitlement isn't provisioned. The app still runs in that case; the widget
  /// just won't observe a region change until signing is set up properly.
  static var defaults: UserDefaults {
    UserDefaults(suiteName: identifier) ?? .standard
  }

  /// Whether the shared container is actually reachable.
  ///
  /// Useful as a diagnostic: if this is false, the app and widget are silently
  /// reading different stores.
  static var isAvailable: Bool {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
  }
}

// MARK: - Diagnostics

/// A breadcrumb the widget extension can leave for the app to read.
///
/// The extension is a separate, short-lived process whose console output is
/// effectively unreadable from the simulator, so this is the practical way to see
/// whether a widget button actually ran. Read it with
/// `AppGroup.defaults.string(forKey: Diagnostics.lastWidgetLogKey)`.
enum Diagnostics {
  static let lastWidgetLogKey = "lastWidgetLog"

  /// The process a breadcrumb is being written from — `app`, `Widget`,
  /// `watchkitapp`, `watchkitapp.Widget`.
  static var processLabel: String {
    BundleIdentity.processLabel(bundleID: Bundle.main.bundleIdentifier ?? "unknown")
  }

  /// Stamped with the process, the date and the time. Without them, a later
  /// tap that ran would overwrite the evidence of an earlier one that did not,
  /// and no reading could say which was which — the 2026-09-16 device run.
  ///
  /// Also appended to the timeline, so an intent that ran shows *where it ran
  /// in order* — beside the app activations and widget builds around it —
  /// rather than only as the last value of one key.
  static func record(_ step: String) {
    AppGroup.defaults.set(
      Breadcrumb.stamped(step, process: processLabel, at: .now),
      forKey: lastWidgetLogKey
    )
    appendTimeline("intent: \(step)")
  }

  /// The last thing the widget's log intent did, if it has ever run.
  static var lastWidgetLog: String? {
    AppGroup.defaults.string(forKey: lastWidgetLogKey)
  }

  static let intentBuildKey = "lastIntentBuild"

  /// Records that the widget's `LogOneDrinkIntent` was *constructed*, and by
  /// which process.
  ///
  /// Separate key from `lastWidgetLog` on purpose: construction and execution are
  /// different events, and one overwriting the other is what made the last round of
  /// this inconclusive. Together they bisect the remaining possibilities —
  ///
  /// - build absent → the widget never rendered its buttons at all
  /// - build present, `lastWidgetLog` absent → the tap never reached `perform()`,
  ///   which is dispatch or parameter resolution
  /// - both present → the intent ran, and the fault is in what it did
  ///
  /// Diagnostic scaffolding. It writes on every timeline render, which is why it
  /// records something cheap.
  static func recordIntentBuild(_ description: String) {
    AppGroup.defaults.set(
      Breadcrumb.stamped(description, process: processLabel, at: .now),
      forKey: intentBuildKey
    )
  }

  static let timelineKey = "diagnosticTimeline"

  /// How many lines the timeline keeps.
  static let timelineLimit = 20

  /// A short, ordered record of the events that decide what the home-screen
  /// widget shows: each intent step (`record`), each widget build and what it
  /// read, each reload the app asks for and why, each CloudKit import that
  /// fails, and each time the app comes to the front.
  ///
  /// A list rather than a value, because the act of reading a single value
  /// overwrites it — opening the app to look is an app activation.
  ///
  /// **How to read a ＋ tap that seemed to do nothing** (ADR-0047). A tap that
  /// ran shows `intent: entered (one-drink) · Widget` at the time of the tap.
  /// A tap that landed outside the ＋ and opened the app shows `app active`
  /// at that time and no `intent:` line — and *not* the absence of a widget
  /// build, because the app asks the widget to redraw for several reasons of
  /// its own around an activation. A tap that shows neither never reached the
  /// app or the intent. The timeline cannot tell a missed tap from opening the
  /// app on purpose; the time of the tap is what separates them.
  ///
  /// What it cannot show: a widget whose App Group does not resolve writes to
  /// its own private defaults, which this list is not — so that failure is the
  /// glyph on the widget with no widget lines here at all. And it is written
  /// from two processes with no lock, so two writes in the same instant can
  /// drop a line. Diagnostics, not a record.
  static func appendTimeline(_ event: String) {
    let line = Breadcrumb.stamped(event, process: processLabel, at: .now)
    let lines = AppGroup.defaults.stringArray(forKey: timelineKey) ?? []
    AppGroup.defaults.set(
      Breadcrumb.appending(line, to: lines, limit: timelineLimit),
      forKey: timelineKey
    )
  }

  static var timeline: [String] {
    AppGroup.defaults.stringArray(forKey: timelineKey) ?? []
  }

  static var lastIntentBuild: String? {
    AppGroup.defaults.string(forKey: intentBuildKey)
  }

  static let storeModeKey = "storeMode"

  /// Which configuration the shared store was last opened with.
  ///
  /// "requested" is doing real work in that string. Opening with CloudKit enabled
  /// says nothing about whether mirroring then succeeded — see `cloudKitStatus`.
  ///
  /// Both degraded modes are invisible from the UI otherwise: losing CloudKit
  /// looks exactly like "nothing has synced yet", and losing the store entirely
  /// looks like an empty log. Recording the mode is what makes them
  /// distinguishable after the fact.
  ///
  /// **Only the two apps' launches write it** — `DrinkTrackerApp.init` and
  /// `DrinkTrackerWatchApp.init`, with the mode `SharedModelContainer.open()`
  /// hands back. The key is last-writer-wins across every process in the
  /// group, and `isStoreInMemory` — the one release-visible degraded state
  /// (ADR-0004) — reads it, so it has to mean *how this launch opened the
  /// store*. When `open()` itself wrote it, any later open overwrote that: an
  /// extension a second after the app fell back to memory, or a Siri intent
  /// running in the app's own process, would erase the warning while the app
  /// kept writing to memory (ADR-0047).
  static func recordStoreMode(_ mode: String) {
    AppGroup.defaults.set(mode, forKey: storeModeKey)
  }

  static var storeMode: String? {
    AppGroup.defaults.string(forKey: storeModeKey)
  }

  static let cloudKitStatusKey = "cloudKitStatus"

  /// Whether CloudKit mirroring is *actually* working, as opposed to requested.
  ///
  /// These are different questions, which a device run made obvious. Opening the
  /// container with `cloudKitDatabase: .automatic` succeeds even with no iCloud
  /// account: `ModelContainer(…)` returns normally and `NSCloudKitMirroringDelegate`
  /// fails afterwards, asynchronously, with `CKAccountStatusNoAccount`. So
  /// `storeMode` can only ever report what was asked for — it is written before
  /// the answer exists.
  ///
  /// This is the answer, and it has to be fetched separately.
  static func recordCloudKitStatus(_ status: String) {
    AppGroup.defaults.set(status, forKey: cloudKitStatusKey)
  }

  static var cloudKitStatus: String? {
    AppGroup.defaults.string(forKey: cloudKitStatusKey)
  }

  static let cloudKitStatusCodeKey = "cloudKitStatusCode"

  /// Machine-readable form of the same answer, for the release-facing Settings
  /// row — UI copy maps from this rather than parsing the diagnostic string.
  static func recordCloudKitStatusCode(_ code: String) {
    AppGroup.defaults.set(code, forKey: cloudKitStatusCodeKey)
  }

  static var cloudKitStatusCode: String? {
    AppGroup.defaults.string(forKey: cloudKitStatusCodeKey)
  }

  static let watchContextSentKey = "lastWatchContextSent"

  /// On the phone: the last publish of the settings bridge (watch Phase 2,
  /// ADR-0041) — what was sent and when, or what went wrong. The bridge is a
  /// silent channel by design (latest value wins, delivered whenever the watch
  /// is next reachable), so this is the only way to see it did anything.
  static func recordWatchContextSent(_ description: String) {
    AppGroup.defaults.set(description, forKey: watchContextSentKey)
  }

  static var lastWatchContextSent: String? {
    AppGroup.defaults.string(forKey: watchContextSentKey)
  }

  static let watchContextReceivedKey = "lastWatchContextReceived"

  /// On the watch: when the phone built the last context the watch applied.
  /// `nil` means no context has ever arrived, which is how the counter (Phase
  /// 3) tells "the region has not been set yet" from "the US, by choice" —
  /// `AppSettings.storedRegion()` alone cannot, since it falls back to the US.
  static func recordWatchContextReceived(sentAt: Date) {
    AppGroup.defaults.set(sentAt.timeIntervalSince1970, forKey: watchContextReceivedKey)
  }

  static var lastWatchContextReceived: Date? {
    (AppGroup.defaults.object(forKey: watchContextReceivedKey) as? Double)
      .map(Date.init(timeIntervalSince1970:))
  }

  static let syncSucceededKey = "lastSyncSucceededAt"
  static let syncFailureKey = "lastSyncFailure"

  /// When CloudKit mirroring last moved data on this device, either way.
  ///
  /// The third question, and the only one that is actually about *syncing*.
  /// `storeMode` says what was asked for; `cloudKitStatus` says whether the
  /// account exists. Neither says whether a byte ever moved, and the owner's
  /// evening of 2026-09-15 is what that gap looks like from outside: two
  /// devices drifting apart while the Settings row said "Syncing with
  /// iCloud", which it printed from the account status alone.
  ///
  /// Written from `NSPersistentCloudKitContainer`'s own event notification,
  /// which reports each import and export with an end date and a result.
  static func recordSyncSuccess(at date: Date) {
    AppGroup.defaults.set(date.timeIntervalSince1970, forKey: syncSucceededKey)
    AppGroup.defaults.removeObject(forKey: syncFailureKey)
  }

  static var lastSyncSucceededAt: Date? {
    (AppGroup.defaults.object(forKey: syncSucceededKey) as? Double)
      .map(Date.init(timeIntervalSince1970:))
  }

  /// The last mirroring failure, kept until something succeeds. A transient
  /// failure that the next retry clears leaves nothing behind, which is what
  /// makes a value here worth reading.
  static func recordSyncFailure(_ description: String) {
    AppGroup.defaults.set(description, forKey: syncFailureKey)
  }

  static var lastSyncFailure: String? {
    AppGroup.defaults.string(forKey: syncFailureKey)
  }

  /// Whether anything has ever synced on this device. The difference between
  /// "your log follows your iCloud account" as a promise and as a fact.
  static var hasEverSynced: Bool { lastSyncSucceededAt != nil }

  /// Whether the store fell back to memory — the one state where nothing at all
  /// is being saved. Surfaced in release builds, not just diagnostics.
  static var isStoreInMemory: Bool {
    storeMode?.hasPrefix("IN MEMORY") == true
  }

  /// Whether the diagnostics UI should be shown.
  ///
  /// Debug builds always. **TestFlight builds too**, which is the point: the widget
  /// dispatch question can only be answered on a real device, and a tester holding a
  /// Release build has no way to read the breadcrumb — so the only report they can
  /// make is "nothing happened", which is precisely the answer that distinguishes
  /// nothing. A build that can't be diagnosed can't be tested.
  ///
  /// App Store builds never. TestFlight is identified by its sandbox receipt, which
  /// is the standard signal and the only one that separates TestFlight from a
  /// production install — both are Release, so `#if DEBUG` cannot tell them apart.
  static var isVisible: Bool {
    #if DEBUG
    return true
    #else
    return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    #endif
  }
}

// MARK: - Shared store

enum SharedModelContainer {
  /// Built from the versioned schema so this and `CurrentSchema` cannot name
  /// different model sets — see `SchemaVersions.swift` for the version story.
  static let schema = Schema(versionedSchema: CurrentSchema.self)

  /// Where the store lives.
  ///
  /// Identical for every configuration below. The App Group is what makes the app
  /// and the widget one app, so it is never the thing a fallback gives up.
  private static var groupContainer: ModelConfiguration.GroupContainer {
    AppGroup.isAvailable ? .identifier(AppGroup.identifier) : .automatic
  }

  private static func configuration(
    cloudKit: ModelConfiguration.CloudKitDatabase
  ) -> ModelConfiguration {
    ModelConfiguration(schema: schema, groupContainer: groupContainer, cloudKitDatabase: cloudKit)
  }

  /// Builds the container every process opens.
  ///
  /// Deliberately takes no options, so every process opens the store with
  /// *identical* configuration (PRD invariant 5) and no call site can drift.
  ///
  /// **What happens in a process with no iCloud container entitlement** — the
  /// home-screen widget, the only such process: `.automatic` opens on the
  /// first rung *without mirroring*, and its writes land and persist. On
  /// 2026-09-16 the simulator's widget extension wrote three `DrinkEntry` rows
  /// whose persistent-history transactions name
  /// `com.shawnsemmes.DrinkTracker.Widget`, and the app displayed them. The app's
  /// own mirroring exports such rows from persistent history the next time it
  /// runs (TN3163). An earlier comment here (6f759f6) said writes from such a
  /// process "fail silently". That was never observed: it was written while the
  /// widget's one-tap log was failing for a different reason, which 17853f3
  /// found four days later — a non-optional `@Parameter` with no default, which
  /// abandoned the tap during resolution, before `perform()` was entered. It is
  /// retracted (ADR-0004, 2026-09-16 amendment). The argument that still points
  /// the same way is TN3164's: one process manages sync, which is why the widget
  /// is not given the entitlement (ADR-0047).
  ///
  /// That is also why the CloudKit fallback lives *here* rather than at the call
  /// site. The app used to carry its own fallback that dropped the group container
  /// as well as CloudKit, while the widget had no fallback at all — so one iCloud
  /// failure sent the app to a private store and left the widget with no store,
  /// which is precisely the silent split this type exists to prevent. One ladder,
  /// every process.
  ///
  /// Losing sync is a degradation; losing the widget is a broken feature. So the
  /// fallback keeps the App Group and gives up only the mirroring.
  ///
  /// **Unverified (Tier 4, see docs/PRD.md §4):** whether a store that *was*
  /// mirrored reopens cleanly without CloudKit. Both processes now run the same
  /// ladder, so they agree at any given moment, but two processes opening the
  /// store while iCloud availability is changing could still land on different
  /// rungs. Confirming that needs a device.
  static func make() throws -> ModelContainer {
    try open().container
  }

  /// `make()`, plus which rung the store opened on. Records nothing: the two
  /// apps' launches write `Diagnostics.storeMode` with the mode this returns,
  /// and every other caller only reads it (see `recordStoreMode`).
  static func open() throws -> (container: ModelContainer, mode: String) {
    do {
      let container = try ModelContainer(
        for: schema,
        migrationPlan: DrinkTrackerMigrationPlan.self,
        configurations: configuration(cloudKit: .automatic)
      )
      return (container, "shared, CloudKit requested")
    } catch {
      let container = try ModelContainer(
        for: schema,
        migrationPlan: DrinkTrackerMigrationPlan.self,
        configurations: configuration(cloudKit: .none)
      )
      return (container, "shared, no CloudKit — \(error)")
    }
  }
}

/// Watches what CloudKit mirroring actually does, and records it through
/// `Diagnostics`.
///
/// SwiftData mirrors through `NSPersistentCloudKitContainer`, which posts an
/// event for every setup, import and export — twice each, once when it starts
/// and once when it ends, the ending one carrying a result. Observing it needs
/// no container handle, no new entitlement and no polling: it is the same
/// plain `NotificationCenter` observation the watch app already runs for
/// `.NSPersistentStoreRemoteChange`.
///
/// This exists because the app had no way to tell a working sync from a
/// stalled one. Three questions were being conflated: what the store was
/// opened with (`Diagnostics.storeMode`), whether an iCloud account exists
/// (`cloudKitStatus`, one round trip against the local daemon), and whether
/// data has actually moved. Only the third is syncing, and nothing measured
/// it — so Settings printed "Syncing with iCloud" on the strength of the
/// second, which is how two devices could drift apart for an evening while
/// the app said they were in step.
///
/// It records and does not act. Nothing here retries, forces or schedules
/// anything: the transfers are the system's to schedule, this project sets no
/// networking policy at all, and a record that pretended otherwise would be
/// the same kind of claim it exists to retire.
enum CloudKitSyncMonitor {
  nonisolated(unsafe) private static var observer: NSObjectProtocol?

  /// Idempotent, so an app may call it from `init` without guarding.
  static func start() {
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil,
      queue: .main
    ) { note in
      guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
        as? NSPersistentCloudKitContainer.Event else { return }
      // Only the ending half of each pair carries a result.
      guard let endDate = event.endDate else { return }
      record(event, endedAt: endDate)
    }
  }

  private static func record(_ event: NSPersistentCloudKitContainer.Event, endedAt: Date) {
    guard event.succeeded else {
      // A setup failure is the "no account" shape and is worth keeping; so is
      // a failed transfer. Either way the description names the kind, because
      // "export failed" and "import failed" send a reader to different places.
      Diagnostics.recordSyncFailure("\(name(of: event.type)) failed — \(event.error?.localizedDescription ?? "no reason given")")
      return
    }
    // A successful *setup* is not a byte moved: it means the mirroring
    // delegate started, which `storeMode` already claims. Only a transfer
    // counts as having synced.
    switch event.type {
    case .import, .export:
      Diagnostics.recordSyncSuccess(at: endedAt)
    default:
      break
    }
  }

  private static func name(of type: NSPersistentCloudKitContainer.EventType) -> String {
    switch type {
    case .setup: "setup"
    case .import: "import"
    case .export: "export"
    @unknown default: "sync"
    }
  }
}
