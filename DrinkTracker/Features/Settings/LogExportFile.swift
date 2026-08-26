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
    let freeDays = try context.fetch(FetchDescriptor<AlcoholFreeDay>()).map(\.day)

    let csv = LogExport.csv(
      drinks: drinks,
      alcoholFreeDays: Set(freeDays),
      region: region
    )

    // A fresh directory per export keeps the human-readable file name without
    // two exports racing over one path.
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(fileName)
    try Data(csv.utf8).write(to: url, options: .atomic)
    return url
  }

  /// `tallyist-log-2026-08-26.csv` — dated so successive exports sort and
  /// don't silently overwrite each other in the receiver's files.
  static func defaultFileName(on date: Date = Date(), calendar: Calendar = .current) -> String {
    "tallyist-log-\(LogExport.dayString(date, calendar: calendar)).csv"
  }
}
