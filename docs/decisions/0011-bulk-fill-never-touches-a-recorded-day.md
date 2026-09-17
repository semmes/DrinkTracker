# 0011 — Bulk fill never touches a recorded day

**Status:** accepted · **Date:** 2026-08 · **Relates to:** ADR-0003, ADR-0009,
PRD invariant 7

## Context

The calendar gained drag-to-select: touch and hold a day, drag across a run of
days, and apply one answer — zero (alcohol-free) or N drinks — to all of them at
once. It exists for the infrequent logger, for whom most days carry the same
answer and a per-day round-trip through the day sheet is the reason the record
has gaps.

A bulk gesture is a coarse instrument aimed at precise data. The design question
was what happens when the swept run includes a day that already has a record —
logged entries, or an alcohol-free marker.

## Decision

**A day with any record is skipped, always.** The bulk sheet filters them out
before writing, states how many it is skipping ("3 days already have a record
and will be kept"), and its action button counts only the days it will actually
write. There is no overwrite option, no merge option, and no "apply anyway".

Mechanics that follow from it:

- The count applies **per day**, with the same semantics as the day sheet: zero
  records an `AlcoholFreeDay` marker; N logs N separate entries (ADR-0003) at
  noon, seeded once from the usual drink (`DrinkDraft.quickCount`) — captured
  before the loop, so every day gets the *same* drink rather than a seed that
  drifts as the loop's own writes change what is most recent.
- The repository remains the backstop: `markAlcoholFree` refuses a day with
  entries regardless of what the view asks, so even a stale selection cannot
  create a contradiction.
- Selection is a contiguous run within the visible month, past days only. The
  hit-test arithmetic lives in `MonthGrid.dayIndex(row:column:)` and
  `days(between:and:)` in DrinkTrackerCore, where it has tests; the view only
  converts points to rows and columns.
- **VoiceOver's path is the per-day sheet.** A drag across a grid is not a
  gesture VoiceOver users perform; every cell remains an individually
  activatable button opening `DayLogSheet`, which can express everything the
  bulk sheet can, one day at a time. Bulk fill is an accelerator, not the only
  route.

## Consequences

- Sweeping over a logged evening can never destroy it. The worst a careless
  drag can do is add records to blank days — every one individually visible,
  editable, and deletable afterwards.
- Fixing a recorded day stays a deliberate, single-day act. That is friction,
  and it is the point: precise data should take precise input to change.
- The skip note is honest about the gap between what was selected and what will
  be written, so the button's day-count never surprises.

## How to reopen

If real use shows people repeatedly selecting runs *because* they want to
correct recorded days in bulk (rather than fill blanks), that is a different
feature — bulk *edit* — and it needs its own confirmation design. Extending
bulk *fill* to overwrite is not the answer; this record exists to say why.

---

## Amendment (2026-08): the action bar

The *Tallyist iOS Prototype* handoff restyled the surface: releasing a drag now
parks the selection under a bottom action bar (live count, one-tap **Mark no
drinks**, **Log drinks…** into the bulk sheet, dismiss) instead of opening the
sheet directly. The user directed keeping this record's semantics under the
prototype's UI: nothing about *what gets written* changed — recorded days are
still never touched, the sheet still says what it skips, and `markAlcoholFree`'s
refusal still backstops both paths. The bar's cell highlight makes the rule
visible before the action: the accent wash lands only on days a bulk action can
write to; recorded days in the run get the ring alone.

---

## Amendment (2026-09-16): the backstop reads the day, or refuses

"The repository remains the backstop" was not true when the read under it
failed. `markAlcoholFree` asked whether the day had drinks through
`drinks(on:)`, which turns a failed fetch into an empty day — so a store that
could not be read let a day *with* drinks be marked, from bulk fill, the
calendar's action bar, Today, Siri or the watch alike. And because the save
that followed usually failed too, the marker stayed inserted in the context,
where the next save that worked wrote it. ADR-0047 found it in passing.

The refusal now reads through `drinksOrThrow` (and the marker check through
`isMarkedAlcoholFreeOrThrow`), so a day that cannot be read is never marked:
`markAlcoholFreeOrThrow` throws, and `markAlcoholFree` — the call every in-app
path uses — answers `false`, which the views already read as "nothing
changed". Nothing is inserted until both reads have answered. Pinned at tier 2
in `FailedReadTests` against a store file damaged under its open container and
then restored, which is what shows the old path's marker landing on a day with
a drink. Nothing about what a bulk action writes has changed.

---

## Amendment (2026-09-16, second): the rule is kept where the write happens

The amendment above made the marker's backstop read the day or refuse. The
drinks half of bulk fill had no backstop at all, and it read from the wrong
place. The sheet's skip filter and the seed both came from the calendar's
`@Query`, and a query whose first fetch fails hands back no rows: every day in
a dragged run looked blank, every one was offered, and — under the usual-drink
seed, with no history to take a plurality from — each was queued a beer at
beer's defaults. ADR-0004's second amendment of this date found it.

Three changes, each closing a different route to the same write:

- **The calendar draws nothing to drag while its log cannot be read.** It reads
  both queries' `fetchError` and draws "Your log couldn't be read." in place of
  the grid, with no selection bar and no share button (ADR-0004's third
  amendment of this date), so the run cannot be selected from an empty query.
- **The seed is read from the store, once, when the sheet is applied**
  (`DrinkRepository.historyOrThrow`), and a failed read stops the fill. Once
  before the loop, as before, so every day still gets the same drink.
- **Each day is checked again as it is written.** `bulkFillDrinks` answers
  with no drinks for a day that has entries or a marker, through reads that
  throw — the rule this record states, "a day with any record is skipped,
  always", kept at the one point every route passes. It also closes the older
  gap the amendment above did not mention: a selection that went stale under a
  CloudKit import could write drinks onto a day that had meanwhile gained a
  record, where only the marker path refused.

A write that fails stops the fill; the days before it are written and the
rest are not, and the Diagnostics timeline says `bulk fill stopped`. The day
it stopped on may hold fewer drinks than asked — it now has a record, so a
second fill skips it, and the day sheet is the way to finish it. The drinks
are saved one at a time for exactly that: `DrinkStore.save(_ drinks:)` reports
a partial batch as success, and the first cut used it, which moved on to the
next day and left the short one unannounced (found in review). And a sheet
already open when the calendar's read fails — this one or the day sheet —
closes, since both show the record that read no longer vouches for.
Nothing about what a bulk action writes to a blank day has changed. Pinned at
tier 2 in `FailedWriteTests` (a failing history or day throws; a day with
drinks or a marker gets nothing; a blank day gets the history's drink, not
beer's defaults).
