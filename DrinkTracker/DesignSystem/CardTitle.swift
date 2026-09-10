import SwiftUI

/// The title at the top of a glass card, naming what the card holds.
///
/// Two heading levels exist on a screen that groups cards under a heading, and
/// they are told apart by **case**, never by ink (design-system §3: hierarchy
/// comes from size, case and tracking, and re-inking a heading is invariant
/// 10's own failure mode). The group heading above the cards is `SectionLabel`
/// — the same footnote-medium secondary label, uppercased. A card title is the
/// sentence-case form of it, so a reader sees COMPARISONS over "Weekly
/// average" exactly as Settings shows COMPARISONS over its switch rows.
///
/// It replaced `WeekdayCard`'s private uppercase-tracked label when that card
/// stopped holding two tables (ADR-0032's 2026-09-10 amendment):
/// `GlassTokens.Typography.sectionLabel`'s own documentation scopes the
/// uppercase form to "a card that holds more than one table", and after the
/// weekend comparison moved out, no card on Trends holds two.
///
/// A key rather than a `String`: `Text(String)` is the verbatim initializer, so
/// typing this as `String` would silence every card title in the app at once —
/// the fault `SectionLabel`'s own comment records.
struct CardTitle: View {
  let text: LocalizedStringKey

  init(_ text: LocalizedStringKey) { self.text = text }

  var body: some View {
    Text(text)
      .font(GlassTokens.Typography.sectionLabel)
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
