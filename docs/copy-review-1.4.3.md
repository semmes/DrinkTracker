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

---

## Addendum (2026-08): the iCloud status row

New release-visible strings in `SettingsView.iCloudSection`, reviewed against the
same standard on addition:

| String | Note |
|---|---|
| "Syncing with iCloud" / "Not syncing — no iCloud account" | States of the system, not of the person |
| "Not saving — storage unavailable" | The one deliberately alarming line: "nothing is being saved" is the most important sentence this screen can say, and softening it would be the failure |
| Footnotes | Each says what the state means for *the user's data* and what, if anything, they can do — never blame, never urgency beyond the facts |

No 1.4.3 exposure: none of these strings reference drinking behaviour at all.

---

## Addendum (2026-08): the onboarding refresh and the calendar action bar

The prototype handoff replaced most onboarding copy and added the calendar's
selection bar. All new strings reviewed against the same standard on arrival.
(`HealthContextView` is `PrivacyView` since this change.)

| String | Note |
|---|---|
| "Your drinks, tallied" / "One tap per drink, like tick marks on a napkin, except this napkin does charts. No goals, no lectures, no judgement." | Personality without advocacy: it describes the mechanism and disclaims judgment outright. Nothing invites drinking; a tally is what the app *is* |
| "(that's five)" | A joke about counting, not about drinking |
| "Your tab is nobody's business" / "…We couldn't peek even if we wanted to." | Every clause checkable: private CloudKit database, no account, no server, no networking code. Reviewed as a privacy claim the way Finding 1 was — it survives the same test |
| "Share with a doctor if you choose. Your Apple Health data can give a provider the full picture of your drinking, daily to yearly" | The one place the app mentions a clinical use, framed as the user's choice. Factual and empowering, not diagnostic |
| "How big is a drink, anyway?" / "…Pick your region so the math pours right. Not sure? Skip it, no quiz later." | "Pours right" is wordplay about arithmetic, not an invitation. "No quiz later" honours the no-lectures promise |
| "Start tallying" / "Sounds good" / "Finish up" / "I'll decide later" | Verbs about using the app, none about drinking |
| "N days selected" / "Days that already have a record are kept" / "Mark no drinks" / "Log drinks…" | Factual in both directions, same register as the day sheet (ADR-0011). "Mark no drinks" states a fact being recorded; it carries no praise |

No new 1.4.3 exposure. The tone rules held: the personality lives in *how the
mechanism is described*, never in encouragement or judgment of the behaviour
being recorded.

---

## Addendum (2026-08): the tip jar

"Buy me a drink" inside an alcohol tracker is the riskiest phrase the app has
shipped, so every string got the full review (ADR-0012 has the design
reasoning).

| String | Note |
|---|---|
| "Buy me a drink" (Settings row, screen title) | Unambiguously about money the moment it's opened: the first body line prices it. The drink is the developer's, not the user's — no consumption is invited |
| "Tallyist is free, private, and has nothing to sell you… Tips unlock nothing — everyone gets the whole app." | The anti-paywall statement, before any price appears |
| "N × $4.99 · App Store limit is 10 per purchase" | The cap stated as a fact of the platform, not scarcity marketing |
| "Received — thank you. That keeps Tallyist free." | Gratitude without celebration; no exclamation mark (voice rule) |
| "That didn't go through. Nothing was charged." | The failure case leads with the fact the user cares about |
| "A drink every month / every year" · "cancel any time" | Cadence of a payment, not of drinking |
| "Tallyist will remind you a week before, so cancelling first is always realistic." | The pro-user promise, stated as the reason for the notification permission |
| Renewal notification: "Your recurring tip renews on <date>. Cancel any time in the App Store — the app stays the same either way." | A reminder *to cancel*, delivered before money moves — the voice's "states of the system" rule applied to billing |
| "…tips appear nowhere in your drink log." | The two ledgers never mix, said outright |

No 1.4.3 exposure found: every "drink" in this feature is priced in dollars,
and no string connects tipping to consuming.

---

## Addendum (2026-08): the day sheet's live counter

ADR-0013 rewrote every string in `DayLogSheet`; all reviewed here. Note the
Passed table above still cites "How many" and "Log 3 drinks" — those strings
left the app with the batch model this addendum replaces.

| String | Note |
|---|---|
| "Drinks" (section label) / "Drinks on this day" (VoiceOver) | A count named factually; no target implied. The label is hidden from VoiceOver so the stepper announces once |
| "Plus logs a beer, 12oz at 5% — editable afterwards. Minus removes the day's most recent drink." | Mechanism described in both directions; no invitation, no warning. The Other type reads "a drink" so the article always scans |
| "Record no alcohol" / "Recorded as no alcohol" / "Remove that record" | The zero as an explicit statement, same register as Today's "Record no alcohol today"; states a fact, carries no praise |

