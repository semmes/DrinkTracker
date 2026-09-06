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
   *(Amended 2026-09-05 by ADR-0033, and only in its display clause. The
   persistence half stands absolutely: nothing about gaps goes into SwiftData or
   UserDefaults, and ADR-0033's figure is derived per render like every other.
   What is now permitted is displaying the longest run of days the user
   **explicitly recorded as having no alcohol**, inside a chosen window — a
   maximum over the past, built from affirmative records. The silence-based gap
   this rule was written about — a run counted from days with nothing recorded —
   stays refused, because there not logging is what grows the number. Rules 1
   and 3 are untouched.)*
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

---

## Amendment (2026-09-06, ADR-0034) — the rolling count carries the ramp

**The owner reversed one clause of this record, and it is the clause that
mattered.** Reviewing the Home v2 design, they were shown that "styled with
weight, never color, icon, or exclamation" — restated in `SessionPaceCard`'s doc
comment and in `docs/tallyist-1.2-spec.md`'s constraint 3 — refused the drawn
chip by name, and asked for the tint anyway.

So the chip is now painted with the intensity ramp. What is *not* amended is the
reasoning that made the original refusal right, and the implementation is shaped
by it:

- **The colour is not urgency styling invented for this card.** It is
  `DayIntensity.bucket` over the rolling window's own standard drinks — the same
  fold and the same palette as the calendar cell for the day the card sits
  inside. A shade here means what that shade means everywhere: an amount, on one
  scale. Nothing red, nothing pulsing, no icon, no exclamation.
- **It says nothing the figure does not.** The chip prints its count in digits
  beside the shade, and the ramp's boundaries are stated in a legend a few
  points above it.
- **It escalates from `.high` only.** Below that the chip keeps the neutral
  capsule. That is a measured limit, not a cautious one: the ramp's ink flips to
  white at `.medium`, and white on `#2a78d6` is 4.42:1 — under AA for text this
  size, where a calendar cell gets away with the same pair only because a day
  numeral is large text. `.high` and `.veryHigh` measure 11.95:1 and 17.97:1
  light, 11.75:1 and 15.87:1 dark.

Mechanics: `SessionPace.rollingStandardDrinks(in:now:region:)` shares
`rollingCount`'s window and nothing else — a count is what a person tracks
through an evening, the ramp is how much that amounts to, and the two are
deliberately different quantities (an imported Health row is the case where they
visibly coincide, since its count is unlensed).

**The three hard rules are untouched.** Nothing is persisted, no notification
exists, and a session still ends by ceasing to render. The rolling display
minimum stays 3 and the gap threshold stays 4 hours — the prototype drew 4 and
3h respectively, and both were read as prototype convenience rather than
intent, since neither was raised.

### What this costs

The honest cost is that the sentence "the number is the signal, and whether it
signals is the user's reading" is now half true: a deep fill is a second signal,
and it is the app saying *this is a lot* in a channel the reader did not opt
into. The defence is that it says exactly what the calendar already says about
the same drinking, and that a measurement tool which colours a month but not an
evening is drawing a distinction the user never asked for. Whether that holds is
a question for real use, which is what the reopen clause below is for.

### How to reopen this amendment

If anyone reports the chip reading as a warning rather than a reading — or if it
changes when they log — the cheapest revert is one line: drop `paceBand` to
always return nil and the neutral capsule comes back with no other change.
