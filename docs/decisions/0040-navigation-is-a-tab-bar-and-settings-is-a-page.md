# 0040 — Navigation is a tab bar, and Settings is a page

**Status:** accepted · **Date:** 2026-09-08 · **Amends:** ADR-0034 (Today's
chrome: the four toolbar buttons Home v2 kept are gone) · **Relates to:**
ADR-0027 and ADR-0029 (the calendar's and the year view's toolbars keep their
share buttons), ADR-0012 (Settings as the tip jar's quiet home), PRD invariant 1

## Context

Since 1.0 the app has been one navigation stack rooted on Today. History,
Calendar and Trends were pushed from three icon buttons in Today's toolbar, and
a fourth, a gear, presented Settings as a sheet with a Done button. That shape
was never a decision — it was the first build's default, and every design
bundle since (`docs/design/today2/` included) drew the same four glass circles
in Today's top-right corner.

The owner's new bundle (`docs/design/bottom-nav/`, the *Tallyist iOS
Prototype* canvas, dropped in by hand as every bundle now is) changes that.
Diffed against the previous drop — the reliable way to read one of these, as
ADR-0034 records — the *unbuilt* new work is exactly four things:

1. A **tab bar**: five items, each a glyph over a word — Today, Calendar,
   Trends, History, Settings — in a floating glass pill 14pt in from each
   edge, the active item on an accent wash, the others in secondary ink. It
   shows on every top-level screen and on the year view; it hides under a
   sheet.
2. **Home v3**, which is Home v2 with the four toolbar buttons deleted and
   nothing added. Today carries no chrome at all.
3. A **Settings page** with a large title, in place of the sheet. Its content
   is the sheet's.
4. The calendar's **Year button** becomes a labelled pill — a calendar glyph
   and the word "Year" — where an icon-only grid glyph stood.

The undo toast's bottom offset also moves up to clear the bar. The bundle's
other three files (`github.md`, `ios-frame.jsx`, `support.js`) are
byte-identical to the previous drop, and so is the nested
`design_handoff_tallyist_ui_updates/` directory — the same stale copy `today2`
carries, not committed again. The `.dc.html` itself also carries a stratum
that is not this change's: the *Drink Icons* work the canvas absorbed after
`today2` — a Filled/Outline glyph-style prop with two path sets (`this.ICS`,
defaulting to Filled, which is what shipped), every drink glyph rewired to it,
a Cocktail type and a 40 oz beer pill, and the sheet's type control redrawn as
five glyph-over-name segments — all of it shipped by ADR-0035, ADR-0036 and
ADR-0037 from the icons bundle, none of it new intent. Three things in the
bundle are drift rather than intent, and none is built: Home v3's empty day
still shows the caption and the "Remove that record" link the owner removed
from Today on 2026-09-08 (PR #83); the prototype's cocktail sizes (4 / 6 / 8 oz
at 20%) predate ADR-0037's 3 / 4 / 6 at 15%; and in tab mode the drawing's
Calendar, Trends and History screens still carry a back chevron to Today
beside the bar, an artefact of the prototype sharing those screens between
its two modes — the build's tab roots have none.

What made this a decision rather than a transcription:

