# 0033 — A run of days with no alcohol is counted from the record, never from silence

**Status:** proposed · **Date:** 2026-09-05 · **Reopens:**
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

**A known hole in (b), and it must be closed in the same change.**
`CalendarDay` carries `hasEntries` and `isMarkedAlcoholFree` independently, and
the store can hold a day with both: `DrinkRepository.saveOrThrow` deletes
markers on a drink's day and `markAlcoholFreeOrThrow` refuses a day with
entries, but neither guard re-runs on a row CloudKit's mirroring inserted — the
repository's own comment concedes "two devices writing before CloudKit merges
can leave two". `summary(of:)` classifies such a day as `.drinks`; delete the
entry and the dormant marker is revealed and can join two runs. That is an
omission lengthening the figure, i.e. definition (a)'s failure re-entering
through the back door. It is closed in the repository (reconcile on read, so the
dormant marker is dropped when its day has entries), not in the fold.

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
- **Where it appears** is deliberately narrow, and is the part most worth
  arguing with: the scrub readout's facts row already carries three figures
  measured at the full content width, so a fourth needs the row to earn its
  space or the design to give something up. Proposed: the range-level figure on
  the Trends summary cards (where "longest run with none" is checkable against
  the log), and the per-bar figure only if the row still fits at the default
  text size — measured, not assumed, exactly as the 3.7pt facts-row measurement
  in ADR-0028's amendment was.
- **Arithmetic in `DrinkTrackerCore`**, tier-1 tested, over `[CalendarDay]` —
  the same input `summary(of:)` folds, so the run and the counts beside it
  cannot disagree about what a day is. The lemma the suite pins: *no omission
  over that input can raise the figure* — deleting entries never creates a
  marker — plus clipping, empty windows, and the all-marked window.

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
