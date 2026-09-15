# Handoff: the watch counter, and the tap that hides the number

## Overview

Tallyist's Today counter, narrowed to the Apple Watch at 198 × 242 pt, with one
addition: **a tap on the intensity tile puts the digits away while the band stays
lit.** The day's amount remains fully stated by colour, so a wrist on a table
shows its owner where they are and shows everyone else a blue square.

This covers Phase 3 (the counter), Phase 4 (the type picker), Phase 5 (the
session dot row) and Phase 6 (complications) of `docs/tallyist-watch-plan.md`.

**Target:** a new SwiftUI view in `DrinkTrackerWatch/`, watchOS 26, dark ground
only. `DrinkTrackerCore` only — not ComponentsKit.

## About the design files

`Tallyist Watch Counter.dc.html` is a **design reference drawn in HTML** — a
prototype of the intended look and behaviour, not production code to port. The
job is to recreate it in SwiftUI using the repo's own components, tokens and
patterns.

Where this document names a Swift symbol, **call the symbol rather than copying
the number.** Hex codes are printed so the drawing can be checked against the
spec, not so they can be pasted into a view. `IntensityPalette` remains the only
place in the app that defines literal colours (PRD invariant 10), and
`GlassTokens` still defines none.

Open the HTML file in a browser. Watch screens are drawn at true point size and
scaled up for legibility (1.7× for the hero, 1.05× for the state grid); every
figure quoted below is in **points**.

## Fidelity

**High.** Layout, type sizes, radii and colours are final and measured. Recreate
them exactly.

One element is deliberately **not** settled and is marked in place: the "Record
no alcohol" button on the empty-day screen is a proposal with no decision behind
it. See Open question 1.

## Constraints this design is built to respect

These are the repo's own rules, restated because they explain shapes that would
otherwise look arbitrary.

- **No goals, no streaks, no scores.** Nothing on this screen accumulates toward
  anything and no shape implies a target — which is why the band is a *tile*
  rather than a bar or an arc that fills. `SUProgressBar` was removed from the
  app for exactly this reason: a bar that fills implies a target, and the
  cheapest way to protect a target is to stop logging.
- **Colour never grades.** The ramp carries magnitude in lightness only.
  Alcohol-free sits off the ramp with an outline. Status is shape and words
  first, colour as reinforcement.
- **One tap is the fast path** (invariant 1), and it cannot mean different things
  in the app and the widget. ＋ runs the same seed rule, read from the App Group.
- **Region is a display lens** (invariant 3). Every figure is expressed in the
  region the settings bridge delivered, never a US default.
- **Voice:** factual, countable, states of the system and not the person, and no
  exclamation marks — the storage warning included.
- **The watch shows what the user already knows and hides it from everyone else
  by default.** If a surface has to choose between glanceable and private,
  private wins, because this product's failure mode is a drink that never gets
  logged.

## Screens

### 1. The counter (Phase 3)

The home surface and the only screen that writes. No header, no navigation
chrome, no summary — everything else the watch could show is a reason to keep
looking at it.

