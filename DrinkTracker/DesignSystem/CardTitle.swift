import SwiftUI

/// The title at the top of a glass card, naming what the card holds.
///
/// It is `GlassTokens.Typography.cardLabel` — the role every other card on
/// Trends and the calendar already titles itself with (`StatCard`, "Days with
/// no drinks logged", "Longest run with none", the chart card's own title,
/// `RecentSummaryCard`) — plus the two things a *title* needs that a caption
/// does not: a header trait and a wrapping rule. It exists so those are in one
/// place rather than repeated at five call sites.
///
/// Two heading levels sit together on a screen that groups cards under a
/// heading, and they are told apart by **weight and case**, never by ink
/// (design-system §3: hierarchy comes from size, case and tracking, and
/// re-inking a heading is invariant 10's own failure mode). The group heading
/// above the cards is `SectionLabel`: footnote *medium*, uppercased. A card
/// title is footnote *regular*, sentence case — so a reader sees COMPARISONS
/// over "Weekly average" in the same relationship Settings draws between its
/// section title and its switch rows. (`SettingsSection` inlines that heading
/// treatment rather than using `SectionLabel`, so the two render alike but only
/// this one speaks as a heading.)
///
/// It replaced `WeekdayCard`'s private uppercase-tracked label when that card
/// stopped holding two tables (ADR-0032's 2026-09-10 amendment): the
/// uppercase-tracked form was scoped to "a card that holds more than one
/// table", and after the weekend comparison moved out, no card on Trends holds
/// two. Matching `cardLabel` rather than inventing a heavier title is what
/// keeps the four new titles from reading a step louder than the summary cards
/// directly above them.
///
/// A key rather than a `String`: `Text(String)` is the verbatim initializer, so
/// typing this as `String` would silence every card title in the app at once —
/// the fault `SectionLabel`'s own comment records.
struct CardTitle: View {
  let text: LocalizedStringKey

  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(GlassTokens.Typography.cardLabel)
      .foregroundStyle(.secondary)
      // Three words ("Weekend and weekdays") wrap rather than truncate at the
      // larger type sizes — design-system §3's rule, and the fault that reached
      // the drink sheet as "≈ 1 standard dr…".
      .fixedSize(horizontal: false, vertical: true)
      // A heading, so VoiceOver can move between the cards on a long screen.
      // The title stays a *sibling* of the card's content, never a parent and
      // never inside a shared `children: .combine` — that would merge it into
      // the content's sentence and destroy the header stop.
      .accessibilityAddTraits(.isHeader)
  }
}
