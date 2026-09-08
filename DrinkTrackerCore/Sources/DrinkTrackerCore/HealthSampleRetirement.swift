import Foundation

/// The one decision a save makes about Apple Health, as a value (ADR-0016 and
/// its amendments): which sample, if any, to retire before writing a
/// replacement — and, once Health has answered, whether the row keeps the id
/// it had or takes a fresh sample's.
///
/// Two inputs, because a save can arrive with the row still in the store
/// (an edit) or with the row already gone (Remove → Undo re-saves the
/// `LoggedDrink` value *after* the hard delete). The stored row's sample id is
/// the truth when there is a row; when there is none, the value's own id is
/// the only record of which sample the entry mirrors. Deciding from the row
/// alone was the fault: an undone adopted import had no row to read, so the
/// save took the fresh-sample path, wrote a Tallyist sample beside the other
/// app's, and overwrote the foreign id that dedups a re-delivered sample —
/// a doubled drink in Health, and a duplicate row on the next re-walk.
///
/// Pure so it can be pinned at tier 1. The HealthKit half — what
/// `deleteSample` actually answers for a given sample — is tier 4 by nature.
public struct HealthSampleRetirement: Equatable, Sendable {

  /// What became of a sample the app asked Health to retire.
  public enum Outcome: Equatable, Sendable {
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

  /// What the row's sample id becomes after the save.
  public enum Resolution: Equatable, Sendable {
    /// Write a new sample for the drink; the row takes its id (nil if Health
    /// declines, which queues the row for backfill).
    case writeFresh
    /// Write nothing; the row keeps pointing at this sample.
    case keep(UUID)
  }

  /// The sample to ask Health to retire before writing, if any.
  ///
  /// The stored row's id when there is a row, else the incoming value's own.
  /// Nil means there is nothing to retire and the save writes fresh without
  /// asking — a new drink, or a row the widget logged that backfill has not
  /// reached yet.
  public let sampleToRetire: UUID?

  /// - Parameters:
  ///   - existingSampleID: the sample id on the stored row with the drink's id,
  ///     or nil when no such row exists.
  ///   - incomingSampleID: the sample id carried by the `LoggedDrink` value
  ///     being saved. A draft's `makeLoggedDrink` never sets one; only a value
  ///     read from the store — the undo bar's — can.
  public init(existingSampleID: UUID?, incomingSampleID: UUID?) {
    sampleToRetire = existingSampleID ?? incomingSampleID
  }

  /// The row's sample id after Health has answered about `sampleToRetire`.
  ///
  /// `.retired` frees the slot, so the save writes a replacement. `.foreign`
  /// and `.kept` both mean the sample is still in Health and still the row's:
  /// keep its id, write nothing. With nothing to retire the answer is
  /// `.writeFresh` whatever `outcome` says, since there was nothing to ask.
  public func resolution(after outcome: Outcome) -> Resolution {
    guard let sampleToRetire else { return .writeFresh }
    switch outcome {
    case .retired:
      return .writeFresh
    case .foreign, .kept:
      return .keep(sampleToRetire)
    }
  }
}
