# 0033 — A run of days with no alcohol is counted from the record, never from silence

**Status:** accepted · **Date:** 2026-09-05 · **Reopens:**
`docs/tallyist-1.2-spec.md`'s stop condition "A streak counter or a
longest-gap record", ADR-0017 hard rule 2, and ADR-0027's stop-condition list ·
**Relates to:** ADR-0006 (a summary, not a score — its under-logging test is
the whole of this record), ADR-0001, ADR-0007, ADR-0011, ADR-0025, ADR-0026
(`summary(of:)`, the one classifier), ADR-0028 and its amendments, PRD
invariants 8 and 9

## Context

The owner asked, on 2026-09-05, for the longest-gap figure the design pass
proposed and ADR-0028's amendment refused, and asked that this record be opened
before it is built: *"Yes I do want it to count longest gap record. Let's open
the ADR first."* Asked which days count, they answered: *"Only days you
explicitly marked as no alcohol get logged as a 0."*

This reverses a refusal the repository made in writing, twice, and it crosses
rules written as law. They are quoted here in full, because a record that
reverses a rule it does not quote has slipped past that rule rather than
overturned it.

**ADR-0017, "Three hard rules, settled here as law", rule 2:**

> **Nothing about gaps is ever persisted or displayed as a record.** No
> longest-gap, nothing in SwiftData or UserDefaults. A session ending is the
> absence of a value, not an event.

**`docs/tallyist-1.2-spec.md`, Stop conditions:**

> A streak counter or a longest-gap record

**ADR-0028's amendment**, eleven days later, refusing the same figure:

> a run is a number that can be protected, which is the under-logging incentive
> ADR-0006 exists to refuse.

The owner has authorised the reopen. Authorisation settles *whether*. It does
not settle *which figure* — and the two candidate definitions are not variants
of one idea. They are opposite incentives wearing one word.

## The definitions, and why one of them cannot ship

A run of days "without a drink" can be counted two ways, differing exactly in
what a user's *omission* does to the number.

**(a) Days whose total is zero** — the population the "Days with no drinks
logged" card already counts: explicit markers *and* days with nothing recorded
at all. Under (a), **not logging grows the number.** The cheapest way to
lengthen a run is to record nothing; recording a no-alcohol day earns nothing,
because the day already counted; and logging a drink onto a blank day shortens
it. Worse than the composite score ADR-0006 refused: a score is *protected* by
omission, this is *manufactured* by it. It also moves discontinuously — two
six-day stretches split by one drinking day become thirteen the moment that one
drink goes unlogged, so the reward for omitting a single entry is thirteen, not
six. **(a) fails ADR-0006's reopen bar** — "the feature has to be safe for
someone having a bad month, because that is precisely who is most likely to stop
logging" — and the design prototype's blank-week `runNone 7` is exactly (a).

**(b) Days explicitly recorded as no alcohol** — `AlcoholFreeDay` markers, the
ADR-0025 population, including the ones another app's Health zero put there.
Under (b) the only edit that lengthens a run is an affirmative record. Deleting
an entry, or never making one, leaves that day either still a day with drinks or
a day with nothing logged; neither is a marker; only a marker extends a run.
**The incentive inverts: the figure grows when you log more.** This is the
owner's answer, and it is the only one that survives ADR-0006.

The cost of (b), stated rather than hidden: a fortnight genuinely without
alcohol that nobody marked reads as 0. That is the honest reading — the app does
not know about it — and it is the same rule the calendar already applies, where
an unmarked day is blank rather than green.

**A hazard checked and found already closed, recorded so it is not re-raised.**
`CalendarDay` carries `hasEntries` and `isMarkedAlcoholFree` independently, and
CloudKit can merge a marker onto a day that has entries, so the worry was: delete
the entry, and a dormant marker surfaces and joins two runs — an omission
lengthening the figure. Two things close it. `DrinkRepository.saveOrThrow`
already deletes **every** marker on a drink's day, and its comment names this
exact case: *"Leaving it dormant would be worse than a visible contradiction —
it would resurrect the moment the entries were deleted"*, and *"Every marker on
the day, not the first: two can land on one day when two devices act before
CloudKit merges."* And the fold makes entries beat markers regardless, so while
the entry exists the day is `.drinks` and cannot extend a run. The residue — a
marker mirrored in *after* the save and never reconciled — does not breach the
safety property either: the run still cannot be lengthened by *failing to
record*, only by a marker the user affirmatively made. No repository change is
needed, and an earlier draft of this record claiming otherwise was wrong.

