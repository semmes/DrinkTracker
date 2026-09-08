# Tallyist 1.3 — feature spec

Opened 2026-09-05 with the first 1.3 PR. Same shape as the 1.2 spec: the
project constraints and the App Review claims are hard rules, each feature
states what it adds and what it must not become, and the claims table is the
record of what was said to Apple and why it stays true.

## Project constraints

Unchanged from `docs/tallyist-1.2-spec.md` ("Project constraints" and
"Stop conditions"), and restated platform-neutrally in the product contract
(`semmes/tallyist-product`, `contract/constraints.md`): no account, no
servers, no goals, streaks, scores, or advice, no user data shared between
users, no consumption guidelines, report never instruct, every new
behavioural surface optional and off or neutral. **The 1.2 train is frozen
and awaiting App Review**; a fix that must ship in 1.2 is a new build and a
re-submission, and says so.

## Feature A: Year in review share card — done (ADR-0029)

The owner's design (the claude.ai/design project *Share Card*, bundled at
`docs/design/Share_cards/`) confirmed the month and year cards as shipped
and added one card: a complete calendar year as an image — the year card's
four figures with unlogged days named, then the year's twelve monthly totals
as bars with the Trends chart's monthly average dashed across them.

**What it is.** Offered from the year view's share button for a year that
has ended and has something recorded in it; the button becomes a two-item
menu naming the calendar image and the review. Every bar is the month card's
own total (`monthSummary`); the line is `bucketAverage` over twelve complete
months (total ÷ 12); the figures are `yearSummary`'s. Filename
`tallyist-<year>-review.png`.

**What it must not become.** No delta between years, no rank, no tallest
month named, no arrow, no grade, no per-week or per-day rate, no comparison
to anyone, no prompt or badge inviting the share. The rule that governs
future cards is ADR-0027's, as amended by ADR-0029: a figure the in-app
calendar surface for that period or a period nested in it already shows,
from the same function, or a line the Trends chart already draws under the
same rule.

**Acceptance.** Renders in both appearances; the four figures equal the
year view's card; each bar equals that month's card; the caption states the
line's value; the PNG carries no identifier; nothing persisted; the year in
progress is never offered a review. Tier-1 tests in
`YearInReviewTests.swift`; tier 3 on the simulator (menu, sheet, Preview of
the rendered PNG); the remaining tier-3/4 items are listed in ADR-0029.

## Feature B: The comparison window, and a complete year — done (ADR-0030)

The population card's window follows the record: the trailing four weeks as
shipped, then the trailing twelve months once the first recorded fact is 52
weeks old, because the survey's column is a twelve-month average. The note
names the span. A year that has ended, with a record, gets the same
comparison on the year view under its summary card, from the same summary.
Never on a share card. Region-matched references for the UK and Australia
were sought and not found (every published band is a guideline edge) and are
recorded as candidates in the contract.

**Must not become:** two averages on one card, a delta between windows, a
comparison against any guideline band.

## Feature C: A drinking-days reference — done (ADR-0031)

Two sentences under the volume comparison: the user's days with drinks over
the same window, and NESARC-III's published mean scaled to the same number of
days, whole days. A mean, so never a percentile, never a rank.

## Feature D: By weekday — done (ADR-0032)

A card on Trends: seven rows of the user's own log by weekday, the user's
Friday-to-Sunday and Monday-to-Thursday split, and the published rate of days
with a drink from Liang and Chikritzhs (NHANES 2005–10), whose definition of
the weekend the bundled file carries. No busiest day, no rank, no threshold;
the paper's heavy-episode rate is not bundled.

**Discarded, per the owner (2026-09-05):** everything in the sources review
that a record cannot be placed against without a threshold — guidelines,
clinical definitions, risk estimates, threshold-defined categories, attitude
polling, third-hand concentration figures. The contract's verifier now
rejects them by construction.

## Feature E: The bar readout moves into the chart card's header — done (ADR-0028 amendment)

