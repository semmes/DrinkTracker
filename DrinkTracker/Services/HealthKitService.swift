import DrinkTrackerCore
import Foundation
import HealthKit
import Observation

/// Reads and writes `numberOfAlcoholicBeverages` in Apple Health.
///
/// Every failure path here is deliberately silent to the caller: the log itself
/// lives in SwiftData, so a denied or unavailable Health store degrades the app
/// to local-only rather than blocking the primary action.
@Observable
@MainActor
final class HealthKitService {

  enum Authorization: Equatable {
    case notDetermined
    case authorized
    case denied
    case unavailable
  }

  private(set) var authorization: Authorization = .notDetermined

  private let store = HKHealthStore()

  private var beverageType: HKQuantityType {
    HKQuantityType(.numberOfAlcoholicBeverages)
  }

  init() {
    refreshAuthorization()
  }

  /// Re-derives the stored state from the system's remembered answer, without
  /// prompting.
  ///
  /// HealthKit persists the user's choice across launches, but this service's
  /// state used to be set only by the onboarding prompt — so on every later
  /// launch of an existing install it sat at `.notDetermined`, and the guards
  /// on save, backfill, and import all silently declined. Fresh installs always
  /// looked fine (onboarding ran in the same session), which is exactly how it
  /// escaped device testing. Called from init and on every foregrounding, since
  /// the user can change access in the Health app at any time.
  ///
  /// `authorizationStatus` reports *share* permission; read remains invisible
  /// by design, which is why the import path also accepts `.denied` — a user
  /// can grant read while refusing write.
  func refreshAuthorization() {
    guard HKHealthStore.isHealthDataAvailable() else {
      authorization = .unavailable
      return
    }
    switch store.authorizationStatus(for: beverageType) {
    case .sharingAuthorized:
      authorization = .authorized
    case .sharingDenied:
      authorization = .denied
    case .notDetermined:
      authorization = .notDetermined
    @unknown default:
      authorization = .notDetermined
    }
  }

  /// Fires the system permission sheet. Called from the HealthKit context
  /// screen's Continue button, immediately after the explanatory copy.
  func requestAuthorization() async {
    guard HKHealthStore.isHealthDataAvailable() else {
      authorization = .unavailable
      return
    }
    do {
      try await store.requestAuthorization(
        toShare: [beverageType],
        read: [beverageType]
      )
      // `authorizationStatus` only reports share permission; read access is
      // deliberately opaque in HealthKit. Sharing is what the app needs.
      authorization = store.authorizationStatus(for: beverageType) == .sharingAuthorized
        ? .authorized
        : .denied
    } catch {
      authorization = .denied
    }
  }

  /// Writes one beverage sample. Returns the sample's UUID so an edit can
  /// retract it later, or `nil` if Health is unavailable or not authorized.
  func save(_ drink: LoggedDrink) async -> UUID? {
    guard authorization == .authorized else { return nil }

    // The Health type counts beverages, not standard drinks, so a single logged
    // drink is one beverage. The gram equivalent rides along as metadata — and
    // only the grams: it is the region-free fact, where a "standard drinks"
    // figure would freeze whichever display region was active at write time
    // into an immutable external record (invariant 3, ADR-0002). A reader can
    // derive standard drinks for any region from grams; the reverse loses data.
    //
    // The typed binding is load-bearing. This dictionary is [String: Any], and
    // an unapplied method reference (`drink.standardDrinks` — the region-lens
    // *method*) once type-checked here as a value, crashing every authorized
    // save at HealthKit's runtime validation with "(Function)". `Double` makes
    // that mistake a compile error.
    let grams: Double = drink.gramsOfAlcohol
    let sample = HKQuantitySample(
      type: beverageType,
      quantity: HKQuantity(unit: .count(), doubleValue: 1),
      start: drink.loggedAt,
      end: drink.loggedAt,
      metadata: [
        HKMetadataKeyWasUserEntered: true,
        Self.gramsOfAlcoholKey: grams
      ]
    )

    do {
      try await store.save(sample)
      return sample.uuid
    } catch {
      return nil
    }
  }

