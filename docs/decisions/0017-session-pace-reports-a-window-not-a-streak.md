# 0017 — Session pace reports a rolling window, never a streak

**Status:** accepted · **Date:** 2026-08-27 · **Source:** `docs/tallyist-1.2-spec.md`
Feature B · **Relates to:** ADR-0006, PRD invariants 8 and 9

## Context

The 1.2 spec replaced an earlier "stopwatch since last drink" idea with a
session pace card, for a reason worth keeping in the decision log: the
variable that tracks intoxication risk is **pace** — drinks inside a rolling
window — not elapsed time since one drink. The two come apart exactly when it
matters: someone six drinks deep at ten-minute intervals sees a since-last
stopwatch that keeps resetting to near zero, reading calmest precisely when
the pace is fastest. So the rolling count is the primary number and elapsed
time is context.

The competing shape — an ever-visible "time since last drink" — is a streak,
and this app's whole stance (ADR-0006: a summary, not a score) is that a
number the user protects is a number that stops the logging.

## Decision

**A card on Today, off by default, visible only during an active session**
(a drink within the 4-hour gap threshold), showing three flat facts — drinks
this session, when it started, time since the last — plus a fourth line, the
rolling two-hour count, shown only at 3 or more and styled with weight, never
color, icon, or exclamation.

**Three hard rules, settled here as law** (the spec's own words, restated):

1. **No time-without-a-drink runs outside an active session.** An increasing
   "time since last drink" is a streak, and a streak that resets to zero
   punishes the user at the exact moment they are least able to handle it.
2. **Nothing about gaps is ever persisted or displayed as a record.** No
   longest-gap, nothing in SwiftData or UserDefaults. A session ending is
   the absence of a value, not an event.
3. **No notifications.** None, not behind a toggle.

Mechanics: `SessionPace` in `DrinkTrackerCore` — pure, calendar-free
(absolute timestamps only, so midnight/DST/time zones can't split a run),
clock always injected. A Health import contributes its count; typed entries
count 1 each (invariant 7's model). Future timestamps clamp to now so a
backwards clock jump can't render a negative elapsed. The card recomputes on
a 60-second `TimelineView` — no repeating `Timer`.

## Consequences

- The card can name a fast pace ("5 in the last 2 hours") without ever
  saying it is fast — the number is the signal, and whether it signals is
  the user's reading. That is the same boundary the intensity ramp holds
  (ADR-0007): data, never verdict.
- Off by default costs discoverability, deliberately. A behavioural surface
  that self-promotes is halfway to a coach (spec constraint 3).
- The gap threshold ships fixed at 4 hours. The spec allowed an optional
  3/4/6 setting; not built — one more knob is one more thing to tune toward
  a goal. Adding it later is additive and needs no migration.

## How to reopen

- The 3/4/6-hour threshold setting: add it if real users report sittings the
  4-hour default splits or merges wrongly — as a quiet setting, never a
  prompt.
- Any pressure toward notifications, persistence of gaps, or urgency styling
  reopens nothing: those are the three hard rules, and the spec's own stop
  conditions say a build heading there stops.
