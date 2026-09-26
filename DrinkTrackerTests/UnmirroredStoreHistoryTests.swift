import DrinkTrackerCore
import Foundation
import SwiftData
import Testing

/// Pins the one premise ADR-0055's export path rests on that no Apple page
/// states: a store opened without CloudKit mirroring still records persistent
/// history, so a drink written there is a transaction the mirroring process can
/// later find and export.
///
/// The configuration is the one the two extensions open. `.automatic` in a
/// process with no iCloud container resolves to no mirroring, and this test
/// bundle holds no entitlements at all, which makes it that process: the phone
/// widget since 1.0, and the watch complication from 1.4. The write goes
/// through `logOneDrink`, the call both extensions' ＋ makes.
///
/// What this does not pin, and cannot at tier 2: that the app on the device
/// actually exports such a transaction, or when. That needs an iCloud account
/// and a device (ADR-0055's verification list).
@Suite("A store written without mirroring keeps persistent history")
@MainActor
struct UnmirroredStoreHistoryTests {

  @Test("a drink logged without mirroring is a transaction another container can read")
  func historyRecordsAnUnmirroredWrite() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("UnmirroredStoreHistory-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("default.store")

    func open() throws -> ModelContainer {
      try ModelContainer(
        for: SharedModelContainer.schema,
        migrationPlan: DrinkTrackerMigrationPlan.self,
        configurations: ModelConfiguration(
          schema: SharedModelContainer.schema,
          url: url,
          cloudKitDatabase: .automatic
        )
      )
    }

    let writer = try open()
    let writerContext = ModelContext(writer)
    writerContext.author = "extension"
    let logged = try DrinkRepository(context: writerContext)
      .logOneDrink(seed: .standardDrink, region: .unitedStates)

    // Read back from a second container on the same file, as the app's own
    // process would, rather than from the writer's context.
    let reader = try open()
    let transactions = try ModelContext(reader)
      .fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    let authored = transactions.filter { $0.author == "extension" }
    #expect(!authored.isEmpty, "the write left no transaction authored by the writer")

    var inserted: [PersistentIdentifier] = []
    for transaction in authored {
      for change in transaction.changes {
        if case .insert(let insert) = change {
          inserted.append(insert.changedPersistentIdentifier)
        }
      }
    }
    #expect(inserted.contains { $0.entityName == "DrinkEntry" },
            "the transaction holds no DrinkEntry insert")

    // And the row itself is readable from the second container.
    let id = logged.id
    let rows = try ModelContext(reader).fetch(
      FetchDescriptor<DrinkEntry>(predicate: #Predicate { $0.entryID == id })
    )
    #expect(rows.count == 1)
  }
}
