import SwiftUI

/// The Phase 0 placeholder: it proves the target builds, installs and launches
/// on a paired simulator, and nothing more. Phase 1 prints today's count from
/// the shared store here; Phase 3 replaces the view with the counter.
///
/// `verbatim` on purpose — this is the app's name, not copy, and a placeholder
/// key in the watch catalog would outlive the view that introduced it.
struct ContentView: View {
  var body: some View {
    Text(verbatim: "Tallyist")
      .font(.title3)
  }
}

#Preview {
  ContentView()
}