## Decision

**Build (b).** One figure: the longest run of consecutive days *recorded as
having no alcohol*, over the picked Trends range.

- **It is a maximum over a bounded window, never a running total.** ADR-0017
  rule 1 forbids "an increasing time since last drink" outside a session; this
  is not that. It never counts forward from today, has no current value, and
  cannot tick upward while the app sits open. It is a property of a window of
  the past, recomputed from the log like every other figure on the screen.
- **Rule 2 is narrowed, not deleted.** Its persistence clause stands
  absolutely: nothing about gaps goes into SwiftData or UserDefaults, and this
  figure is derived per render like `daysWithDrinks`. Its *display* clause is
  what this record reopens, and only for a run built from affirmative records
  inside a chosen window — not for the silence-based gap rule 2 was written
  about. Rules 1 and 3 are untouched.
- **The run is clipped to the window** and never extends past its edges. A run
  crossing a bucket boundary is an artefact of the bucket, not a fact about the
  user; the figure is honest about the days it can see, as `summary(of:)` is.
- **Never a record to beat.** No "best", no "longest ever", no all-time scope,
  no comparison between windows, no celebration when it grows, and no separate
  line when it falls. It is one figure among ADR-0006's others, in the same
  type, with a noun that describes it and no verb that praises it.
- **Where it appears**, as built: both places the design pass drew it. In the
  scrub readout's facts row it is the **third** fact — "1 none in a row" — which
  is the design's own third fact, and it takes the slot the count of marked days
  held rather than adding a fourth. That is the design as drawn, and it is what
  keeps the row on one line: the row measured at the full content width with
  three facts, so a fourth would have wrapped, and a wrapped row is the card
  growing under the reading hand. The count it displaces is still spoken in the
  readout's accessibility label and still printed in full by the block a stepped
  selection shows, so no ADR-0006 figure is lost from the screen. At range level
  it is a card of its own beneath "Days with no drinks logged", in that card's
  shape so the two figures about days without drinks read as a pair. Verified by
  measurement: the card's chart baseline and bottom edge sit at 562.00pt and
  595.67pt in **both** readout states, unchanged by the new fact.
- **At zero the range card says "None recorded", not 0.** A bare 0 reads as a
  run of length nothing; the honest reading is that there is nothing of this
  kind in the record. A user who marks no days sees that, permanently, and it
  must never be "fixed" by falling back to (a).
- **Arithmetic in `DrinkTrackerCore`**, tier-1 tested, over `[CalendarDay]` —
  the same input `summary(of:)` folds, so the run and the counts beside it
  cannot disagree about what a day is. The lemma the suite pins is checked
  **exhaustively rather than asserted**: over every window of every three-state
  day up to length 9, turning any one day into "nothing recorded either way" —
  which is what not logging produces — never raises the figure. Plus clipping at
  the window's edge (a marked stretch straddling two weeks is 3 and 4, never 7
  twice), empty windows, the all-marked window, and the bound
  `run <= daysAlcoholFree`.

## Consequences

- `docs/tallyist-1.2-spec.md`'s stop list and ADR-0017 rule 2 are amended in the
  same change that builds this, naming (b) and keeping (a) stopped. A stop
  condition that is quietly contradicted is worse than one that is argued.
- The repository gains a reconciliation for the dormant-marker case, which is a
  correctness fix with or without this figure.
- The 1.2 spec's "three hard rules" heading — "the difference between a
  measurement tool and a shame mechanic" — now has one rule with a stated
  exception. That is a real loss of absoluteness, and it is the price the owner
  has chosen to pay for the figure.
- A user who marks nothing sees 0 forever. That is not a bug and must never be
  "fixed" by falling back to (a).

## How to reopen

If the figure is ever wanted over unmarked days — definition (a) — that reopens
ADR-0006 head-on and needs an answer to the under-logging test above, not a
convenience argument. If it is ever wanted as a *current* run, that is ADR-0017
rule 1 and this record does not touch it. If it acquires a superlative, a
comparison between windows, or any reaction when it changes, it has become a
streak and this record is the thing being violated.
