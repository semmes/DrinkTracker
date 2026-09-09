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
      // The drop is the untyped drink's own glyph (ADR-0036), and it is what
      // the design drew for this tab: Today is the surface where that drink
      // is logged. A catalog symbol, so `image:` — `systemImage:` would
      // render nothing. The bar draws every glyph in its fill variant at
      // rest, so the four SF names below are the outline ones.
      Tab("Today", image: DrinkType.Symbol.standard, value: .today) {
        NavigationStack { TodayView() }
      }

      Tab("Calendar", systemImage: "calendar", value: .calendar) {
        NavigationStack { CalendarView() }
      }

      Tab("Trends", systemImage: "chart.bar", value: .trends) {
        NavigationStack { TrendsView() }
      }

      Tab("History", systemImage: "list.bullet", value: .history) {
        NavigationStack { HistoryView() }
      }

      Tab("Settings", systemImage: "gearshape", value: .settings) {
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
}
