import DrinkTrackerCore
import SwiftUI

/// What Calendar, the year view, History and Trends draw in place of their
/// content while the log cannot be read (ADR-0004's third 2026-09-16
/// amendment).
///
/// Each of those screens folds the whole log, and a query whose first fetch
/// fails hands back no rows: the calendar drew every day blank and offered
/// them to bulk fill, History said "Nothing logged yet", and Trends drew a
/// week of zeros — each a confident claim about a log nobody read. A later
/// fetch that fails keeps the rows it had, which is a picture from before
/// whatever change asked for the new read. Either way the screen draws this
/// instead: the drop glyph Today and the widget draw where a figure would be,
/// and one sentence. Nothing on it acts, and nothing on it states a fact about
/// the log.
///
/// Recovery is the same as Today's: the next fetch that works — a store
/// change, or a relaunch — puts the screen back.
///
/// Each screen decides by reading its queries' values first and their
/// `fetchError` after, Today's order and for Today's reason: a query fetches
/// when its value is read, and `fetchError` read first answers for the fetch
/// before — nil, on the first render over a store that cannot be read
/// (measured; ADR-0004's second 2026-09-16 amendment).
struct UnreadableLogView: View {
  var body: some View {
    ContentUnavailableView {
      Label {
        Text("Your log couldn't be read.")
      } icon: {
        Image(decorative: DrinkType.Symbol.standard)
      }
    }
  }
}
