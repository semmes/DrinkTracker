# 0013 — The day sheet's counter is the day's log

**Status:** accepted · **Date:** 2026-08 · **Relates to:** ADR-0009 (count-first
logging), ADR-0003 (separate entries), ADR-0011 (bulk fill untouched)

## Context

ADR-0009's revision made Today's counter *the* log: ± acts on the data directly,
no confirm step, undo bar on minus. The calendar's day sheet still ran the older
batch model — a counter meaning "how many to add", floored at one on a day with
entries, applied by an "Add N more" button. The asymmetry had a user-visible
consequence, reported as a feature request before the App Review resubmission: a
drink logged in error on a past day could not be subtracted where it was seen.
Removal meant finding the row and swiping, a different gesture than the one that
created the mistake.

The request was explicit: plus and minus should work the same on every day,
current or past.

## Decision

**The day sheet's counter shows the day's actual count, and ± acts on the log
directly** — the same contract as Today, one surface later:

- **Plus** logs one seeded drink dated that day the moment it is tapped. Seeding
  is unchanged: `DrinkDraft.quickCount`, the shared rule. The timestamp is
  `TrendSummary.backfillTimestamp` — `now` when the day is today (Today's own
  contract, and a noon stamp on today could sit in the future, which HealthKit
  rejects); otherwise noon or one second after the day's latest entry, whichever
  is later, clamped to the day. Landing *after* the day's existing entries is
  load-bearing: it makes the just-added drink the day's most recent, so a plus
  followed by a minus removes the drink the plus created — never a real evening
  entry — and repeated taps get strictly increasing stamps (ADR-0003's
  determinism, preserved one tap at a time). The counter keeps one tap of
  headroom past the count (`max(12, count + 1)`), so twelve is a soft floor
  rather than a cap that strands the thirteenth drink.
- **Minus** removes the day's most recent entry through the same path as a
  swipe-delete: HealthKit sample retired, undo bar shown. The pick is
  `TrendSummary.mostRecentDrink(on:in:calendar:)` — domain code, tested — and
  matches the top row of the sheet's own newest-first list, so the tap removes
  what the user sees.
- **The "Log N / Add N more" button is gone.** With a live counter there is no
  batch to confirm. "Done" closes the sheet; nothing else needs saying.
- **Zero stays an explicit statement.** An empty day shows "Record no alcohol"
  below the counter; minus-to-zero does not auto-mark, the same deliberate rule
  as Today (ADR-0009). Recording or clearing the marker no longer dismisses the
  sheet — the sheet reflects the state it changed.
- **Undo outlives the sheet.** The `DeletionCoordinator` is owned by the
  calendar and passed in, so the bar renders inside the sheet while it is up
  (gated to the sheet's own day, so another day's removal never reads as a
  failed undo here) and on the calendar after it closes. The window ends early
  if the user pops back to Today — the coordinator is calendar-scoped, and
  Today's own coordinator knows nothing of it; a cross-surface undo is a
  deliberate non-goal for now.
- **± operations are serialized.** Each counter mutation queues behind the
  previous one and resolves its target from the repository at execution time,
  not from the tap-time query snapshot. Store writes await HealthKit round
  trips before committing, so tap-time resolution would let two quick minus
  taps pick the same victim (one removal for two taps) or let a minus race a
  pending plus onto the wrong drink. Serialized, two minus taps remove two
  drinks, and a minus behind a plus removes the drink that plus created.

## Consequences

- One counter contract everywhere a count is said. The user-facing asymmetry —
  add-anywhere, subtract-only-today — is gone.
- `DayLogSheet` lost its only local state; the count is always the query's
  truth, so the sheet cannot drift from the list it sits over.
- The bulk-fill path is untouched: it still writes only to blank days
  (ADR-0011), and its sheet keeps the batch counter, where a batch is the point.
- History's swipe actions are unchanged — this adds a path, it doesn't move one.
- The queued-ops pattern has since been carried back to `TodayView`, the
  follow-up this note originally recorded as queued: Today's ± now serializes
  through the same chained task, minus resolves its victim from the repository
  inside the op rather than from the tap-time query snapshot, and Today's
  stepper keeps the same one-tap headroom (`max(12, count + 1)`) instead of
  capping at the count — which had disabled plus for good once a day reached
  twelve entries.

## How to reopen

If backfill turns out to need the batch confirm (someone reconstructing a heavy
week may want to state "8" once rather than tap eight times), the counter can
regain a staged mode without touching the domain — `quickCount` still accepts
any count. The evidence to watch is calendar sessions with many consecutive
plus taps on one day.
