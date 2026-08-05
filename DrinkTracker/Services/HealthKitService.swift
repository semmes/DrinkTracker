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
    if !HKHealthStore.isHealthDataAvailable() {
      authorization = .unavailable
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

  /// Removes a previously written sample, used when an entry is edited or deleted.
  func deleteSample(id: UUID) async {
    guard authorization == .authorized else { return }
    let predicate = HKQuery.predicateForObject(with: id)
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.quantitySample(type: beverageType, predicate: predicate)],
      sortDescriptors: []
    )
    guard let samples = try? await descriptor.result(for: store), !samples.isEmpty else {
      return
    }
    try? await store.delete(samples)
  }

  // "DrinkTrackerStandardDrinks" existed as a second key but never shipped a
  // sample: the value passed for it was the crashing method reference above, so
  // every save that would have written it threw instead. No compatibility to
  // keep — and per the comment in save(), it was the wrong fact to freeze anyway.
  private static let gramsOfAlcoholKey = "DrinkTrackerGramsOfAlcohol"
}
