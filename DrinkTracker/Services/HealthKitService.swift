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

  // MARK: - Reading other apps' data (ADR-0014)

  /// One external beverage sample, reduced to the facts Health actually has.
  struct ExternalBeverageSample: Sendable {
    let id: UUID
    let count: Double
    let loggedAt: Date
  }

  /// What changed in Health since the last look.
  struct ExternalBeverageDelta: Sendable {
    let added: [ExternalBeverageSample]
    let deletedIDs: [UUID]
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
  func fetchExternalChanges() async -> ExternalBeverageDelta? {
    guard authorization == .authorized || authorization == .denied else { return nil }

    let descriptor = HKAnchoredObjectQueryDescriptor(
      predicates: [.quantitySample(type: beverageType)],
      anchor: Self.loadAnchor()
    )
    guard let result = try? await descriptor.result(for: store) else { return nil }
    Self.storeAnchor(result.newAnchor)

    let ownBundleID = Bundle.main.bundleIdentifier ?? ""
    let added = result.addedSamples.compactMap { sample -> ExternalBeverageSample? in
      guard sample.sourceRevision.source.bundleIdentifier != ownBundleID else { return nil }
      let count = sample.quantity.doubleValue(for: .count())
      guard count > 0 else { return nil }
      return ExternalBeverageSample(id: sample.uuid, count: count, loggedAt: sample.startDate)
    }
    // Deletions are reported for every source; the repository only acts on ones
    // that mirror external samples, so the app's own log never follows a pruned
    // mirror sample.
    let deleted = result.deletedObjects.map(\.uuid)

    guard !added.isEmpty || !deleted.isEmpty else { return nil }
    return ExternalBeverageDelta(added: added, deletedIDs: deleted)
  }

  /// The anchor lives in the App Group so a reinstall that keeps the group
  /// container resumes instead of re-walking history (dedup makes a re-walk
  /// harmless, just slow).
  private static let anchorKey = "healthImportAnchor"

  private static func loadAnchor() -> HKQueryAnchor? {
    guard let data = AppGroup.defaults.data(forKey: anchorKey) else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
  }

  private static func storeAnchor(_ anchor: HKQueryAnchor) {
    guard let data = try? NSKeyedArchiver.archivedData(
      withRootObject: anchor,
      requiringSecureCoding: true
    ) else { return }
    AppGroup.defaults.set(data, forKey: anchorKey)
  }
}