No new 1.4.3 exposure: every string says what the control does to the record,
never anything about the drinking.

---

## Addendum (2026-08): the export row

ADR-0015 added one section to Settings; every new string reviewed here.

| String | Note |
|---|---|
| "Export" (section title) / "Export log" (row label) | Names the action on the record, nothing about the drinking |
| "Saves your whole log as a CSV file spreadsheets can open — every drink, drinks counted from Apple Health, and the days you recorded as no alcohol. Totals are in your current unit; each drink's size and strength are included so the numbers can be rechecked." | States what the file contains and in what unit; no suggested audience, no suggested conclusion. "Recorded as no alcohol" keeps the calendar's register — a fact the user stated, not praise |
| CSV cell strings: "No alcohol recorded", "Imported drink", "Tallyist", "Apple Health", unit names ("US standard drink", "UK unit", "Australia standard drink") | The file is the record restated. No aggregate appears that a reader didn't compute themselves — the ADR-0006 boundary applies to the export by construction |

No 1.4.3 exposure: the export contains counts and physical facts, and the copy
around it describes the file, never the behaviour.

---

## Addendum (2026-08): quarter and year trend ranges

Two picker items and the strings around them; all reviewed here.

| String | Note |
|---|---|
| "Quarter" / "Year" (range picker) | Named periods, no invitation |
| "Last 13 weeks" / "Last 12 months" (chart label) | Says exactly what the bars are — calendar buckets, current one partial — rather than a rounder "90 days" the chart doesn't literally show |
| "Your weekly average" / "Your monthly average" | Same register as the existing "Your average": possessive and factual, never a target. The line averages completed periods only, so a fresh week can't read as a drop |
| "last 13 weeks" / "last 12 months" (stat label) | Value + noun, matching "this week" / "this month" |

No 1.4.3 exposure: longer ranges add no comparison, delta, or judgment — the
same three counts over more days. The year view was checked against ADR-0006's
boundary: no year-over-year framing exists anywhere in it.

---

## Addendum (2026-08): import adoption

ADR-0016's flow; every new string reviewed here.

| String | Note |
|---|---|
| "Add details" (leading swipe on an adoptable import) | Names what the action collects, parallel to "Edit" on logged rows. No suggestion the import is wrong or lesser |
| "From Apple Health, <date> at <time>" (sheet subtitle) | Provenance and the one fact the import carries, stated once where the user is about to add the rest |
| "Save details" (primary action) | A verb phrase about the record, same register as "Save changes"; not "Claim" or "Upgrade", which would editorialise |

No 1.4.3 exposure: adoption collects size and strength for a drink already
recorded; nothing invites drinking, and the count-to-facts change is shown as
arithmetic, never celebrated.

---

## Addendum (2026-08): appearance setting

1.2 Feature A; four strings.

| String | Note |
|---|---|
| "Appearance" (section) / "System" / "Light" / "Dark" | Platform-standard display vocabulary, no invitation |
| "The widget follows the device's appearance either way." | States the one boundary of the setting as a fact, so nobody hunts for a widget option that deliberately doesn't exist |

No 1.4.3 exposure: a display preference with no relationship to drinking.

---

## Addendum (2026-08): session pace

1.2 Feature B (ADR-0017); the spec's own copy rule — report, never
instruct — restated as this review's bar.

| String | Note |
|---|---|
| "3 drinks this session" / "1 drink this session" | A count and a noun. "Session" names the sitting without praising or warning about it |
| "Started 8:56 AM" | A timestamp |
| "Last drink just now" / "Last drink 47 min. ago" | Elapsed time as context, shown only during an active session — outside one it would be a streak (ADR-0017 rule 1) |
| "3 in the last 2 hours" | The pace fact, weight-styled only: no color, no icon, no exclamation. States a window and a count; sets no threshold and passes no judgment |
| "Session pace" / "Show session pace" (Settings) | Named factually; off by default |
| "Shows how many drinks you've logged in the current sitting." | A description, not an invitation — the footnote is the entire pitch |

No 1.4.3 exposure: every string is a measurement of the record. The card
never congratulates a slow pace or warns about a fast one, in either copy
or styling.

---

## Addendum (2026-08): population reference

1.2 Feature C (ADR-0018). The spec's copy rules applied verbatim.

