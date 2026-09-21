# Handoff: Health pairing on Trends (the table, the switches, the one-time offer)

Status: design chosen, ready for build. Written 2026-09-19.

This is the design half of `docs/tallyist-health-pairing-plan.md`. That plan stays the authority on behaviour: read "The risk", "The four rules" and "Stop conditions" there before every session, as it says. This document tells you what the three surfaces look like and which existing parts to build them from. Where the two disagree, the plan wins, except for the three changes listed under "What this design changes in the plan", which the owner chose on 2026-09-19.

Target: SwiftUI, iOS 26, the existing `DrinkTracker` app target. No new dependency. Light and dark.

## About the design files

Three HTML drawings sit beside this file. They are references, not code to port. Recreate them in SwiftUI from the repo's own components and tokens.

| File | Surface |
|---|---|
| `Trends Health Table.dc.html` | Trends, scrolled to the new section. Only the last card ("From Apple Health") is new. Everything above it is a rough stand-in for the shipping screen, and the comparison card carries bracketed placeholders on purpose |
| `Settings Switches.dc.html` | The new Settings section with four switches |
| `The Offer.dc.html` | The one-time offer card, in the table's own shape |

Open them in a browser; `support.js` beside them is the same file the other design folders carry.

Every health figure in the drawings is invented sample data. Where this document names a Swift symbol, call the symbol instead of copying the number. Hex values appear nowhere in the build: neutrals are system semantic colours, and the only brand colour on these surfaces is the accent on the two offer buttons and the switches.

## What this design changes in the plan

1. **No metric picker.** Plan decision 2 put a picker on Trends. The chosen design has none: the Settings switches are how the user picks, and every metric that is switched on and passes its gate is a row in one table. The user still chooses the question, one switch at a time. ADR "the app pairs, it does not conclude" should say so.
2. **Short column heads.** The owner shortened the heads to DRINKS and NO DRINKS. The plan's labels were "Nights you logged drinks" and "Nights you didn't". See "Copy" below: the short heads need the long phrases in VoiceOver and in the source note, and one of them needs a second look in the copy review.
3. **The offer covers the table, not one metric.** It shows every row the build ships, with the figure cells empty, and one button.

Also: **the plan's ADR numbers are taken.** It reserves 0046 to 0049, but `docs/decisions/` already holds 0046 (the face shows today's count) and 0047 (the widget redraws). Number the four health ADRs from the next free number when you write them, and fix the plan's references in the same commit.

## Surface 1: the table card on Trends

### Placement

Below `ComparisonsSection`, last thing on the screen. A `SectionLabel` reading "From Apple Health", then one card on `glassSurface()` at the standard card radius and `cardPadding`. Screen margin and block spacing as the rest of Trends.

Build it as its own section view (suggested: `Trends/HealthPairingSection.swift`) that resolves every row's condition once and shows the heading only if at least one row survives. Follow `ComparisonsSection`'s rule: the heading's condition is the literal disjunction of the rows' conditions, so a heading can never outlive its content. No row re-checks its own switch.

### Layout

One grid, three columns, in the idiom of `WeekdayCard`. Reuse `ComparisonTableParts` (column head, the `@ScaledMetric` figure column, the fold rule) instead of writing a second copy.

