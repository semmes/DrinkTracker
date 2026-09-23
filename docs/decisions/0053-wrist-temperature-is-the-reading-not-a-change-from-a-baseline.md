# 0053 — Wrist temperature is the reading, not a change from a baseline

**Status:** accepted · **Date:** 2026-09-22 · **Relates to:** ADR-0048 (the
nights, the buckets, the sleep-day filing and the base gate this row uses
unchanged); ADR-0049 (the read layer this row's query joins); ADR-0050 (the
card this is the fourth and last row of, and rule 1 — both sides, never a
delta — which decides this record); ADR-0051 (the offer, and how a later
metric arrives); ADR-0052 (the row before it, whose "the figure the Health
app shows on that date" this record cannot match, and says why);
`docs/tallyist-health-pairing-plan.md` ("Sleeping wrist temperature", "The
four rules"); `docs/design/health-pairing/README.md` (the figure table, the
temperature note, surface 2's caption and footnote);
`docs/health-pairing-phase-0-findings.md` (§2, "What it forces")

The sixth of the health pairing's records, written in Phase 6 with the row.
It carries the one piece of new statistics the plan said this feature would
need — the baseline — and decides not to have one.

## Context

The plan names sleeping wrist temperature as the last of the four metrics
and gives it two complications nothing else here has. The first is that the
hardware restriction is invisible: a watch that cannot measure it produces
nothing, and the plan says to treat that exactly as a denied read — show
nothing, explain nothing, never prompt. That costs no decision; the empty
state is already one state (ADR-0049). The second is the one this record
exists for: "the raw value is not the interesting quantity. The Health app
presents wrist temperature as a deviation from the user's own baseline,
because an absolute figure means nothing to a reader. Tallyist would have to
compute its own baseline, which is a new derived statistic and therefore
something to define and defend rather than assume. Phase 6 decides it: the
user's own median over the displayed range is the obvious candidate, stated
as such in the UI." The design drew that candidate: a signed figure to two
decimals ("+0.21", "−0.08"), a note under the row — "Wrist temperature is
set against your own median over these 13 weeks" — and a switch captioned
"Set against your own median".

**What Phase 0 found.** Apple's own words: the watch reduces a night of
five-second readings to "a single value that represents the wrist
temperature over the entire night", corrects it for environmental bias, and
"records the absolute wrist temperature value; however, Health displays this
data as a relative value, based on a person's baseline", a baseline Health
needs about five nights to establish and that is not in HealthKit — no
header in the 27.0 SDK names it, and how Health computes it is undocumented.
So whatever Tallyist shows, it cannot be the number in the Health app for
the same night unless it reproduces a statistic Apple does not publish.

**The arithmetic that decides it** (Phase 0's §2, "What it forces", item
3, made explicit here). Take a range's nights with a reading: the drink
bucket, *n_D* nights with mean reading *m_D*; the no-drinks bucket, *n_S*
and *m_S*; and the nights with nothing logged, *n_U* and *m_U*. Measure
every night against one baseline *b* and average the deviations per bucket.
The drink column shows *m_D − b*, the no-drinks column *m_S − b*, and,
weighted by their nights, the three groups' deviations sum to the range's
own mean less the baseline, *N(m − b)*. With *b* the median of those same
nights, *m − b* is the gap between a mean and a median, which for a
season of wrist temperatures is close to zero; and for a reader who logs
most nights, *n_U* is small. So *n_D(m_D − b) ≈ −n_S(m_S − b)*: unless the
columns barely differ, or the range's readings are skewed by more than the
smaller column's deviation (a run of hot nights can do it), **the two
columns land on opposite sides of zero**, and their signs, read together,
say which column is the higher one. "+0.21" beside "−0.08" is the
direction of the difference between the columns, stated twice. Rule 1 says
the app never signs that difference; a baseline taken from the same nights
signs it in two halves nearly always, and the exceptions do not rescue it —
a pair that happens to share a sign still shows two deviations a reader
compares. The plan's own note that the sign "still sits close to rule 1"
was the caution; this is the arithmetic behind it.

A baseline from *other* nights — the reader's median over the year before
the range, say — moves *b* and loosens the tie, but leaves two signed
figures that a reader reads against each other, and adds a second window
the note would have to name. A baseline over the no-drinks nights alone is
worse: the no-drinks column becomes zero by definition and the drink column
becomes the difference itself.

**The alternative is the idiom of every other row.** HealthKit stores the
reading. "62 bpm" beside "58 bpm" is two readings; "36.62 °C" beside
"36.30 °C" is two readings. The plan's "an absolute figure means nothing to
a reader" is true of one figure alone, and this card never shows one alone:
the pair is the observation, as it is for every row, and the reader does the
subtracting (ADR-0050's first consequence). What is lost is agreement with
the number in the Health app, and that is lost either way — with a median,
Tallyist's deviation would differ from Health's on every night — so the
honest course is to show the reading and say, once, that Health shows the
same nights as a change from a baseline of its own.

## Decision

The fourth row is **the reading**: the mean of the watch's nightly wrist
temperature over each bucket's nights, as stored, with no baseline
subtracted, no sign and no deviation — the plain idiom of the three rows
above it. Each night's reading (Apple's one aggregated sample) is filed
under the night whose sleep day holds the sample's middle
(`HealthPairing.nightlyValues(attribution: .sleepDay)`, the rule ADR-0048
built for it), behind the base gate of fourteen nights in each bucket, at
every range the gate allows.

**The unit is the one the reader's Health app shows.** The read returns
Celsius, the stored unit; `HealthKitService.preferredTemperatureUnit()`
asks HealthKit for the reader's preference for this type
(`preferredUnits(for:)`: their own choice in Health for a type the app is
authorized to read, the locale's default otherwise, and an error while the
type's status is not determined), beside a read that returned samples —
the one place the answer is the reader's own, and a read that returned
nothing draws nothing to convert; the figure converts with the offset,
through Foundation's own conversion, at the moment it is drawn — exact for
a mean, because the conversion is affine. Nothing is converted before the
domain sees it and nothing is kept. Celsius for every kind of nothing.

**The figure is to the hundredth of a degree** — "36.62 °C", "97.92 °F" —
the precision the design drew ("+0.21", "−0.08"; the Health app's own
deviation chart shows two decimals as well, its list of readings is the
owner's to check), by the same rounding as the other rows, the unit's
symbol in the caption face beside it as "bpm" and "ms" are; spoken as
"36.62 degrees Celsius" from the same conversion and rounding.

**The design's temperature note stays, and says something else.** Under the
last row while the wrist temperature row is on the card: "Wrist temperature
is the overnight reading your watch records. Apple Health shows it as a
change from a baseline of its own." It exists so a reader who checks a night
in Health, and finds a signed deviation where Tallyist shows a reading,
knows why the two differ. It is not on the offer, which shows no figure to
explain.

**The switch** is "Wrist temperature" over "One figure a night, from your
watch" — resting heart rate's caption with the night in place of the day,
because that is what the reading is — fourth in the Settings order, off by
default, and it arrives switched on for anyone with **any** of the three
earlier switches on (ADR-0051's rule, extended once more: the three before
it, or-ed, decided once when its key is first missing and written). The
footnote's third sentence names it: "Sleep and wrist temperature come from
nights you wear your watch to bed" — true of this figure, which the watch
takes during sleep, where it was not true of heart rate variability
(ADR-0052).

**The read** is a sample query (`HealthKitService.wristTemperature`), not a
daily statistic: the sample is stamped during the sleep and may start before
midnight, and a calendar-day bucket would file such a night under the day
before it, where the sample's own span lets the domain file it by its
middle. Samples ending inside the window, `.strictEndDate`, as sleep's are;
one breadcrumb per query, `wrist temperature · N days · T s`.

**The hardware restriction is the empty state.** A watch that cannot
measure it — Apple lists Series 8 and later, every Ultra and the SE 3 — is
a read that returns nothing, which is the same state as a denied read; no
caption, note or reviewer note names a model.

## Consequences

- **The figure is not the Health app's number for the night.** Health shows
  "+0.21 °C"; Tallyist shows "36.62 °C". The note says why, once. The
  plan's cross-check — the Health app's own figure for a night — holds for
  the *reading* only where Health exposes it (its list of samples), not for
  the chart, and the owner's tier-4 check is against that list.
- **One figure alone means little; the pair is the observation.** Accepted,
  as for every row. A reader who wants a baseline has the no-drinks column,
  which is theirs to read that way; the app does not.
- **The columns widen a little.** Measured with CoreText (calibrated as
  before): "36.62 °C" is 64.0pt in the card's tabular figures with the unit
  beside it, wider than "6h 12m" (58.5), so the two numeric columns go from
  133.5 to 139.0pt; on a 375pt phone the leading column keeps 156.0pt with
  four rows and 141.4 against the widest figures ("100.12 °F", a reading
  over 37.8 °C, and three-digit heart rates and milliseconds) — "Heart rate
  variability" at 138.3 and "Wrist temperature" at 123.9 stay on one line
  everywhere. The header row is unchanged at 213.9.
- **The offer shows four rows** and its acceptance turns on four switches,
  asking for the four types in one sheet (ADR-0052's named exception). The
  note is not on it.
- **A fourth caption on the card.** The note is one more sentence of
  secondary caption under the rows, on every card that has the row.
- **The unit follows Health, not the locale directly.** The design said
  "locale decides °C or °F"; Health's preference *is* the locale's default
  until the reader changes it in Health, and then it is what the reader
  sees there. If `preferredUnits` cannot answer, Celsius, which is what the
  watch stores. A change made in Health lands on the next read — the card
  does not observe `HKUserPreferencesDidChange`, so a reader who switches
  units with Trends open sees the new unit on their next visit or range
  change (rendered: the next read after the switch drew "36.60 °C").
- **Five design lines did not survive**, all listed once here: the signed
  two-decimal format with U+2212; the note's text and its span; the
  caption "Set against your own median"; the footnote naming heart rate
  variability among the nights-in-bed metrics (ADR-0052's cut stands); and
  the row's own line in the copy review, which the design reserved for the
  sign — it is there, and says why there is no sign.
- **Nothing new is written.** The switch and the inheritance are
  preferences beside the others; the read leaves its one breadcrumb per
  query; the unit is a value held with the render's figures and dropped
  with them. Checked the way the earlier phases checked it, by grepping
  every added line for the write, store and log APIs.

## How to reopen

- **A baseline after all.** If the owner wants the Health app's shape, the
  domain fold is one call (`nightlyValues` → subtract → `figures`), and the
  decision to reopen is not this record's but rule 1's: two signed
  deviations from a baseline built from the range's nights sign the
  difference between the columns in two halves (the arithmetic above), and
  a baseline from another window leaves two signed figures read against each
  other. Argue the rule first, then the window and the statistic.
- **Health's own baseline**, if HealthKit ever exposes it. Then the row could
  show the number Health shows, and the sign would be Apple's convention to
  reproduce rather than a statistic of Tallyist's own; the tie would still
  hold and would still want arguing.
- **One decimal**, if the hundredths read as noise on a real display. One
  `precision` in two places; the Health app's precision was the reason for
  two.
- **The note**, if a reader who never opens the Health app finds it
  explains a difference they never meet. It is one `if` on the card.
- **A live unit change**, if the next-read behaviour above reads as a
  stale card: observe `HKUserPreferencesDidChange` and re-read, one
  notification in the model.
