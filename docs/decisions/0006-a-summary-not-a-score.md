# 0006 — The 30-day view is a summary, not a score

**Status:** accepted · **Date:** 2026-08 · **Relates to:** ADR-0001, PRD §1 and §2

## Context

A competitor (drylendar) shows a **SobriScore**: a single figure "computed from your
last 30 days of tracking", updating daily "to reflect your progress", rendered as a
smiley face that fills as the number rises. We were asked to build something similar.

The underlying want is reasonable and worth serving: *how have the last few weeks
gone, at a glance.* The objection is to the composite number, not to the question.

Three problems with the score, in increasing order of seriousness.

**It is a verdict.** A score has a direction — higher is better. That tells the user
what to think about their own month, which is the thing PRD §1 rules out. The app
reports and stops.

**It is a target.** A number that moves daily is a number to move deliberately. ADR-0001
already settled that this app carries no streaks and nothing framing volume as
achievement; a score is a streak with a decimal point, and the smiley face is the
reward loop made literal.

**It creates a reason to under-log.** This is the one that decides it. The cheapest
way to protect a score is to stop recording the days that would lower it. The app's
entire claim is *an accurate answer to how much am I actually drinking*, and
under-logging is the specific failure mode every other decision here — the two-tap
path, the one-tap widget, repeat logging — exists to prevent. A feature that pays
the user to log less is working against the product, not just against its tone.

The screenshot shows the score alongside friends and sharing features, which
compounds all three. Those were not requested and are not built.

## Decision

`RecentSummary` and `RecentSummaryCard`: the same 30-day window, reported as
**four independent figures** plus an explicit unlogged count.

- days with drinks
- days recorded as having no alcohol
- total standard drinks
- average across days you drank

No composite. No delta against last month. No arrow, no grade, no colour that
ranks them.

Two details carry most of the honesty:

**The average covers drinking days only.** Averaging across the whole window lets a
stretch of unlogged days drag the figure down, so it would fall when you stopped
recording — rewarding exactly the behaviour above.

**Unlogged days are named.** Without that line the two day-counts look like they
should sum to 30, and a reader would assume the remainder was alcohol-free. The
same reasoning gives the year view its "X of 365 days have something recorded"
footnote, and it is why `DayIntensity` has five cases rather than four.

## Consequences

- No at-a-glance single number. That is the cost, and it is real — a score is more
  glanceable than four figures. Four figures are checkable against the log, which a
  score is not.
- Every figure stays true under any amount of missing data, because the missing data
  is stated rather than absorbed.
- Any future "how am I doing" feature inherits this: report the components, don't
  combine them into a judgment.

## How to reopen

If there is ever a reason to ship a composite figure, it needs an answer to the
under-logging incentive that doesn't rely on the user being disciplined — the
feature has to be safe for someone having a bad month, because that is precisely
who is most likely to stop logging. Nothing in the current design has one.
