import Foundation
import Testing

@testable import DrinkTrackerCore

/// The save's decision about Health, every branch (ADR-0016's second
/// amendment). The HealthKit half — what `deleteSample` answers for a real
/// sample — cannot be reached here and is tier 4.
@Suite("Health sample retirement")
struct HealthSampleRetirementTests {

  private let rowSample = UUID()
  private let valueSample = UUID()

  // MARK: - Which sample to retire

  @Test("With a stored row, the row's sample is the one to retire")
  func rowSampleWins() {
    let decision = HealthSampleRetirement(existingSampleID: rowSample, incomingSampleID: valueSample)
    #expect(decision.sampleToRetire == rowSample)
  }

  @Test("An edit's draft carries no sample; the row's is still retired")
  func rowSampleWhenValueHasNone() {
    let decision = HealthSampleRetirement(existingSampleID: rowSample, incomingSampleID: nil)
    #expect(decision.sampleToRetire == rowSample)
  }

  @Test("Remove then Undo: the row is gone, so the value's own sample is the one to retire")
  func valueSampleWhenRowIsGone() {
    let decision = HealthSampleRetirement(existingSampleID: nil, incomingSampleID: valueSample)
    #expect(decision.sampleToRetire == valueSample)
  }

  @Test("A new drink, or a widget row backfill has not reached, has nothing to retire")
  func nothingToRetire() {
    let decision = HealthSampleRetirement(existingSampleID: nil, incomingSampleID: nil)
    #expect(decision.sampleToRetire == nil)
    // Nothing was asked, so every answer resolves the same way.
    for outcome in [HealthSampleRetirement.Outcome.retired, .foreign, .kept] {
      #expect(decision.resolution(after: outcome) == .writeFresh)
    }
  }

  // MARK: - What the row keeps

  @Test("Retired frees the slot: write a replacement sample")
  func retiredWritesFresh() {
    let decision = HealthSampleRetirement(existingSampleID: rowSample, incomingSampleID: nil)
    #expect(decision.resolution(after: .retired) == .writeFresh)
  }

  @Test("Foreign keeps the other app's id and writes nothing")
  func foreignKeepsID() {
    let decision = HealthSampleRetirement(existingSampleID: rowSample, incomingSampleID: nil)
    #expect(decision.resolution(after: .foreign) == .keep(rowSample))
  }

  @Test("Kept (unauthorized, or the delete failed) keeps the id and writes nothing")
  func keptKeepsID() {
    let decision = HealthSampleRetirement(existingSampleID: rowSample, incomingSampleID: nil)
    #expect(decision.resolution(after: .kept) == .keep(rowSample))
  }

  // MARK: - The two undo scenarios end to end

  @Test("Undoing an adopted import keeps its foreign id: Health is untouched, the dedup key survives")
  func undoneAdoptionKeepsForeignID() {
    // The row was hard-deleted; the undo bar holds the value with the other
    // app's sample id. Health refuses the delete of a foreign sample.
    let decision = HealthSampleRetirement(existingSampleID: nil, incomingSampleID: valueSample)
    #expect(decision.sampleToRetire == valueSample)
    #expect(decision.resolution(after: .foreign) == .keep(valueSample))
  }

  @Test("Undoing a Tallyist-owned drink writes a fresh sample, since the delete already retired the old one")
  func undoneOwnDrinkWritesFresh() {
    // Health finds nothing under the old id and answers `.retired`.
    let decision = HealthSampleRetirement(existingSampleID: nil, incomingSampleID: valueSample)
    #expect(decision.sampleToRetire == valueSample)
    #expect(decision.resolution(after: .retired) == .writeFresh)
  }

  @Test("Undoing while Health is unavailable keeps pointing at the sample that is still there")
  func undoneWhileUnauthorizedKeepsID() {
    // The delete could not retire the sample (`.kept`), so it is still in
    // Health; the undo must not queue the row for a second sample.
    let decision = HealthSampleRetirement(existingSampleID: nil, incomingSampleID: valueSample)
    #expect(decision.resolution(after: .kept) == .keep(valueSample))
  }
}
