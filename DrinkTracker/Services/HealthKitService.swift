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
  ///
  /// Defined in the core package so the decision `DrinkStore.save` makes on
  /// it — which sample to retire, and what the row keeps afterwards — is a
  /// pure value pinned at tier 1 (`HealthSampleRetirement`). This service is
  /// the only thing that produces one.
  typealias RetireOutcome = HealthSampleRetirement.Outcome

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

  // MARK: - The health pairing's reads (ADR-0048, ADR-0049)

  /// The types the pairing reads: only what the shipped build shows. Resting
  /// heart rate is Phase 3's metric; later phases append theirs. HealthKit
  /// prompts only for types the person has not yet answered, so each
  /// addition's first request shows a sheet listing its own type alone.
  ///
  /// Nothing here is shared. Every one of these is read-only in HealthKit's
  /// own terms as far as this app is concerned, and the pairing writes
  /// nothing anywhere — not to Health, not to the store, not to a cache.
  private static var pairingReadTypes: Set<HKObjectType> {
    [HKQuantityType(.restingHeartRate)]
  }

  /// Fires the system sheet for the pairing's read types, listing only the
  /// ones not yet answered; silent when every one is.
  ///
  /// Deliberately not folded into `requestAuthorization()`: that sheet is the
  /// app's own beverage type, asked for on the Health context screen and
  /// again from the Settings toggle, and a person who never turns a pairing
  /// switch on must never be asked about their heart rate. Only the pairing's
  /// switch and its one-time offer call this (Phase 3).
  ///
  /// Returns nothing and records nothing. A denied read is invisible in
  /// HealthKit by design — `authorizationStatus(for:)` reports sharing only —
  /// so there is no answer to keep, and keeping one would be pretending to
  /// know what the store refuses to say. The next read either returns values
  /// or it returns none; those are the same state to the pairing.
  func requestPairingAuthorization() async {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    try? await store.requestAuthorization(toShare: [], read: Self.pairingReadTypes)
  }

  /// Resting heart rate, one value per calendar day that has one, over the
  /// days of `range` before the day holding `now` — never that day itself
  /// (`HealthPairing.readWindow`, the pairing's retrospective-only rule made
  /// structural). Each element carries the day's average in beats per minute
  /// between the statistic's own start and end — HealthKit's day, anchored on
  /// the window's first day — so `HealthPairing.nightlyValues(of:for:
  /// attribution: .dayAfter, calendar:)` files it, by its middle, under the
  /// night before it. The middle is what makes that robust: which calendar
  /// HealthKit steps its one-day intervals in is not documented, and a bucket
  /// drifting by an hour across a clock change still has its middle on the
  /// right day. Pass the calendar the domain's nights were built with, so
  /// "today" means the same day on both sides.
  ///
  /// The query is HealthKit's own daily statistics — its discrete average,
  /// which for this type is temporally weighted — anchored on the window's
  /// first day in one-day steps: the shape the plan names for the quantity
  /// types, and the one whose cost at a year the owner asked to have measured
  /// rather than estimated. The measurement is the breadcrumb written after
  /// every query (`Diagnostics.recordHealthPairingRead`): the metric, the
  /// window's day count and the wall time, and nothing that came back. No
  /// query, no breadcrumb — a device without Health, or a range with no day
  /// before today, returns empty before asking.
  ///
  /// Empty means no data. A person who denied the read, one who granted it
  /// with nothing recorded, a watch that cannot measure it, a night it was
  /// not worn, a device the data never synced to, a store that threw: one
  /// state, and this returns the same empty array for every one of them,
  /// with no error to distinguish them by. The result is the caller's for one
  /// render; nothing here keeps it. The beverage type's `authorization` is
  /// not consulted — sharing alcohol samples and reading heart rate are
  /// separate answers.
  func restingHeartRate(
    in range: DateInterval,
    endingBefore now: Date,
    calendar: Calendar = .current
  ) async -> [HealthSample] {
    await dailyAverages(
      of: HKQuantityType(.restingHeartRate),
      unit: .count().unitDivided(by: .minute()),
      named: "resting heart rate",
      in: range,
      endingBefore: now,
      calendar: calendar
    )
  }

  /// One daily statistics query, shared by every *discrete* per-day quantity
  /// the pairing reads. Adding a metric is a public method above naming its
  /// type, unit and breadcrumb label — never a second copy of this. Two
  /// mistakes there are Objective-C exceptions, which the `try?` below cannot
  /// catch: asking for a discrete average of a cumulative type, and a unit
  /// the type cannot convert to. The four metrics the plan names are all
  /// discrete; check the header's comment on the identifier before adding
  /// one, because the failure is a crash, not an empty array.
  private func dailyAverages(
    of type: HKQuantityType,
    unit: HKUnit,
    named metric: String,
    in range: DateInterval,
    endingBefore now: Date,
    calendar: Calendar
  ) async -> [HealthSample] {
    guard HKHealthStore.isHealthDataAvailable() else { return [] }
    guard let window = HealthPairing.readWindow(for: range, endingBefore: now, calendar: calendar)
    else { return [] }

    let descriptor = HKStatisticsCollectionQueryDescriptor(
      predicate: .quantitySample(
        type: type,
        predicate: HKQuery.predicateForSamples(
          withStart: window.start, end: window.end, options: [.strictStartDate])
      ),
      options: .discreteAverage,
      anchorDate: window.start,
      intervalComponents: DateComponents(day: 1)
    )

    let started = ContinuousClock.now
    let collection = try? await descriptor.result(for: store)
    let elapsed = ContinuousClock.now - started
    Diagnostics.recordHealthPairingRead(
      metric,
      days: HealthPairing.days(in: window, calendar: calendar),
      seconds: Double(elapsed.components.seconds)
        + Double(elapsed.components.attoseconds) / 1e18
    )
    guard let collection else { return [] }

    // A day with no sample has no average and contributes nothing — absent,
    // never zero, which is what the domain's gate counts on.
    return collection.statistics()
      .compactMap { statistics -> HealthSample? in
        guard
          statistics.startDate < window.end, statistics.endDate > window.start,
          let average = statistics.averageQuantity()
        else { return nil }
        let value = average.doubleValue(for: unit)
        guard value.isFinite else { return nil }
        return HealthSample(start: statistics.startDate, end: statistics.endDate, value: value)
      }
      .sorted { $0.start < $1.start }
  }
}
