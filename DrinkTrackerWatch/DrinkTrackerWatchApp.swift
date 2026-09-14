import SwiftUI

/// The watch app's entry point.
///
/// Phase 1 opens the shared store here through `SharedModelContainer.make()`,
/// the same ladder the phone and its widget run (PRD invariant 5); Phase 3
/// replaces the placeholder with the counter (`docs/tallyist-watch-plan.md`,
/// `docs/design/watch/README.md`).
@main
struct DrinkTrackerWatchApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