**Layout**, top to bottom, in a centred `VStack` with 8 pt horizontal margin
(watch-local; *not* `GlassTokens.Spacing.screenMargin`'s 20) and 26 / 12 pt top
and bottom insets:

| Element | Spec |
|---|---|
| Counter row | `HStack(spacing: 4)`: 44 · 86 · 44 = **182 pt**, the full usable width |
| − disc | 44 square, radius 22, `glassSurface(cornerRadius: 22, interactive: true)`, glyph 19 semibold in `Color.accentColor` |
| Tile | 86 square, radius **25** continuous, fill `IntensityPalette.fill(band, scheme: .dark)` |
| Numeral | **46** semibold rounded, tabular, `minimumScaleFactor(0.6)`, ink `IntensityPalette.ink(band, scheme: .dark)` |
| ＋ disc | 44 square, radius 22, fill `Color("AccentFill")`, glyph 21 semibold in `.white` |
| Unit word | 12, `.secondary`, 7 below the row — "drinks today" / "drink today" |
| ≈ line | 11, `.secondary`, 1 below that — `StandardDrink.liveEstimate(total, region:)` |
| Legend | 11 above; 9 pt swatch at radius 3, 3 pt inner gap, 9 pt label, 7 pt outer gap |
| Hint | 10, `.tertiary`, bottom-pinned — "Hold ＋ to say what it was" |

**Both controls are the same size on purpose.** 44 / 86 / 44 at 4 pt gaps is the
only arrangement that fits 182 pt with both targets legal. `CountStepper` already
establishes the rule: its hero discs are equal, and the ＋ is told apart by being
**filled**, not by being bigger. The glyphs keep the source's 2-point optical
offset (− 19, ＋ 21) because the ＋ sits on a solid fill and matching them
optically means matching apparent weight, not point size.

**Two ratios, so the tile can be resized honestly.** The phone's hero is a 68 pt
numeral in a 126 pt tile at radius 36. Both watch values are that, scaled:

```
radius  = side × 36 / 126   →  86 × 0.2857 = 24.6 → 25
numeral = side × 68 / 126   →  86 × 0.5397 = 46.4 → 46
```

If the tile ever changes size — another case, an accessibility step — re-derive
from these rather than picking new numbers.

**No tile, no 46.** On an unlogged day `IntensityPalette.fill` returns `.clear`,
so the numeral takes the tile's room at **56** — the same trade `CountStepper`
makes between its 68-in-a-band and 84-without-one.

### 2. Hidden (the addition)

A tap on the tile toggles it. 86 pt is well over the touch floor, so no new
affordance is needed and none is drawn.

**Suppressed:** the numeral (replaced by a 40 × 8 bar at radius 4, in the band's
own `IntensityPalette.ink` at 55%), the ≈ line, all four legend labels, and the
session dots' fill — they fall to outlines.

**Kept:** the tile fill, the four swatches, the unit word, both controls.

The bar is deliberately a struck-out number rather than a blank, so the screen
reads as withheld and not as loading.

**Why the labels go.** A legend label — "3–5" — is as readable across a table as
a count. Hiding the numeral while leaving the ranges named would be theatre.

**Residual exposure, stated plainly.** A passer-by can still see that the tile
matches the third of four swatches. They cannot see what the third one means.
That is a real reduction, not a total one, and the ADR should say so rather than
claim more.

### 3. Recorded as no alcohol

The outline channel at tile scale: fill `.primary` at 16%, plus a 2 pt
`.primary`-at-35% border, with `tally.alcoholfree` at 34 pt inside. Off the ramp
by ADR-0007, so it can never read as a small amount of drinking.

Copy is `TodayView`'s verbatim: "Recorded as no alcohol today", then "Tap the
plus sign to change that." A day mirrored from Apple Health reads "From Apple
Health" instead of the second line and offers no way to clear it (ADR-0025).

### 4. Session running (Phase 5)

Behind the watch's own "Show session pace" toggle, off by default. The hint
yields the bottom slot to the row.

Dots at 9 pt diameter, 5 pt gap, **maximum 8** — above the cap draw the maximum
and let the numeral carry the truth; no truncation mark. Dots read the rolling
two-hour window's band, the tile reads the day: two windows on one scale.

The count line is `N · 1h 12m` — the count in **rounded semibold** (the user's
own figure) and the elapsed time in default SF (the clock's). Inside
`TimelineView(.periodic(from: .now, by: 60))`; never a `Timer` — a one-second
wakeup in a frontmost watch app is a battery complaint in a review.

### 5. Type picker (Phase 4)

Reached by **long-press ＋**. One screen deep, returns on tap, the app's only
navigation.

A 2-column grid of 62 pt tiles at radius 14 on `.primary`-at-10%, each the
type's glyph at 20 pt in the accent over its name at 11 pt. Iterate
`DrinkType.selectableCases` — five cases; `.unspecified` is never offered as a
choice. The fifth tile sits under the fold and the crown scrolls to it.

Load glyphs with `Image(_:)` or `Label(_:image:)`, **never
`Image(systemName:)`** — these are asset-catalog symbols and `systemName`
renders nothing for them. Use `Image(decorative:)` beside text, or a catalog
image speaks its asset name.

Tapping a type writes it at the type's defaults through `DrinkDraft(type:)` →
`makeLoggedDrink(region:)`. **No size, no strength** — those are refinements and
refinements happen on the phone.

### 6. Always-On / wrist down

The system's redaction, and it is distinct from the user's. **The tile's fill
goes too**, falling to the outline channel, because once the digits are gone the
colour *is* the figure. The drop glyph (`tally.standard`) returns at 34 pt so the
screen does not read as broken, the unit word stays, the swatches empty to
outlines.

Every count and total is `.privacySensitive()`. The user's hide state composes on
top of this and does not opt out of it.

### 7. Storage failed

`Diagnostics.isStoreInMemory` is true when the store could not be opened and
nothing is being saved. A bottom-pinned strip at radius 14 on `.primary`-at-10%:
`exclamationmark.triangle` at 14 pt plus "Not saving — storage unavailable" at
10 pt, in `SettingsView`'s own words, taking the legend's and the hint's room.

The watch has no Settings page to bury this on, and a watch that silently
discards every log is the worst outcome available here.

## Complications (Phase 6)

`StaticConfiguration` throughout, four families. The tile shrinks to a disc and
keeps its job.

| Family | Content |
|---|---|
| `accessoryCircular` | Band disc, numeral in band ink, "drinks" beneath |
| `accessoryCorner` | Band disc in the corner, numeral and "drinks" inset |
| `accessoryRectangular` | 70 pt band tile, unit word, ≈ line, and a 56 pt ＋ |
| `accessoryInline` | Glyph + "N drinks today" — text only, no block |

**One content rule:** the session count while a session is running, today's count
otherwise. The same thing the home-screen widget shows, no more.

**The timeline is the part that is easy to get wrong.** Build it with two
entries — the current one, and one dated `session.lastDrinkAt +
SessionPace.gapThreshold` carrying the post-session state, with `.after` that
date as the refresh policy. Without the second entry the face keeps a dead
session's count until something else triggers a reload, which is precisely the
accumulating standing number the tone rules forbid. Call
`WidgetCenter.shared.reloadAllTimelines()` after every write.

**Use `LogOneDrinkIntent`, never `LogDrinkIntent` or `LogDrinksIntent`.** A
parameter the system cannot resolve is one it wants to *ask* about, which a
complication cannot do — the tap is abandoned during parameter resolution, before
`perform()` is entered. That is the bug that once broke one-tap logging;
`LogOneDrinkIntent` is parameterless and structurally cannot repeat it.

**No relevance-based Smart Stack surfacing.** "You usually drink around now" is a
behavioural prediction presented as help, and it would be surfaced by the app
rather than requested by the user. The card appears in the stack because the user
put it there.

Every family is `.privacySensitive()`, redacting to the glyph and the unit word
with the figure suppressed — **never to a blank tile.** A complication that looks
broken gets removed from the face, which loses the feature entirely.

## Interactions & behaviour

**＋** writes through `DrinkDraft.quickCount(1, from:seed:region:)` with region
and seed from `AppSettings.storedRegion()` / `storedCounterSeed()`. This is
`LogOneDrinkIntent.perform()`'s body — **lift the shared part into `Shared/` and
call it from both.** A fourth copy of the seed rule will drift; that is the whole
of ADR-0023's argument and the day-sheet caption bug `countSeedPreview` exists to
prevent.

**−** removes the newest entry through `DrinkRepository.delete(id:)`, on the
entry returned by a new pure function:

```swift
public static func removableNewest(in drinks: [LoggedDrink], on day: Date,
                                   calendar: Calendar = .current) -> LoggedDrink?
```

Nil means the control is **unavailable**, never skipping to an older drink — the
watch cannot retire a HealthKit sample, and skipping would silently remove a
drink the user did not point at. Cover at tier 1: nothing today, newest has a
sample, newest is an import, newest is watch-logged behind an older phone-logged
one.

**Both refetch at execution time** and chain like `TodayView`'s `counterOps`, so
a fast − behind a ＋ removes the drink that ＋ just made rather than the one
before it. Read `TodayView`'s counter section before writing this; the race is
likelier on a watch because a tap is easier to repeat.

**Double Tap** is `.handGestureShortcut(.primaryAction)` on the ＋ and nothing
else claims it. It fires only while the counter screen is frontmost. A Double Tap
log must be **distinguishable by feel** from an on-screen tap, so an unintended
pinch announces itself immediately rather than being found three days later in
History.

**Haptics:** `.click` on a log, `.failure` on a refusal, a distinct one for a
Double Tap log. Never `.success` — it reads as praise for the act.

## State management

| State | Shape |
|---|---|
| Today's entries | `@Query` on `DrinkEntry`, filtered to the current calendar day, re-evaluated on `.NSCalendarDayChanged` and on foregrounding |
| Band | `DayIntensity.bucket(standardDrinks:isMarkedAlcoholFree:hasEntries:)` over the region-lensed total |
| Hide | `@State` bool, view-local, **per-glance** — cleared on launch, nothing persisted, never gates a write |
| Toast | `@State` enum with a ~2 s timer; occupies the hint's slot, reserves no row |
| Session | `SessionPace.currentSession(in:now:)` inside the 60 s `TimelineView` |
| Session toggle | Watch-local, `AppGroup.defaults`, off by default |

Region and counter seed arrive over the Phase 2 settings bridge and are read back
through `AppSettings.storedRegion()` / `storedCounterSeed()`. A missing payload
means "keep what you have", never "reset to the default".

## Motion

| Change | Spec |
|---|---|
| Count changes value | `.contentTransition(.numericText(value:))` + `.snappy(duration: 0.2)` |
| Tile fill / ink | `.smooth(duration: 0.22)`, gated by Reduce Motion |
| Numeral → bar | **Crossfade. Must not roll.** |

Hiding is a *subject* change, not a value change. A roll between two subjects
draws a direction the app does not assert (ADR-0026, ADR-0028).

**One thing jumps:** the legend re-lays-out when the labels leave, which moves
the swatches. Either crossfade the whole row or pin its width so it cannot shift.
Do not animate the gap.

Never: springs with overshoot on numbers, looping or idle animation, or motion
that draws the eye to a "good" value.

## Design tokens

### The dark ramp — `IntensityPalette`, dark scheme

| Band | Step | Fill | vs black | Ink | Ink on fill |
|---|---|---|---|---|---|
| 1–2 `.low` | 600 | `#184f95` | 2.59:1 | white | 6.94:1 |
| 3–5 `.medium` | 400 | `#3987e5` | 5.77:1 | black | 5.77:1 |
| 6–9 `.high` | 200 | `#9ec5f4` | 11.76:1 | black | 11.76:1 |
| 10+ `.veryHigh` | 100 | `#cde2fb` | 15.86:1 | black | 15.86:1 |

**The 2.59:1 in row one is why the session dots start at `.medium`.** A dot is a
graphical object needing 3:1 against its ground and `.low` does not clear it, so
a `.low` dot stays on the neutral outline — the design system's existing
off-ramp channel.

**The tile is exempt, and deliberately.** It is 86 pt of fill carrying a numeral
at 6.94:1, not a 9 pt mark whose colour is the whole message.

Recompute all four before changing any of them. A colour error here is invisible
to a reviewer with normal colour vision (invariant 10).

### Brand and semantic

| Token | Value |
|---|---|
| ＋ fill | `Color("AccentFill")` — 500 `#256abf`, both modes |
| Accent text / glyphs | `Color.accentColor` — 400 `#3987e5` in dark |
| Alcohol-free tile | `.primary` at 16% + 2 pt `.primary` at 35% |
| Unlogged tile | `.clear`, no stroke |
| − ground | `glassSurface(cornerRadius: 22, interactive: true)` |
| Everything else | system semantic: `.primary`, `.secondary`, `.tertiary` |

**Never use `Color.accentColor` for a fill.** The asset accent is the *text*
pair and resolves to a lighter step in dark mode, where a white glyph on it falls
to 3.64:1. `AccentFill` is the fill pair in both modes (design review R2).

### Type

Signature rule: **numerals the user made are rounded; everything else is default
SF.** The count and the session count are rounded semibold tabular. The unit
word, the ≈ line, the legend labels, the elapsed time and all copy are default
SF.

Sizes in points: numeral 46 (56 without a tile), unit word 12, ≈ line 11, legend
label 9, hint and toast 10, session count line 11, picker name 11.

### Spacing and shape

Screen margin 8, top inset 26, bottom inset 12, counter gap 4. Tile radius 25,
disc radius 22, toast pill radius 12, warning strip radius 14, picker tile radius
14. Minimum touch target 44.

## Assets

The five drink glyphs plus `tally.standard` and `tally.alcoholfree`, in `icons/`.
These are the repo's own drawn set from `docs/design/icons/icons/` — the owner's
24 × 24 art, copied unchanged, not redrawn. The HTML inlines their paths; the
SwiftUI view loads the compiled symbols from the asset catalog by name
(`DrinkType.Symbol`).

Phase 1 moves the `.symbolset` folders into `Shared/Assets.xcassets` so all
four targets can reach them — **thirteen**, not eight: the five `tally.tab.*`
share the generator's one output path and its cross-check asserts the full set
— and updates the output path in `scripts/make-drink-symbols.py` and the two
`git diff` paths in CI's `drink-symbols` job. `AccentColor` and `AccentFill`
move with them, since this design draws from both and the watch targets carry
only an empty template accent. **Never hand-edit a symbolset** — regenerate it.

`exclamationmark.triangle` on the storage strip is an SF Symbol; the HTML draws a
geometric stand-in for it.

## Accessibility

The counter is **one adjustable element**, not three stops:
`accessibilityElement(children: .ignore)`, label "Drinks today", value the count,
and an `accessibilityAdjustableAction` for increment and decrement. That is also
what keeps the tile out of the accessibility tree — the value already says the
number, and the colour encodes nothing a reader needs twice.

**Hiding must not change what VoiceOver speaks.** A screen reader is not the
audience the tap protects, and silencing the value would make the feature an
accessibility regression dressed as privacy. Same for the legend: each band is
one element with its range as the label and `.isSelected` on the active one,
labels visible or not.

Both discs are 44 pt with the hit shape **inside** the button's label — a frame
applied to the Button grows the layout without growing the target. Every text
style relative; `minHeight`, never `height`.

Colour carries nothing alone: the ramp is lightness-ordered so it survives every
form of CVD and greyscale, alcohol-free adds an outline, and the storage warning
is a symbol plus words.

## Strings — for the 1.4.3 copy review

Already in the catalogs: "drinks today" / "drink today", "≈ N standard drinks",
"1–2" / "3–5" / "6–9" / "10+", "Recorded as no alcohol today", "Tap the plus sign
to change that.", "From Apple Health", "Not saving — storage unavailable", and
Beer / Wine / Spirit / Cocktail / Other.

New, and needing review:

- "Hold ＋ to say what it was"
- "Tap again to show the count"
- "Record no alcohol" — *unresolved, see Open question 1*
- The session line's `N · 1h 12m` format
- The −-unavailable line (not drawn; replaces the ≈ line in that state)
- The region-not-set line (not drawn; replaces the ≈ line before the first
  settings payload arrives)
- The complication display name and description

Whole-phrase keys carrying their own count, never a number glued to a noun — the
unit's name varies by region, its form by count, and word order by language.

## Open questions — five, none cosmetic

1. **Recording a day as no alcohol has no watch path.** The phone offers it on an
   empty day; the plan gives the watch no equivalent, and the wrist is the
   surface you are wearing at the end of a dry day. The button drawn on the
   empty-day screen is a **proposal**. Decide before Phase 3, because it changes
   that screen's layout.
2. **The ＋ in `accessoryCircular`.** Phase 6 puts an interactive ＋ in both the
   circular and rectangular families, but a 50 pt disc cannot hold a figure *and*
   a 44 pt target. This design keeps the figure and leaves the ＋ to
   `accessoryRectangular`. Confirm that, or make the whole circle the button and
   give up the count.
3. **Per-glance or stored?** Drawn as per-glance. A stored preference is discreet
   *before* the wrist is on the table, which is the only kind that helps — but it
   needs a switch, and the watch has no real Settings screen. If stored, it is
   watch-local by the plan's own dividing line: it changes what is shown, not
   what is computed.
4. **Does hiding govern the complications?** It has to, if it is stored. A face
   needs no unlock and is the most public surface the product has, so a setting
   that governed only the app would protect the one screen nobody else was
   looking at.
5. **What `.privacySensitive()` actually renders** in Always-On and at each
   complication size is a device question. The policy here is sound; the redacted
   tile may not look the way this page draws it. Check it in Phase 6, not Phase
   8 — the answer may send the design back.

### Decisions (owner, 2026-09-14)

1. **Yes — the watch can record a day as no alcohol.** The drawn button is
   the design, with the phone's exact copy. Phase 3 confirms, before it writes
   one, that a user-set marker has no Health side effect the watch cannot
   mirror; its ADR records the check.
2. **As drawn:** the figure keeps the `accessoryCircular` disc and the ＋ is
   `accessoryRectangular`'s.
3. **Per-glance.** Nothing stored, no switch.
4. **So hiding does not govern the complications**; the system's own
   redaction is what protects the face.
5. Stays a Phase 6 check.

### Built (Phase 3, 2026-09-14) — where the code departs from this page

- **The −-unavailable line is a toast, not a replacement for the ≈ line.**
  The newest entry carries a Health sample as soon as the phone has been
  opened after it was logged, so the drawn state would be up most of a day
  and the ≈ figure gone for the duration. The − disc dims instead, and a
  touch on it plays the refusal haptic and shows "Remove that drink on the
  phone" in the hint slot for about two seconds (ADR-0043).
- **The hint slot is empty until Phase 4.** "Hold ＋ to say what it was"
  names a picker that does not exist yet. In debug builds the slot carries
  the diagnostics line instead (store mode · iCloud · region · seed · the
  last settings payload's time).
- **A failed write says "Not saved"** in the same slot, the same way — a
  state this page did not draw.
- **The toast is a pill** at radius 12 on `.primary` at 10%, per the token
  table, in primary ink at the hint's 10 pt.
- **The − ground is `glassEffect(.regular.interactive(), in: .circle)`** —
  watchOS 26's own Liquid Glass; the phone's `glassSurface` helper is the
  phone's.
- Everything else is as drawn: 44 · 86 · 44 at 4 pt gaps, radius 25, numeral
  46 (56 bare), the hidden bar at 40 × 8 in the band's ink at 55%, the
  alcohol-free tile, the Always-On fall to the outline channel with the drop
  glyph, the legend's labels leaving at zero opacity so the swatches never
  move, one adjustable VoiceOver element, the storage strip.

### Built (Phase 4, 2026-09-14)

- **As drawn.** Two columns of 62 pt tiles at radius 14 on `.primary` at 10%,
  the glyph at 20 pt in the accent over the name at 11 pt, iterating
  `selectableCases`; the fifth tile under the fold. The system's back chevron
  is the only chrome, and the picker has no title.
- **The hold is half a second** on the ＋ disc's own button — a simultaneous
  `LongPressGesture`, so Double Tap keeps its control — and a hold never also
  logs on release.
- **The hint is on** in the counter's slot from this phase: "Hold ＋ to say
  what it was", tertiary at 10 pt, under a toast when one is showing.
- The counter now lives in a `NavigationStack`; its row sits a few points
  higher than the Phase 3 render, inside the same insets.

### Built (Phase 5, 2026-09-14) — where the code departs from this page

- **As drawn** for the row: 9 pt dots at 5 pt gaps, at most eight, in the
  rolling window's fill from `.medium` up; `N · 1h 12m` beneath at 11 pt, the
  count rounded semibold, the time default SF; inside a 60-second
  `TimelineView`. The row takes the hint's slot while a sitting is active.
- **The neutral dot is a 1 pt ring in the secondary label colour**, not the
  tile border's 35% primary: a ring that small needs its own 3:1, and white
  at 35% on black sits on that line (3.01 unquantised, 2.998 as `#595959`)
  where secondary is 6.4:1 (ADR-0044).
- **The switch is on the counter itself**, the last thing on its scroll: the
  system's own toggle row, "Show session pace", off by default. This page did
  not draw where the toggle lives; the watch has no Settings screen.
- **Concealed — hidden by the tap or redacted under Always-On — the row is
  eight rings whatever the count, and the count line goes.** This page's
  hidden state outlined the dots at their count; a row of rings at the count
  is still a count, readable across a table up to eight, which is the leak the
  hide exists to close. One expression to reverse (ADR-0044).

### Built (Phase 6, 2026-09-14) — where the code departs from this page

- **Today's count on every family, the sitting only as dots.** The
  complications table's "session count while a session runs" is not built:
  the home-screen widget it cites shows today's count, and a numeral that
  changes meaning and rises when a sitting ends is a standing number by
  another door (ADR-0046). The rectangular card carries the Phase 5 dots
  while a sitting runs.
- **The rectangular card is smaller than drawn.** The real family is about
  177 × 80 pt on a 46 mm watch, not 264 × 118: the tile and the ＋ are 44, the
  ≈ line is not shown (the home-screen widget's small family makes the same
  trade), and the dots sit on a row beneath. The first build at the drawn
  sizes truncated the words on the simulator's Smart Stack.
- **The circular and corner unit word is the bare noun**, "drinks" / "drink"
  (two new strings, reviewed): "drinks today" does not fit a 50 pt disc.
- **The "… hidden" circular is not built**, by the owner's fourth answer; the
  system's redaction shows the drop glyph and the plural words with the
  figure and the band's fill gone — on a day recorded as no alcohol too, so a
  locked watch cannot sort dry days from drinking ones (ADR-0046).
- The circular, corner and inline families were compiled and not rendered on
  a face here; the rectangular card was placed and driven.

## Build order

| Phase | Work |
|---|---|
| 3 | The counter: row, tile, unit word, ≈ line, legend, hint. ＋ / − with haptics and Double Tap. The storage-failure line. **Then the tap to hide** — additive, touches no write path. `removableNewest` at tier 1 before any view code. |
| 4 | The type picker, long-press ＋. Five cases, defaults only. |
| 5 | The session dot row behind its toggle. `dotRow(forCount:maximum:)` at tier 1; the contrast table in its ADR. |
| 6 | The four complication families, the two-entry timeline, and the Always-On check that open question 5 turns on. |

Anything that can be a pure function in `DrinkTrackerCore` should be. Tier 3 on
watchOS is a slow loop, tier 4 is slower, and the thing you most want to be sure
about — CloudKit between phone and watch — is the thing you can least test before
putting it on your wrist.

### ADRs

0042 covers type-only specification and Double Tap; 0044 the dots and the ramp
floor; 0045 the privacy posture. **The tap to hide needs its own record** — it is
a new user-visible claim about what the app shows, and it belongs with 0045.
Write each one in its phase; a decision recorded after the code is a summary, not
a record.

## Files

| File | What it is |
|---|---|
| `Tallyist Watch Counter.dc.html` | The design reference. Open in a browser. |
| `_ds/tallyist-design-system-…/styles.css` | Token sheet the page draws from — the ramp, type, spacing and radii transcribed from `docs/design-system.md` |
| `icons/*.svg` | The repo's own drink and tab glyphs, copied unchanged from `docs/design/icons/icons/` and `docs/design/bottom-nav/icons/` |

### Source read to build this

`DrinkTracker/Features/Today/TodayView.swift`,
`Today/HeroBandLegend.swift`, `Today/PlusModePill.swift`,
`Today/SessionPaceCard.swift`, `Today/TodayDrinkRow.swift`,
`DesignSystem/CountStepper.swift`, `DesignSystem/GlassTokens.swift`,
`DesignSystem/IntensityPalette.swift`,
`Features/Navigation/AppTabs.swift`, `Features/Settings/SettingsView.swift`,
`DrinkTrackerWidget/QuickLogWidget.swift`,
`DrinkTrackerCore/Sources/DrinkTrackerCore/DrinkType.swift`,
`DayIntensity.swift`, `SessionPace.swift`, `StandardDrink.swift`,
`docs/design-system.md`, and `docs/tallyist-watch-plan.md`.
