import DrinkTrackerCore
import SwiftUI

/// The app's five surfaces side by side in the system tab bar (ADR-0040).
///
/// Before this the app was one stack rooted on Today: History, Calendar and
/// Trends were pushed from three icon buttons in Today's toolbar, and a fourth
/// presented Settings as a sheet with a Done button. The owner's design (`docs/design/bottom-nav/`)
/// puts the five in a bar with a glyph and a word each, and makes Settings a
/// page like the others.
///
/// The bar is the system's own — iOS 26's floating Liquid Glass tab bar, with
/// its selection tint, its accessibility sizes, its VoiceOver traits and its
/// iPad form — never a drawn one. The design system's first rule is to ride
/// Apple's material rather than approximate it, and a hand-built bar would be
/// the one piece of chrome in the app that did not.
///
/// One `NavigationStack` per tab, owned here rather than by each screen, so a
/// screen is the same view whether it is a tab root or pushed inside one (the
/// year view under Calendar; the privacy policy and the tip jar under
/// Settings). Nothing about the selection is stored: the app opens on Today
/// every launch, because Today is where ＋ is (PRD invariant 1), and a bar
/// that remembered History would put the fast path one tap further away on
/// exactly the launch that wanted it.
struct AppTabs: View {
  @State private var selection: AppTab = .today

  var body: some View {
    TabView(selection: $selection) {
      // Catalog symbols, so `image:` — `systemImage:` would render nothing.
      // The five are the drawing's own glyphs (`AppTab.symbolName`), not SF
      // Symbols: the owner's review of the first bar (2026-09-09) found the
      // system set neither matched the prototype nor sat uniformly beside
      // the drop, so the bar wears the prototype's set, generated like the
      // drink glyphs (ADR-0040 amendment).
      Tab("Today", image: AppTab.today.symbolName, value: .today) {
        NavigationStack { TodayView() }
      }

      Tab("Calendar", image: AppTab.calendar.symbolName, value: .calendar) {
        NavigationStack { CalendarView() }
      }

      Tab("Trends", image: AppTab.trends.symbolName, value: .trends) {
        NavigationStack { TrendsView() }
      }

      Tab("History", image: AppTab.history.symbolName, value: .history) {
        NavigationStack { HistoryView() }
      }

      Tab("Settings", image: AppTab.settings.symbolName, value: .settings) {
        NavigationStack { SettingsView() }
      }
    }
  }
}

/// The five tabs, in the bar's order. Today first: it is the home surface and
/// the launch selection.
enum AppTab: Hashable {
  case today
  case calendar
  case trends
  case history
  case settings

  /// The catalog symbol the bar draws for the tab: the prototype's own five
  /// glyphs, built by `scripts/make-drink-symbols.py` from
  /// `docs/design/bottom-nav/icons/` exactly as the drink glyphs are built
  /// (ADR-0036, ADR-0040 amendment). Two hand-written lists of the same
  /// names, this and the generator's, and the generator compares them, so a
  /// typo here fails CI instead of rendering a blank tab.
  var symbolName: String {
    switch self {
    case .today: "tally.tab.today"
    case .calendar: "tally.tab.calendar"
    case .trends: "tally.tab.trends"
    case .history: "tally.tab.history"
    case .settings: "tally.tab.settings"
    }
  }
}