| Part | Spec |
|---|---|
| Header row | One line. Column 1: `CardTitle` "Your averages". Columns 2 and 3: `.columnHead` in `.primary` ink, right aligned, "DRINKS" and "NO DRINKS". All three share a baseline. 8 pt below, then a full-strength separator |
| Metric row | Column 1: metric name in subheadline, and under it the night counts in caption, secondary ink, with the two numerals in `.rowCount` primary ink: "18 and 31 nights". Columns 2 and 3: the figure in `.rowFigure` (rounded, tabular), right aligned, with its unit in default SF caption, secondary ink |
| Between rows | Hairline (the weekday table's lighter rule). 9 pt vertical padding per row |
| Temperature note | Caption, secondary, under the last row, only when the wrist temperature row is present: "Wrist temperature is set against your own median over these 13 weeks." The span follows the range |
| Source line | Hairline, then `SourceDisclosure` with a 44 pt row: "From Apple Health, last 13 weeks". The span follows `TrendRange` |
| Figure columns | 84 pt each in the drawing. Use the scaled metric from `ComparisonTableParts` |

Rows appear in the Settings order: resting heart rate, sleep, heart rate variability, wrist temperature.

The numerals are rounded because they are the user's own data. Units and labels stay default SF. No colour anywhere in the card. No delta, no arrow, no sign on a difference, no chart.

### Figure formats

| Metric | Figure | Unit |
|---|---|---|
| Resting heart rate | whole number | bpm |
| Sleep | "6h 12m", minutes zero padded | none |
| Heart rate variability | whole number | ms |
| Wrist temperature | signed, two decimals, U+2212 for minus: "+0.21", "−0.08" | °C |

The sign on wrist temperature is a sign on a deviation from the user's own median, not on the difference between the two columns. It still sits close to rule 1, so give it its own line in the copy review. Locale decides °C or °F.

### Source note (disclosure open)

"Two averages of your own Health data, over the nights counted here. Drinks means nights you logged drinks. No drinks means every other night. Read on this iPhone. Tallyist keeps none of it."

The middle two sentences are new since the drawing, and they carry the whole definition of the two columns now that the heads are short. They depend on how Phase 1 defines the second bucket: rewrite them to match the domain exactly, and say plainly whether a night with nothing logged is counted there.

### States

| State | Behaviour |
|---|---|
| Switch off | No row |
| Switch on, gate not met in either bucket | No row. No caveat, no asterisk |
| Switch on, no Health data (denied, unsupported watch, not worn, second device) | No row. These four cases are one state. Show nothing, say nothing, prompt never |
| No rows at all | No card and no heading. Absence, not an empty state |
| HRV at Week or Month | No row, if Phase 5 settles on wide ranges only. The Settings caption already says "Shown at Quarter and Year" |
| Wrist temperature row absent | The temperature note goes with it |
| Loading | Nothing until the query returns, then the card appears with `.smooth(duration: 0.25)` and opacity. No skeleton and no spinner: a placeholder that later vanishes would reveal the no-data state |
| Range change | Figures crossfade (`.contentTransition(.opacity)`, `.smooth(duration: 0.22)`). Never a numeric roll: the subject changed, not the value |

The gate is per row and per range, and both buckets must clear it (plan rule 3).

### Accessibility

Each metric row is one VoiceOver stop with the label on the name cell, as the weekday rows do. Speak the long phrases, not the column heads: "Resting heart rate. On nights you logged drinks, 62 beats per minute, over 18 nights. On other nights, 58 beats per minute, over 31 nights." No comparative word in the label either.

From `.xLarge` up, fold to stacked rows exactly as `ComparisonTableParts.folds` does for the weekday table: metric name, then one line per bucket with its label written out. Render it at AX sizes and check it, do not reason about it.

## Surface 2: Settings switches

A new `SettingsSection` titled "Apple Health on Trends", placed directly after the Comparisons section. Four `ComparisonToggle`s, no accessory, in this order and with these captions:

| Switch | Caption | Setting (suggested name) |
|---|---|---|
| Resting heart rate | One figure a day, from your watch | `showsRestingHeartRatePairing` |
| Sleep | Time asleep on nights you wear your watch | `showsSleepPairing` |
| Heart rate variability | Shown at Quarter and Year | `showsHRVPairing` |
| Wrist temperature | Set against your own median | `showsWristTemperaturePairing` |

All default off. Store them where the three comparison flags live. These are preferences, not Health data, so storing them does not touch the read, compute, render, discard rule.

Footnote: "Each switch puts one figure from Apple Health beside your log on Trends. Read on this iPhone, never stored, never sent. Sleep, heart rate variability and wrist temperature come from nights you wear your watch to bed."

That footnote is the one place the app mentions wearing the watch to bed. Nothing else may.

Turning a switch on calls `HealthKitService.requestAuthorization()` with the read types. HealthKit only prompts for undetermined types, so this is silent for anyone who already answered. Turning a switch on never shows an error or a hint if no data follows, because a denied read is invisible.

Only ship the switches for metrics that are built. Phase 3 ships one switch. Do not draw disabled switches for later phases.

The switch tint in the drawing is the accent fill. Use whatever the existing comparison switches use.

## Surface 3: the one-time offer

### When

It appears in the table's position on Trends, under the same "From Apple Health" heading, when all of these hold: the drink log clears the sample-size gate on the drink side for the current range, no pairing switch is on, and the offer has never been answered. Persist one boolean (suggested: `hasAnsweredHealthPairingOffer`). Not in onboarding, not as a sheet, not as a notification.

### Layout

The table card itself, with the header row and one row per shipped metric, names only. Every figure cell reads "– –" in tertiary ink. Then:

- Caption with the drink-side counts, the only real numbers on the card: "18 nights with drinks logged and 31 without, last 13 weeks". Before access, these come from the drink log alone, so they are the same for every row and are stated once.
- Hairline, then body text: "Your watch already records these. Tallyist can show them here, beside your log. They are read from Apple Health on this iPhone and never stored."
- Primary button, accent fill, full width, 50 pt: "Show these on Trends".
- Text button, accent ink, 44 pt: "Not now".

One primary action on the card, a verb phrase, per the design system.

### Behaviour

"Show these on Trends" sets the offer answered, turns on every shipped pairing switch, and calls `requestAuthorization()`, which presents the system sheet listing only the new read types. The card then becomes the real table or, if no data comes back, disappears. Both outcomes are final and silent.

Decided by the owner, 2026-09-19: accepting turns on every shipped switch, and the user turns off the ones they do not want in Settings afterwards. The switches stay independent after that, and the system sheet still lets them deny any single type.

"Not now" sets the offer answered and removes the card with the structure-change animation. Nothing in the app mentions it again. The switches remain in Settings.

VoiceOver reads the placeholder cells as nothing at all. The card's label is the body text; the row names follow.

## Decisions

Decided by the owner, 2026-09-19:

1. **A metric that ships later arrives switched on for anyone who accepted the offer**, and shows once the user grants its read. Its type is undetermined in HealthKit, so the next `requestAuthorization()` lists it alone. Make that call when the user next opens Trends, not at launch, so the system sheet appears beside the table it feeds. For anyone who chose "Not now", or who has since turned every switch off, a later metric arrives switched off and nothing asks.
2. **The heads stay DRINKS and NO DRINKS.** They are the concise form, and the app already uses "drinks" and "drank" interchangeably. The source note carries the definition of the second column, so write that note to match whatever Phase 1 puts in the bucket (ADR-0006 separates a day recorded as no alcohol from a day with nothing logged).

3. **The card title is "Your averages".** It replaced "The night after", which implied a sequence and so sat one step from "the effect of", and which was not true for resting heart rate, a daily figure rather than a nightly one. "Your averages" names what the figures are, claims no order, and stays true whichever way Phase 0 pairs a day's value to a night. For the same reason the source note no longer says "and the sleep that followed".

Still open, and a Phase 0 question rather than a copy one: **which day's resting heart rate pairs with which night.** The title no longer depends on the answer, but the domain does.

## Copy

Every string above goes through `docs/copy-review-1.4.3.md`, twice, per the plan. The strings, collected: "From Apple Health", "Your averages", "Drinks", "No drinks", the four metric names, "N and N nights", the temperature note, "From Apple Health, last N weeks", the source note, the Settings title, four captions and footnote, the offer caption, body and two buttons, and the VoiceOver sentences. No comparative adjective in any of them, including the spoken ones. No exclamation marks.

## Acceptance checks

- With all four switches off and the offer answered, Trends is pixel-identical to today.
- Revoking Health access in Settings makes the card vanish with no message, and nothing about it remains in SwiftData, UserDefaults, CloudKit or the App Group beyond the five booleans.
- A metric below its gate in either bucket shows no row at every range.
- The heading never renders without a row or the offer beneath it.
- No view in this feature imports a colour other than system semantics and the accent.
- The header row is one line at the default size on a 375 pt phone. Measure it.
- At `.xLarge` and above the table folds and no metric name hyphenates.
- Once answered, the offer never appears again across range changes, relaunches and iCloud sync (a delete and reinstall aside).
- VoiceOver on a row speaks both long bucket phrases, both figures with units, and both night counts.
- Tier 4: Tallyist's sleep figure for a night matches the Health app's.

## Housekeeping

Add a "Paired-figure table" row to `docs/design-system.md` section 6, in the shape the other card rows use, citing this folder as the design reference.

This folder arrived untracked in the main clone. `scripts/sync-main.sh` pauses on any uncommitted file, so commit it (or stash it) before expecting main to fast-forward again.
