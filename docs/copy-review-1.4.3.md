# Copy review — App Store guideline 1.4.3

**Date:** 2026-08 · **Scope:** every user-visible string in the app, the widget, and
the Info.plist usage descriptions · **Reviewer:** Claude (Opus 5)

Guideline 1.4.3 rejects apps that encourage excessive alcohol consumption. On a
drink-tracking app the *framing* is what gets read, so this is a pass over the words
rather than the features. PRD §1 and ADR-0001 are the standard being applied.

This is a required gate before submission (PRD §7, Iteration 2). It should be re-run
whenever user-visible copy changes materially.

## Verdict

**Two findings, both fixed in the same commit as this document.** Everything else
passes.

Neither finding was a case of celebratory language — the copy has been careful about
that from the start. Both were subtler: one inaccurate claim, and one *visual*
element saying something the words were careful not to.

---

## Finding 1 — A privacy claim that wasn't accurate

**Where:** `HealthContextView`, the screen shown immediately before the HealthKit
permission prompt.

**Was:**
> Your log is stored in Health, on this device. Nothing is sold, shared, or used for ads.

**Problem:** "on this device" is not true. The SwiftData store is CloudKit-mirrored
(`SharedModelContainer.make()` passes `cloudKitDatabase: .automatic`), so the log
follows the user's iCloud account across their devices — that is a deliberate
feature, and the README describes it as such.

This is not a 1.4.3 issue; it is worse. It is an overstated privacy guarantee, on the
one screen whose entire job is informed consent, immediately before a health-data
permission dialog. A reviewer comparing the copy against the entitlements would find
the contradiction quickly.

**Now:**
> Your log stays in your own iCloud account and Apple Health. There's no account to
> create and no server to send it to — nothing is sold, shared, or used for ads.

Every clause is checkable: no account system exists (`RootView` routes onboarding
straight to Today), the CloudKit database is the user's own private one, and the app
contains no networking code.

---

## Finding 2 — A progress bar is a goal

**Where:** `TrendsView.summaryCards`, the "Days with nothing logged" card.

**Was:** the count, plus an `SUProgressBar` whose `maxValue` was the length of the
period and whose `currentValue` was the number of days with nothing logged.

**Problem:** the words were careful and the picture wasn't. A bar that fills has a
full state; a full state is a target; and a target for "days you didn't drink" is a
goal. The app's own About screen says it "doesn't set goals, keep streaks, or offer
advice", and the README claims the rest-day card "counts days without framing them as
wins" — which the bar quietly contradicted.

This is the kind of thing a copy review catches only if it looks past the copy.
Nobody wrote a goal; a component with a progress semantic was reused for a count.

**Now:** the count alone. It says everything the bar said, without implying a
direction to move in.

---

## Passed

Recorded so a future reviewer can see what was considered rather than re-deriving it.

| Area | Sample | Why it passes |
|---|---|---|
| Onboarding | "See how much you're actually drinking… No lectures, just your own picture." | States the product's purpose; explicitly disclaims advice |
| Trends | "Your average" | Named as an average, never a limit or target |
| Trends | "Days with nothing logged" | Factual. Not "sober days", not "clean days", not "streak" |
| Repeat logging | "Another beer", "How many", "3 of these", "Log 3 drinks" | Countable and flat — see ADR-0001 |
| Calendar | "Record no alcohol", "No alcohol", "Not logged" | Describes a day, never the person |
| Calendar | "Blank days are days without a record, not days without alcohol." | Corrects a reading that would flatter the user |
| Summary card | "18 days with drinks · 34 total · 2.8 on days you drank" | Components, not a composite — see ADR-0006 |
| About | "It doesn't set goals, keep streaks, or offer advice." | States the constraint to the user directly |
| Widget | "See today's total and log a drink in one tap." | Describes function, promises nothing |
| Health usage strings | "…so your data stays in one place that you control." | Accurate; matches what the entitlements actually do |

## Things deliberately absent

Checked for and confirmed missing: streaks, day counters framed as achievements,
congratulation on low numbers, warnings on high ones, comparison against other users,
any target or recommended limit, any colour that grades a day (see ADR-0007), and any
composite score (ADR-0006).

## Note on the intensity ramp

The calendar's colours were reviewed as copy, because they make a statement the same
way words do. A red-for-heavy, green-for-clear ramp is a verdict rendered in colour,
and it was rejected partly on those grounds. See ADR-0007.