| String | Note |
|---|---|
| "Your average is about 4.1 standard drinks a week." | The user's own number, "about" carrying the estimate honestly |
| "That's lower than roughly 30% of US adults who drink." / "That's more than roughly 95%…" | "Lower than" / "more than", never "better than" or "worse than"; no praise or alarm in either direction. "Roughly" absorbs the source's rounding |
| "No drinks in the last 4 weeks." | The zero case as a fact, with no comparison attached — there is nothing honest to compare |
| "Source: Alcohol Research Group, 2020 National Alcohol Survey" | Always visible, never buried (spec acceptance criterion) |
| Expanded note ("A published population statistic, not data from other Tallyist users — nothing about your log leaves this device. …recalculated to cover only the 72% who reported drinking… Your average covers your last 4 weeks.") | Says what it is, what it is not, how it was derived, and the privacy fact, in that order |

No 1.4.3 exposure: a descriptive comparison with no threshold, no guideline,
and no direction the number "should" move. Checked against constraint 5's
line — the card states where the user sits, never where to sit.

---

## Addendum (2026-08): the month share card

1.2 Feature D; the card's contents and its one entrance.

| String | Note |
|---|---|
| "August 2026" / "15.4 standard drinks" / "3.5 standard drinks a week" | The month restated: name, total, average. No comparison to anyone, no trend arrow, no caption editorializing the numbers |
| Legend ("No alcohol · 1–2 · 3–5 · 6+") | Same factual buckets as the in-app calendar |
| "Tallyist" (wordmark) | Text alone — the mark never locks up with text (design-system.md) |
| "Share this month as an image" (toolbar accessibility label) | Names the action; the button is the feature's only entrance — no prompts, no nudges |

No 1.4.3 exposure: the image is the user's own record, exported at their own
initiative, containing nothing evaluative and nothing about anyone else.

---

## Addendum (2026-08): 1.2 release copy

The What's New (1.2) block, the reviewer notes, the description's two changed
lines, and the privacy policy's new bullet; all reviewed here.

| String | Note |
|---|---|
| What's New (1.2), whole block | Feature statements only: what exists, where the switch is, what stays on-device. "Off by default" said plainly twice; no invitation to use any of it, no exclamation marks |
| "…a published population reference: your weekly average beside a 2020 national survey…" | Names the mechanism and the boundary ("computed on your device… nothing about your log leaves your phone") without promising insight |
| "Export your whole log as a CSV any time; it's your record" (description) | The ownership fact carries the pitch; no "share with your doctor" framing that would imply a health workflow |
| "Weekly, monthly, quarterly, and yearly totals with your own average — never a target" | Existing bullet extended; the "never a target" clause kept |
| Privacy policy, "Export and sharing" bullet (both copies) | States creation-on-request, destination-by-user, no copy, no identifier, no record of sharing — each claim checkable against the code |

No 1.4.3 exposure found. Reviewer notes are addressed to App Review, not
users, but were held to the same register anyway.

---

## Addendum (2026-08): Siri and Shortcuts

ADR-0019. Everything here is **spoken as well as read**, so the voice register
was reviewed too: a phrase that scans as neutral text can still land as
encouragement when Siri says it aloud.

| String | Note |
|---|---|
| "Log a beer in Tallyist" / "Add a beer in Tallyist" (phrases) | Imperative the *user* speaks, not the app — the app never initiates. Names the action on the record |
| "Log drinks in Tallyist" / "Record no alcohol in Tallyist" | Same register as the in-app controls they mirror |
| "Which drink?" / "How many?" (request dialogs) | Questions about the record, asked only because the user started the exchange. No suggestion, no default nudged aloud |
| "Logged: Beer, 12oz, 5% ABV." / "Logged 2: Wine, 5oz, 12% ABV each." | A statement of what was written, built on `summaryLine` so voice and screen render a drink identically. Deliberately not "Got it" or "Nice" — confirmation, never approval |
| "Recorded today as no alcohol." | The fact, matching Today's "Record no alcohol today" — and now only spoken when the write actually persisted (ADR-0019) |
| "Nothing was logged." | The honest answer to a request for zero drinks. It was written as an unreachable branch and the review made it reachable: the alternative was inventing a drink and announcing it |
| "Today already has drinks logged, so it wasn't recorded as no alcohol." | The refusal as a **state of the record**, not an error and not a correction of the person. Evidence beats assertion, said out loud |
| Intent titles/descriptions ("Log a Drink", "Logs a drink using its default size and strength.") | Shortcuts-facing chrome; factual |

No 1.4.3 exposure: nothing spoken invites a drink, praises one, or comments on
quantity. Checked against the 1.2 spec's App Review table — no notifications
exist on any of these paths, and Siri never speaks unprompted.
