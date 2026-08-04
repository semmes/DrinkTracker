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
