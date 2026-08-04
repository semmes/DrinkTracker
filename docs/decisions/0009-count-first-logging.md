# 0009 — Logging is count-first; types are the granular path

**Status:** accepted — revised after the simulator design review, see below · **Date:** 2026-08 ·
**Relates to:** ADR-0003, ADR-0005, PRD invariants 1 and 2

## Context

The Today screen led with four type buttons — beer, wine, spirit, other — each
opening a sheet with size and strength. Accurate, but it front-loads a question
("what kind?") that many people answering the app's actual question ("how much am I
drinking?") don't need asked every day. The calendar's day sheet had already proven
the alternative: a count, with zero as an ordinary value on the same control.

The request was explicit: simplify daily logging to a count (including zero, for
today as well as past days), and keep the type-level control as an advanced option.

## Decision

**The counter is the primary control on Today.** A large ± stepper (0–12) and one
button. Zero, on a day with nothing logged, records the day as alcohol-free — the
same statement the calendar's day sheet makes, now available for *today* without
opening the calendar. Once entries exist, the counter floors at one and the button
reads "Add", because "add none" is not an answer.

**The typed path is a persisted disclosure, not a removed feature.** "Log by type —
size and strength" reveals the quick-add row and the repeat control. The preference
sticks (`AppSettings.prefersDetailedLogging`), so a granular user opens it once and
Today stays that shape for them. Nothing about the sheet, sizes, ABV, editing, or
history changed.

**What a counted drink *is*: the seed rule.** `DrinkDraft.quickCount` produces N
real, typed, individually editable entries (ADR-0003 unchanged) seeded from the
type the user logs most often, at the size and strength they last logged it — the
rule the calendar already used, now shared code, so "3 drinks" means the same thing
on every surface. With no history it falls back to beer's defaults, which are
exactly 1.0 US standard drinks (ADR-0005): a fresh install's count *is* a
standard-drink count until the log says otherwise.

**Evidence beats assertion, now enforced at the write.** `saveOrThrow` deletes the
day's alcohol-free marker when a drink lands on it. Previously the marker survived
dormant and would have resurrected if the drinks were later deleted — claiming
abstinence the user never re-stated. Living in the repository, every path gets it:
app, calendar, widget.

## Consequences

- The two-tap fast path holds: open → + → Log is two taps (invariant 1), and zero
  is also two. The typed path is now three-plus for someone who hasn't pinned the
  disclosure open — that is the trade, chosen deliberately.
- A counted drink inherits the user's habits, not a neutral unit. A habitual
  spirit drinker's "3" weighs more than a wine drinker's "3" — which is *more*
  accurate for each of them, and correctable per-entry since every drink is real.
- The widget is unchanged: still typed buttons. Reconsider after this settles.
- The repeat control moved inside the disclosure. Judgment call: the counter at 1
  covers its job for seed-type drinks at the same tap count.

## Revision, after the simulator review (2026-08)

The first build had **two numbers**: the standard-drinks total on top and a batch
counter below, with a "Log N / Add N more" button between them. The review said
what the screenshots make obvious side by side with drylendar's single figure: two
numbers ask the user to hold a distinction the design invented.

Now there is one. **The counter is the day's count, and ± acts on the log
directly** — plus saves a seeded drink immediately, minus deletes today's most
recent entry through the same path as a swipe-delete, undo bar included. The
binding's getter re-reads the query, so the number cannot disagree with the list
below; there is no separate counter state to drift. The confirm button is gone,
which takes the fast path from two taps to **one tap per drink**.

Standard drinks demote to a caption ("≈ 2.6 standard drinks"), shown when
non-zero. The count is the number people think in; the region-lensed figure stays
one line away for when they diverge — most visibly under the UK lens.

The zero flow is unchanged: an empty day shows "Record no alcohol today", and a
recorded day shows the removable state. Minus-to-zero deliberately does *not*
auto-mark the day — deleting your last entry says nothing about abstinence, and
the marker stays an explicit statement.

## How to reopen

If real usage shows granular users buried (the disclosure tap resented daily) or
count users confused about what a count records, the split — not the counter —
is the thing to revisit. The seed rule is domain-level and tested; it survives any
UI rearrangement.
