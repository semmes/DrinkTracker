import CoreTransferable
import DrinkTrackerCore
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The whole log as a shareable CSV file — what Settings' "Export log" row
/// hands to the share sheet (ADR-0015).
///
/// Nothing is fetched or rendered until the user actually picks a share
/// destination: the export closure runs then, off the main actor, with its
/// own `ModelContext` from the shared container. Opening Settings therefore
/// costs nothing, and a large log never blocks the UI.
struct LogExportFile: Transferable {
  let container: ModelContainer
  /// The current region — the lens every total is expressed in (invariant 3).
  let region: Region
  let fileName: String

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .commaSeparatedText) { file in
      SentTransferredFile(try file.write())
    }
  }

  private func write() throws -> URL {
    let context = ModelContext(container)
    let drinks = try context.fetch(FetchDescriptor<DrinkEntry>()).map(\.logged)
    let markers = try context.fetch(FetchDescriptor<AlcoholFreeDay>())

    // Markers split by who recorded them, so the source column stays true
    // for a no-alcohol day another app put in Health (ADR-0025).
    let csv = LogExport.csv(
      drinks: drinks,
      alcoholFreeDays: Set(markers.filter { !$0.isImportedFromHealth }.map(\.day)),
      alcoholFreeDaysFromHealth: Set(markers.filter(\.isImportedFromHealth).map(\.day)),
      region: region
    )

    // Every export is staged under one directory that is cleared before the
    // next export and on every launch, so the staging copy does not outlive
    // the share that needed it — the policy says the app keeps no copy, and
    // until this the file sat in tmp until iOS got round to purging it. A
    // fresh subdirectory per export keeps the human-readable file name
    // without two exports racing over one path.
    Self.removeStaleExports()
    let directory = Self.exportsDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(fileName)
    try Data(csv.utf8).write(to: url, options: .atomic)
    return url
  }

  /// Where exports are staged for the share sheet.
  static var exportsDirectory: URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
  }

  /// Deletes every previously staged export. Called before each export and
  /// at launch (`DrinkTrackerApp`), so a staged file lives only as long as
  /// the share sheet that reads it.
  static func removeStaleExports() {
    try? FileManager.default.removeItem(at: exportsDirectory)
  }

  /// `tallyist-log-2026-08-26.csv` — dated so successive exports sort and
  /// don't silently overwrite each other in the receiver's files.
  static func defaultFileName(on date: Date = Date(), calendar: Calendar = .current) -> String {
    "tallyist-log-\(LogExport.dayString(date, calendar: calendar)).csv"
  }
}