From the owner's design pass (`docs/design/Bar chart hover states design/`).
The block that reported a selected Trends bar sat *under* the chart, where the
reading hand covers it and the card grew as it appeared. It moves into the
card's header, above the plot, as two states sharing one box over a scaled
floor, so the card's height is identical selected or not. The average line's
label leaves the plot and becomes a legend carrying the line's own value beside
the range's own — two independent facts, never a delta. The grid lines go; the
zero baseline and the dashed average are the only rules left behind the bars. A
rail and a hairline mark the touched bar. The selection lasts the touch, which
is what iOS 26 already did; the ✕ and the fuller block with the type breakdown
narrow to the accessibility-stepped selection.

**Not built, and why it stops here:** the design's fourth figure was a longest
run without a drink, on the header row and as a summary card. That is a
longest-gap record — a stop condition inherited from the 1.2 spec and named by
ADR-0027 — so the slot takes ADR-0006's own second figure, days with none, and
the summary cards are unchanged. The design's live-figure tint is the intensity
ramp's 6+ drinks fill, which would make lightness carry interaction state
instead of magnitude (PRD invariant 10); the figure is `.primary`, with a
costed one-commit route in the ADR if the owner wants the tint.

## Feature F: the longest run with none — done (ADR-0033)

The owner asked for the longest-gap figure the design proposed and ADR-0028's
amendment refused, and asked that the record be opened first. It was, and then
accepted: `docs/decisions/0033-a-run-of-no-alcohol-days-is-counted-from-the-record.md`.

The figure counts **only days explicitly recorded as having no alcohol** — the
owner's answer, and the only definition that survives ADR-0006. Counting
zero-total days instead would mean not logging grows the number, which is the
under-logging incentive the app exists to refuse; here the figure rises only
when the user logs more. A tier-1 test checks that exhaustively over every
three-state window up to length 9 rather than asserting it.

It appears in both places the design drew it: the third fact in the scrub
readout (taking the slot the count of marked days held, so the row stays on one
line), and a card of its own under "Days with no drinks logged" at range level,
reading "None recorded" rather than 0 when there is nothing of the kind in the
log. Accepting it amended `docs/tallyist-1.2-spec.md`'s stop condition and
ADR-0017's hard rule 2 — the display clause only; the persistence clause and
the refusal of a silence-based gap both stand.

## Feature G: Home v2 — the counter carries the day's colour — done (ADR-0034, amended 2026-09-07)