**A drawn bar or the system's.** The prototype draws its bar by hand, as it
draws everything. iOS 26's own tab bar *is* that drawing — a floating Liquid
Glass pill, glyph over word, a glass capsule that slides under the selection
with the selected glyph and word in the accent —
and it brings what a drawn one would have to reinvent: the accessibility
sizes, the VoiceOver traits and the "tab 2 of 5" announcement, the
scroll-edge effect under content, the iPad form. The design system's first
rule (§0, "native iOS with one voice added") and its depth rule (§4, "one
elevation story, owned by the OS") both point one way.

**What Today loses.** Home v2's toolbar was the way to every other screen; the
bar replaces it wholesale. Nothing else on Today changes, and ＋ is exactly
where it was.

**Where the app opens.** A tab bar raises a question a single stack never
had: does the app remember the tab it was on? Apple's own apps mostly do. This
app's north star is the fast path — invariant 1 — and a launch that landed on
History would put ＋ one tap further away on the launch that wanted it.

**The Year button's glyph.** The drawing replaces the grid glyph with a
calendar, which is also the Calendar tab's glyph, two inches below it on the
same screen. The word beside it is what the owner asked for; the glyph came
with the drawing.

**The inks.** The drawing draws inactive tabs in secondary grey and the
toolbar's glyphs in accent. The system bar draws inactive tabs in primary ink
and, on iOS 26, toolbar items in primary ink too — the accent appears on the
selected tab and on a press. Those are the platform's answers, and the app has
always taken them for its toolbars.

**A bar that minimises.** iOS 26 can shrink the bar to the selected glyph as
the content scrolls. The drawing shows a full bar on every screen.

## Decision

**The system tab bar, five tabs, opening on Today, nothing stored.**

- `AppTabs` is the root after onboarding: a `TabView` of five `Tab`s in the
  bar's order — Today, Calendar, Trends, History, Settings — each wrapping its
  screen in its own `NavigationStack`. The stacks live there, not in the
  screens, so a screen is the same view as a tab root or pushed inside one:
  the year view stays a push under Calendar (the bar stays visible on it, as
  drawn), and the privacy policy and the tip jar stay pushes under Settings.
  The tab bar is never hidden on a push.
- The glyphs: the drop for Today — the app's own `tally.standard` symbol
  (ADR-0036), which is what the design drew, since Today is where that drink
  is logged — and `calendar`, `chart.bar`, `list.bullet`, `gearshape` for the
  rest, named by their outline forms because the bar applies the fill variant
  itself, to every item, selected or not. Rendered: `chart.bar` and
  `gearshape` are `chart.bar.fill` and `gearshape.fill` in both states;
  `calendar`, `list.bullet` and the drop have no fill variant and keep their
  one form; so no glyph changes shape on selection — the accent ink and the
  capsule carry it, which is what the drawing does too (every glyph filled in
  every state, only colour and wash changing). The words are the five
  screens' own titles, so the catalog gains no key for them.
- The selection is `@State` and starts at `.today` on every launch. Nothing
  about it is persisted.
- The bar does not minimise on scroll, carries no badge, and takes the
  system's iPad form (a bar at the top). No `tabBarMinimizeBehavior`, no
  `tabViewStyle`.
- Today's toolbar is gone entirely, and so is its Settings sheet and the
  state that presented it. Settings loses its `NavigationStack`, its Done
  button and its `dismiss`.
- The calendar's Year button is a `NavigationLink` whose label is an explicit
  glyph-and-word pair — `Image(systemName: "calendar")` beside `Text("Year")`
  — in its own glass shape, split from the share button by a
  `ToolbarSpacer(.fixed)`, because the drawing makes it a labelled pill and
  not a second glyph in the share button's group. An explicit pair rather than
  a `Label`: the navigation bar applies its own icon-only style to a `Label`
  there and `.labelStyle(.titleAndIcon)` did not override it (rendered:
  the word was missing). The visible word is the accessible name; the
  "Year view" accessibility label and its catalog key retire, and "Year" is
  the one new key. The glyph follows the drawing; the duplicate with the tab
  below is accepted and is a one-line swap back to `square.grid.3x3`.
- The inks are the system's: primary for inactive tabs and toolbar items,
  accent for the selected glyph and word, and the selection capsule is
  neutral glass (rendered: it samples grey in both appearances). The
  drawing's secondary-grey inactive tabs, its accent toolbar glyphs and its
  12% accent wash under the active tab are not reproduced. The Year pill
  likewise takes the navigation bar's own text style and a 4pt gap where the
  drawing draws 15px semibold with a 6px gap: the toolbar's typography is
  the platform's answer too.

## Consequences

**Every screen gains a permanent bottom inset.** Content scrolls under the bar
behind the system's scroll-edge effect, so the last card on Calendar, Trends
and Settings is partly covered until scrolled. The three bottom-pinned
surfaces — Today's and History's undo bar (`safeAreaInset`) and the
calendar's undo bar and selection bar (a bottom-aligned `ZStack`) — rise by
the bar's height through the safe area, with no code change; that is the
prototype's `undoBottom` offset, delivered by layout rather than by a
constant.

**Today has no chrome.** Four buttons and a sheet are gone; ＋ is untouched
and invariant 1 is unchanged, since the bar adds no step to the fast path.
History, Calendar and Trends lose their back button to Today — the bar is the
way back — and each tab keeps its own state while another is shown: a
scrolled History stays scrolled, a calendar left on July stays on July.

**Today's view lives as long as the app.** The foreground sweep — Health
backfill and import, the iCloud probe — hangs on `TodayView`'s `.task` and
`scenePhase` change, as before. Today is the launch tab, so its view exists
from the first frame and stays instantiated behind the other tabs; the sweep
runs on a foregrounding whichever tab is showing. Tier 4 for the owner: a
widget tap while the app sits on History, then a foregrounding, still
backfills the sample.

**A settings page is one tap from anywhere.** The tip jar and the privacy
policy are two taps from any screen, where they were two from Today and three
from anywhere else, which first had to pop back. The gear reads as a peer of the four surfaces rather than
as an afterthought in a corner; the drawing chose that, and it is recorded
rather than argued.

**A hidden tab does not re-fold the log.** Each reading tab runs a `@Query`
over the whole log and folds it per render, and a tab once visited stays
instantiated behind the bar — so the worry was that every drink logged on
Today would re-fold Calendar, Trends and History unseen. Measured during the
review with a scratch probe on iOS 26.5, not reasoned: a hidden tab's body is
not re-evaluated on a store change, so the reading tabs cost nothing until
they are shown again.

**The drop is smaller than its neighbours.** ADR-0036 sized the custom
glyphs at cap height, 62–74% of the SF glyphs' height, and the bar shows the
difference beside four SF symbols. Accepted, rendered, and a one-line swap
to `drop.fill` if the owner's eye disagrees.

**The App Store screenshots are stale in every frame**: each now carries a
bar, and the calendar's toolbar has a word in it.

**iPad takes the system's form**, a bar at the top of the window, not the
drawing's floating pill. Unrendered here; tier 3 for the owner.

**Invariants, checked one by one** (PRD §3, a new surface): 1 — ＋ is one
tap in the app and one from the widget, and the bar changes neither; 2 — no
sheet changed; 3, 4, 5, 6, 7 — no entry, store, Health or quantity path is
touched; 8 — the six visible words are five screen titles and "Year", all
nouns; 9 — the core package is untouched; 10 — no colour is defined: the
selected ink is the `AccentColor` asset through the system, and the capsule
is the system's own glass.

**Dynamic Type and VoiceOver**: the system bar's own. Rendered at the default
size and at `accessibility-extra-large`, in both appearances; VoiceOver's
"tab 2 of 5" reading and the bar's behaviour under a thumb on real glass are
tier 3/4 for the owner.

## How to reopen

- **A remembered tab.** If use shows people living on Calendar or History
  and re-tapping their way there on every launch, `AppTabs.selection` becomes
  an `@AppStorage` — one line — and this record's launch rule is amended. The
  argument against it is invariant 1, so the evidence has to be about the
  fast path, not about convenience.
- **Minimise on scroll.** One modifier, `tabBarMinimizeBehavior(.onScrollDown)`,
  if a screen's last card needs the room. The drawing shows a full bar.
- **A drawn bar.** Only if the system bar cannot do something the design
  needs — a sixth item, a control inside the bar — and even then the design
  system's depth rule wants the case made.
- **Settings back to a corner.** If the gear as a fifth peer reads as too
  prominent for a screen most people open once, Settings returns to a toolbar
  item — on whichever tab the owner names — and the bar has four items.
- **The Today glyph.** `Label("Today", systemImage: "drop.fill")` if the
  cap-height drop reads as too small beside its neighbours, or a different
  symbol if a drink's glyph is the wrong sign for a home tab.

## Amendment (2026-09-09): the bar wears the drawing's own glyphs

The owner's review of the first bar: *"The icons in the bottom row don't match
or look uniform like in the prototype. Can you fix? It's okay to leave them
primary ink vs the prototype but the icon styles themselves need to be
updated."*

What the Decision above got wrong: it sent four SF Symbols and one cap-height
custom drop into a bar whose drawing has five glyphs of one weight on one
24-unit grid. The SF gear and calendar are heavier than the drawing's, the SF
list lighter, and the drop was two-thirds the height of its neighbours —
ADR-0036's cap-height sizing, right beside row text and wrong beside tab
glyphs. Five glyphs from three sources could not read as one set, and the
render said so before the owner did (the "smaller than its neighbours" note
above was the symptom, not the diagnosis).

**Decision.** The five tab glyphs are the prototype's own, lifted from its
Tab bar block into `docs/design/bottom-nav/icons/` — one filled path each,
the calendar's white overlays turned into cut-outs, the gear's zero-length
repeats dropped — and built into `tally.tab.today` / `.calendar` / `.trends`
/ `.history` / `.settings` symbolsets by `scripts/make-drink-symbols.py`: the
ADR-0036 pipeline with a second placement, `TabPlacement`, which centres the
24-unit box on the capital-letter height at 120 template units (5 per source
unit) instead of standing it on the drink glyphs' baseline at 100. That is
the size the system's own tab glyphs render at — the gear's ink measured
20–21pt in the bar before and after — so the bar's proportions are unchanged
and only the drawing is. `AppTab.symbolName` names them; the generator
cross-checks that list, the source directory and the catalog, and the CI job
that regenerates the drink glyphs regenerates these. Ink stays the system's,
primary at rest and accent selected, as the owner allowed.

**Consequences.** The fill-variant discussion in the Decision no longer
applies: a custom symbol has one form, which is what the drawing draws. The
tab glyphs carry no weight axis, like the drink glyphs. The Today tab's drop
is the prototype's *Filled* drop at the bar's size; `tally.standard` keeps
its cap-height size in rows, so the same shape ships twice at two sizes on
purpose. The catalog holds thirteen `tally.*` symbolsets. The "drop is
smaller than its neighbours" consequence and its `drop.fill` reopen path are
retired.

**How to reopen.** Size: `TAB_UNITS_PER_SOURCE_UNIT`, one constant. The
system set: `Tab(_:systemImage:)` per tab, and the five symbolsets and their
sources go.