  /// What became of a sample the app asked to retire.
  enum RetireOutcome: Equatable {
    /// Gone from Health, or never there — the slot is free for a new sample.
    case retired
    /// Another app wrote it (an adopted import, ADR-0016). Health would refuse
    /// the delete, and the app must not want it: that sample is the other
    /// app's record, and its id is the row's dedup key.
    case foreign
    /// Not authorized right now, or the delete failed. The sample is still
    /// there and the row should keep pointing at it.
    case kept
  }

  /// Removes a previously written sample, used when an entry is edited or
  /// deleted, and says whether it did.
  ///
  /// The answer is what lets `DrinkStore.save` keep an adopted entry's foreign
  /// sample id instead of overwriting it with a fresh Tallyist sample's — the
  /// overwrite doubled the drink in Health and let a re-delivered sample
  /// insert a duplicate row.
  @discardableResult
  func deleteSample(id: UUID) async -> RetireOutcome {
    guard authorization == .authorized else { return .kept }
    let predicate = HKQuery.predicateForObject(with: id)
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: beverageType, predicate: predicate)],
      sortDescriptors: []
    )
    guard let samples = try? await descriptor.result(for: store) else { return .kept }
    guard !samples.isEmpty else { return .retired }
    let ownBundleID = Bundle.main.bundleIdentifier ?? ""
    guard samples.allSatisfy({ $0.sourceRevision.source.bundleIdentifier == ownBundleID }) else {
      return .foreign
    }
    do {
      try await store.delete(samples)
      return .retired
    } catch {
      return .kept
    }
  }

  // "DrinkTrackerStandardDrinks" existed as a second key but never shipped a
  // sample: the value passed for it was the crashing method reference above, so
  // every save that would have written it threw instead. No compatibility to
  // keep — and per the comment in save(), it was the wrong fact to freeze anyway.
  private static let gramsOfAlcoholKey = "DrinkTrackerGramsOfAlcohol"

  // MARK: - Reading other apps' data (ADR-0014, ADR-0025)

  /// What changed in Health since the last look.
  struct ExternalBeverageDelta: Sendable {
    let added: [ExternalBeverageSample]
    let deletedIDs: [UUID]
    /// The anchor this delta advances to, archived. Written by `commit`, not
    /// by the fetch, so a sweep killed mid-application replays what it never
    /// applied instead of skipping it — which matters most on the one-time
    /// re-walk a generation bump triggers.
    fileprivate let anchor: Data
  }

  /// Everything alcohol-related other apps have put into (or removed from)
  /// Health since the previous call. Incremental via a persisted anchor, so the
  /// first call walks all history and later calls return only changes.
  ///
  /// Read authorization is deliberately invisible in HealthKit — a denied read
  /// looks exactly like an empty store — so this is best-effort by design:
  /// attempted whenever Health exists and the permission prompt has been shown,
  /// returning nil only when there is nothing to report. The app's own samples
  /// are filtered out by source; importing them back would double every drink.
  ///
  /// Every external sample comes back, zero-valued ones included: a zero is
  /// another app's record of a no-alcohol day, and the repository turns it
  /// into a marker (ADR-0025). Until 1.2 this dropped zeros here, silently,
  /// which is why the anchor carries a generation — see `anchorGenerationKey`.
  ///
  /// The caller applies the delta and then calls `commit(_:)`; an unapplied
  /// delta advances nothing.
  func fetchExternalChanges() async -> ExternalBeverageDelta? {
    guard authorization == .authorized || authorization == .denied else { return nil }

    let stored = Self.storedAnchor()
    let generationIsCurrent = Self.anchorGenerationIsCurrent
    var addedSamples: [HKQuantitySample] = []
    var deletedIDs: [UUID] = []

    // A stale generation means "walk history again from nothing". A walk
    // from no anchor reports no deletions, though — they exist only relative
    // to an anchor — so drain the outgoing one first, or anything deleted at
    // the source since the last sweep under the old reading would leave a
    // mirror nothing can ever remove.
    if let stored, !generationIsCurrent {
      let drain = HKAnchoredObjectQueryDescriptor(
        predicates: [.quantitySample(type: beverageType)],
        anchor: stored
      )
      guard let drained = try? await drain.result(for: store) else { return nil }
      addedSamples += drained.addedSamples
      deletedIDs += drained.deletedObjects.map(\.uuid)
    }

    let descriptor = HKAnchoredObjectQueryDescriptor(
      predicates: [.quantitySample(type: beverageType)],
      anchor: generationIsCurrent ? stored : nil
    )
    guard let result = try? await descriptor.result(for: store) else { return nil }
    addedSamples += result.addedSamples
    deletedIDs += result.deletedObjects.map(\.uuid)
    guard let anchor = Self.archive(result.newAnchor) else { return nil }

    let ownBundleID = Bundle.main.bundleIdentifier ?? ""
    var seen = Set<UUID>()
    let added = addedSamples.compactMap { sample -> ExternalBeverageSample? in
      guard sample.sourceRevision.source.bundleIdentifier != ownBundleID else { return nil }
      // The drain and the walk overlap; one offer per sample is enough.
      guard seen.insert(sample.uuid).inserted else { return nil }
      let count = sample.quantity.doubleValue(for: .count())
      // HealthKit refuses negative and non-finite quantities at write time, so
      // this guard documents the contract more than it filters; what a count
      // *means* — drinks, or a recorded zero — is the repository's call.
      guard count.isFinite, count >= 0 else { return nil }
      return ExternalBeverageSample(id: sample.uuid, count: count, loggedAt: sample.startDate)
    }
    // Deletions are reported for every source; the repository only acts on ones
    // that mirror external samples, so the app's own log never follows a pruned
    // mirror sample.
    let deleted = Array(Set(deletedIDs))

    guard !added.isEmpty || !deleted.isEmpty else {
      // Nothing to apply, so nothing to lose by advancing now.
      Self.storeAnchor(anchor)
      return nil
    }
    return ExternalBeverageDelta(added: added, deletedIDs: deleted, anchor: anchor)
  }

  /// Records that `delta` has been applied: the anchor advances and the
  /// generation is stamped current. Until this is called the next sweep
  /// offers the same changes again, which dedup makes harmless.
  func commit(_ delta: ExternalBeverageDelta) {
    Self.storeAnchor(delta.anchor)
  }

  /// The anchor lives in the App Group so a reinstall that keeps the group
  /// container resumes instead of re-walking history (dedup makes a re-walk
  /// harmless, just slow).
  private static let anchorKey = "healthImportAnchor"

  /// Which *reading* of Health the stored anchor belongs to.
  ///
  /// An anchor says "everything before this point has been handled", and that
  /// is only true for the rules in force when it was written. Generation 1 —
  /// 1.1's import — dropped zero-valued samples on the floor, so on an
  /// existing install every no-alcohol day another app ever recorded sits
  /// behind the anchor, unreachable. A different generation makes the next
  /// sweep drain the old anchor for its deletions, then walk history from
  /// nothing, once: drinks re-offered by the walk dedup by sample id
  /// (adopted ones included — they keep the id), and the zeros become
  /// markers. Bump it again only when the reading changes again.
  private static let anchorGenerationKey = "healthImportAnchorGeneration"
  private static let currentAnchorGeneration = 2

  private static var anchorGenerationIsCurrent: Bool {
    AppGroup.defaults.integer(forKey: anchorGenerationKey) == currentAnchorGeneration
  }

  /// The stored anchor regardless of generation — the caller decides what a
  /// stale one is still good for.
  private static func storedAnchor() -> HKQueryAnchor? {
    guard let data = AppGroup.defaults.data(forKey: anchorKey) else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
  }

  private static func archive(_ anchor: HKQueryAnchor) -> Data? {
    try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
  }

  private static func storeAnchor(_ anchor: Data) {
    AppGroup.defaults.set(anchor, forKey: anchorKey)
    AppGroup.defaults.set(currentAnchorGeneration, forKey: anchorGenerationKey)
  }
}