From the owner's Home v2 design (`docs/design/today2/`). Today is rebuilt
around the counter: the number sits in a tile painted by `DayIntensity.bucket`
over the day's region-lensed standard-drink total — the calendar cell's own two
calls, reached by name — with a legend naming the bands; the ramp gains a fourth
step (`#05172e` light, the family's existing step 100 `#cde2fb` dark) and its
buckets become 1–2 / 3–5 / 6–9 / 10+ on Today, the calendar, the year view and
both share cards at once; a two-segment pill under the counter shows which
drink ＋ is following and logs the other in one tap, its selection derived from
`DrinkDraft.dayTemplate`; the typed path is one "Add specific" link into the
drink sheet, which asks for the type and keeps asking for the whole
presentation (the 2026-09-07 amendment: `asksType` is a stored constant, and the
button reads "Log drink" throughout); the typed disclosure, the four quick-add
buttons, the repeat row and `AppSettings.prefersDetailedLogging` are deleted.
The session pace chip carries the same ramp from `.high` up (ADR-0017's
amendment). `CountStepper.hero`'s filled ＋ is the app's one filled circular
control, with no shadow.

**What it must not become.** No count-band reading: the tile bands by standard
drinks like every other ramp surface, never by number of entries, so it can
never say 3–5 where the calendar says 6–9 for the same day. No stored plus
mode: both pill segments log, and the highlighted one is read from the day's
own newest repeatable entry, which is what keeps invariant 1 true for the
widget. No fifth band without re-spacing the ramp: `#05172e` is the family's
floor (L\* 7.6), so a "20+" means re-validating every step, not appending one.
No wash on the pace chip: the drawn 16% tint measured ΔL\* 0.034/0.016 between
adjacent tiers and was not built; and no tint below `.high`, where the ramp's
white ink is under AA at chip size.

**Recorded costs.** Every existing calendar re-shades at the top end — a
10-drink day moves from `#0d366b` to `#05172e`, and share images made before
and after this build differ. A `counterSeed == .usualDrink` user loses the
typed one-tap: the pill is withheld under that seed because ＋ follows the
day-blind plurality rule there, so the deleted repeat row's one tap becomes
the "Add specific" link (the mitigation is costed in ADR-0034 and not built).
The neutral contract (`semmes/tallyist-product` v1.7.0) still pins the
three-bucket ramp and is bumped separately.

**Acceptance.** The tile's colour equals the calendar cell's for the same day
in both appearances and at every band; the legend under the counter names
the four drinking bands (1–2 / 3–5 / 6–9 / 10+) in the calendar legend's
order and words, with the alcohol-free and unlogged states stated in words
beneath the tile rather than as swatches (`HeroBandLegend`'s documented
rule — the calendar legend itself carries six entries); ＋ on Today and on
the widget log the same drink under both seeds;
the pill's selection follows the day's newest repeatable entry and resets at
midnight with nothing stored; "Add specific" keeps its type picker for the
whole presentation; the pace chip is neutral below `.high`; nothing in
`AppSettings` is new. The four-band fold is pinned at tier 1
(`CalendarTests`); the ramp's contrast arithmetic is measured and recorded in
`IntensityPalette`'s doc comment and ADR-0007's amendment, not tested; tier 3
on the simulator over every band, both appearances and
`accessibility-extra-large`; the remaining tier-3/4 items are listed in
ADR-0034.
## Feature H: the drink glyphs — done (ADR-0036)

The owner redrew the type set (`docs/design/icons/`) and asked for the sheet's
type control to show glyph and name together. Eight custom symbols
(`tally.*`) now live in the app's asset catalog, generated by
`scripts/make-drink-symbols.py` from the bundle's SVGs; `DrinkType.symbolName`
names them, and every surface that names a type draws one. The type control
is `DrinkTypePicker`: real buttons in a segmented track, glyph over name,
folding to the region picker's rows at accessibility sizes.

**Must not become:** colour-coded types (one hue, invariant 10 — the glyphs
take the accent and secondary inks and nothing else), a mascot or an
illustration style (design-system §1), a second way to pick a type that
disappears once answered (PRD invariant 2, `asksType`).

## Feature I: Cocktail, and the 40 oz — done (ADR-0035, revised by ADR-0037)

A fifth selectable type, measured as the whole drink in the glass: 4 oz at
15% by default (one standard drink exactly — the 1.5 oz standard pour mixed
to a glass, ADR-0005's clause exercised a second way), sizes of 3 / 4 / 6 oz
plus Custom, the Custom field asking for the ounces in the glass. ADR-0035
shipped it measured by the spirit poured; the owner's review of the control
moved it to the drink (ADR-0037, 2026-09-08). Beer offers the 40 oz bottle
after the can and the pint. No schema change, no CloudKit step, no setting.

**Must not become:** a recipe or serving guide (the pills are three common
sizes, not a menu), a size list that grows on request into a catalogue (the
forty is one retail size the owner named; the 22 oz stays out), a pill that
silently changes the strength (a size is a size; the slider is the only way
strength moves), or a default that under-counts — the default itself lands on
1.0, and the whole-drink model's plausible under-count in Custom is accepted
in ADR-0037 with the field's wording as its defence, not built around.

## Feature J: the comparisons are the reader's to show — done (ADR-0038)

The owner asked whether Trends' insights could be cycled or chosen from the
user's data. The answer separates the app choosing (refused where the rule
would read a figure's direction; allowed where it reads only how much record
exists) from the reader choosing (allowed, ADR-0026's model). What shipped:
Settings → Comparisons, three switches on by default — Weekly average,
Drinking days, Weekend and weekdays — each naming its source; the first
governs Trends and the year view together; the card's source line and note
name only what is shown. And one sufficiency gate the review found: the
weekend comparison waits for four weeks of range, so the Week range shows
the seven rows alone.

**Must not become:** a rule that reads a figure to decide whether to show
it, a rotation, an ordering of the cards by the reader's own numbers, a
switch that defaults off (a change in what everyone sees under the name of
a preference).

## Feature K: the weekly average can read the survey's men's or women's column — done (ADR-0039)

The source prints Men, Women and Total, verified against the PDF; all three
are bundled, each renormalised by its own abstainer share and pinned row by
row at tier 1. Settings → Comparisons → Compare with (All adults · Men ·
Women) chooses the column the weekly average is placed against, on Trends
and the year view; the sentence names the column and the note's drinkers
share follows the file. A choice of reference kept on the device, not a
fact recorded about the reader: the survey publishes no non-binary column,
so none is offered — the default is what a non-binary reader, or anyone who
would rather not say, already has, with no question asked.

**Must not become:** a gender question (no segment that reads the Total
under another name; no stored identity), a column the source does not
print, a percentile for the drinking-days mean or the weekend rate (their
sources publish one figure for all adults), a comparison against any
guideline band.

## App Review consistency

| Claim made in the 1.0 response, kept through 1.2 | 1.3 |
|---|---|
| "no goals, streaks, scores, or advice" | Preserved, with the one figure that took an argument. The longest run with none (ADR-0033) counts only days the user explicitly recorded as alcohol-free, as a maximum over the chosen range, recomputed per render — ADR-0017 rule 2's persistence clause stands absolutely: nothing about gaps goes into SwiftData or UserDefaults — and a run over days with nothing recorded (the silence-based gap rule 2 was written about) stays refused, because there the cheapest way to grow it is to stop logging. No superlative, no comparison between windows, no reaction when it changes, "None recorded" at zero. The owner's framing, 2026-09-07: not a streak but data on how many days the user has or has not had drinks, to read their own pattern. The About sentence, the description's "no streaks" and the support page stay as written. |
| The same claim, on the session pace card — whose rolling count ADR-0017 settled as "styled with weight, never color, icon, or exclamation", and the 1.2 reviewer notes as "not a goal, a streak, or a timer to beat" | Amended by ADR-0034 (ADR-0017's amendment holds the measurements): the rolling count's chip carries the intensity ramp from 6 standard drinks up. That is calendar-scale colour, not urgency styling — `DayIntensity.bucket` over the window's own standard drinks, the same fold and palette as the calendar cell for the day the card sits in, so a shade means an amount on the app's one scale and nothing else; nothing red, no icon, no exclamation, no notification, and the card stays optional and off by default. The reopen path is ADR-0017's one-line revert: `paceBand` returning nil restores the neutral capsule with no other change. |
| "No user-generated content is shared between users" | Preserved. The year-in-review image is a user-initiated one-way export through the system share sheet, carrying only the user's own figures and monthly totals. |
| "No goals, no scores, no comparison" | Preserved. The card's average is the Trends chart's own line, described as "your average" and never as a target; no bar is compared to another, ranked, or related to any guideline. |
| "Nothing leaves the device unless the user sends it" | Preserved. Built at share time, no temp file, no log of the share. |
| "No accounts, no servers, no networking code" | Preserved. No new code path reaches the network. |
| "The population reference is a bundled, published, dated statistic; no thresholds, no guidelines" | Preserved and extended on the same terms: two more bundled, published, dated descriptive statistics (a mean of drinking days, a weekend rate), each named with its source and year; the app still classifies no one and compares to no threshold. The comparison's window follows the record, matching the survey's twelve-month measure. |
| "The population reference is a bundled, published, dated statistic; no thresholds, no guidelines" — continued | Preserved. Each comparison can be turned off in Settings, and the weekly average can be placed against the survey's men's or women's column instead of its total: the same bundled table, three of its published columns, each renormalised by its own stated abstainer share, the sentence naming the column it read. The setting is a preference like Region, stored on the device and on no entry; the app records nothing about the person and asks no gender (ADR-0038, ADR-0039). |
| "No new permissions, no new privacy label categories, no new third-party code" (the 1.2 notes' closing line, repeated for 1.3) | Preserved. Cocktail is a fifth label over the same two facts every typed drink already records — the drink's volume and its strength, defaulting to one standard drink — and the 40 oz is one more preset over them. The drink icons are bundled artwork on the same surfaces. No new kind of data, no new permission (ADR-0035, ADR-0036). |

Reviewer notes and What's New for 1.3 are in `docs/app-store-listing.md`.

## Stop conditions

Inherited from the 1.2 spec. In addition, for share cards: any figure that
is not already on an in-app surface for that period, from the same
function, stops and goes to an ADR first (ADR-0027 / ADR-0029).
