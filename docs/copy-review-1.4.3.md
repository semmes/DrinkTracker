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

---

## Addendum (2026-08-28): localization steps 2–3

No copy changed. This is recorded because the change *touched* almost every
user-visible string in the app, and "we didn't reword anything" is the claim
that most needs evidence.

Roughly thirty display helpers moved from `String` to `LocalizedStringKey`, so
their literals reach the string catalog instead of passing through `Text`'s
verbatim initializer. A mechanical comparison of every string literal in the
thirteen changed files, before and after, found no word, punctuation mark, or
capital letter altered. Four sentences were *restructured* without changing
what they render:

| Site | Restructure | Rendered result |
|---|---|---|
| `RecentSummaryCard` | `"\(n) \(n == 1 ? "day has" : "days have") nothing logged either way."` split into two whole sentences | identical — and now a translator gets sentences rather than a verb fragment |
| `IntensityCell` | the amount phrase hoisted into each branch | identical |
| `DayLogSheet` | two `Text` values interpolated instead of concatenated | identical; drops a fragment key that began with a space |
| `YearView` | `"\(name): " + parts.joined(…)` folded into one interpolation | identical |

One rendering bug was found and fixed before it shipped: as a `String`,
`"Nothing recorded in \(year)"` interpolated the year plainly; as a key it
became `%lld` and resolved through `String(format:locale:)`, which groups
digits — the caption would have read "2,026" beneath a title reading "2026".
The year now goes in as text.

The tip-jar title "Buy me a drink" is flagged for the eventual translator, not
changed: it is an English idiom that puns on the app's subject, and a literal
translation could read as asking for alcohol rather than a tip. It wants a
translator note in the catalog when languages are chosen.

---

## Addendum (2026-08-28): localization defects, and a plural that was wrong

Copy changed here, which is why this entry is longer than the last one. Every
change is a grammatical agreement fix — no sentence was reworded, no word added
or removed, and nothing gained a tone it did not have.

**The pattern.** Several labels chose between "drink" and "drinks" by testing the
*unrounded* value while displaying a *rounded* one. `StandardDrink.formatted`
rounds to one decimal, so a day of 1.02 standard drinks displays "1" and then read
"1 standard drinks". This is not an edge case: the fast-path default logs exactly
one US standard drink, so the most common day there is was the ungrammatical one.
The noun now agrees with the digits actually on screen.

| Surface | Was | Now |
|---|---|---|
| Today's precise figure | "≈ 1 standard drinks" | "≈ 1 standard drink" |
| Day sheet's precise figure | "≈ 1 standard drinks" | "≈ 1 standard drink" |
| Widget caption | "≈ 1 standard drinks" | "≈ 1 standard drink" |
| Session pace | "1 drinks this session" | "1 drink this session" |
| Weekly average (population card) | "about 1 standard drinks a week" | "about 1 standard drink a week" |
| Drink sheet, VoiceOver | "Approximately 1 standard drinks" | "Approximately 1 standard drink" |
| Drink sheet, VoiceOver, UK | "Approximately 1 units" | "Approximately 1 unit" |

The UK row was wrong at *every* count, not just at one: that label appended a
literal "s" to the singular noun, so it always said "units" — including when the
count was one.

**One wording change, in a VoiceOver label only.** The calendar cell spoke a
hardcoded "standard drinks" regardless of region, so a UK user heard "standard
drinks" while the screen beside it said "units". The cell now names the region's
own unit. Nothing sighted users read changed; this is the spoken label agreeing
with the visible one.

**Reviewed against 1.4.3.** Nothing here celebrates, judges, or congratulates. No
exclamation marks were introduced. The words are the same words — "1 standard
drink" is the same register as "1 standard drinks", only correct. No new claim is
made about the user's drinking, and no number changed: only the noun agreeing
with it.

---

## Addendum (2026-08-28): the last-30-days card

**One agreement fix.** The card's totals caption was built as
`"\(region.unitNamePlural) total"` — always plural — so a total of exactly one
standard drink read "1 standard drinks total". It now agrees with its number, the
way the two day-count captions beside it always have. Observed on screen at a
total of 1: "1 / standard drink total".

| Surface | Was | Now |
|---|---|---|
| Last 30 days, totals caption | "1 standard drinks total" | "1 standard drink total" |
| Same, UK units | "1 units total" | "1 unit total" |

No wording changed. The caption is the same phrase with the noun in the form the
number calls for.

**One spoken change, no visible one.** VoiceOver reads each figure as a single
phrase, and it used to assemble that phrase from the two views — number, pause,
caption. The two whole-number figures now supply the sentence directly, so the
pause between the number and its caption goes away: "1 day with drinks" rather
than "1, day with drinks". The words are identical. The two fractional figures are
untouched and still read as before.

**Reviewed against 1.4.3.** No word was added or removed anywhere here, nothing
celebrates or grades, and no exclamation marks were introduced. A caption naming
what a number counts is as factual after the change as before it.

---

## Addendum (2026-08-28): the privacy policy stays in English

**One word of copy changed: a date.** "Last updated August 27, 2026." became
"Last updated August 28, 2026." in both copies, per the rule that the two move
together.

The substantive change is to the hosted copy only, and it makes a sentence true
rather than changing what the policy claims. It used to read "The same text ships
inside the app." It now names the hosted page the authoritative version and says
the in-app copy stays English even where the interface is translated, and why —
so that what it claims can be checked against the privacy manifest and
entitlements.

That is a factual statement about how the document is maintained, in the same
register as the rest of it: no reassurance, no promise beyond what can be
verified. See [ADR-0021](decisions/0021-the-privacy-policy-stays-in-english.md).

**Nothing was added telling the reader the policy is in English.** There is no
second language yet, so the line would currently describe nothing. It belongs with
the first translation, and the ADR says so.

---

## Addendum (2026-08-29): the count-first seed refuses an empty template

**No in-app copy changed.** The fix is behavioural (ADR-0022). Today's rows and
its repeat control gained an imported-entry branch, but every string in it —
"Add details", "Edit", "Remove" — already existed on the History screen and is
already in the catalog; the change is which rows they attach to. No key was
added, removed, or reworded.

**One listing paragraph added,** to What's New (1.2):

| Line | Reads |
|---|---|
| What's New (1.2), new final paragraph | "Fixed: with drinks imported from Apple Health in the log, one-tap logging could copy one of them — an entry that records a count and a time, but no size or strength — and add it as an empty drink." |

**Reviewed against 1.4.3.** It states what went wrong and what it produced, in
the same register as the feature statements above it: no apology, no
reassurance, no claim about how rare it was or how much better things now are.
"Fixed:" labels the paragraph rather than congratulating anyone, and the
description of an import — a count and a time, no size or strength — is the
same factual line ADR-0014 and the reviewer notes already use. No exclamation
marks.

**Nothing here grades the user's drinking,** which is the axis 1.4.3 actually
polices for this app. The paragraph is about the app's own bookkeeping.

---

## Addendum (2026-08-29): logging a standard drink with no type

New user-visible copy for ADR-0023. The feature exists because a user said the
type question was the friction, so the copy's whole job is to describe two
recording behaviours without recommending either.

| Where | Reads |
|---|---|
| Settings section title | "What the counter logs" |
| Picker options | "Standard drink" / "My usual drink" |
| Footnote, standard-drink setting | "One tap records one standard drink, with no type. You can add the type, size, and strength later by tapping the entry, or skip it — the drink counts either way." |
| Footnote, usual-drink setting | "One tap records the type you log most, at the size and strength you last logged it. Tap the entry to change any of it." |
| Drink type name | "Standard drink" |
| Summary line (row, Siri reply, "last logged") | "One standard drink" |
| Row detail | "8:15 PM · no size or strength recorded" |
| Sheet button, adding a type to an untyped drink | "Save details" |
| Shortcuts intent description | "Logs one drink, the same way the app's counter does." |

**Reviewed against 1.4.3.** Nothing here sets a target, grades a drink, or
implies one setting is the responsible choice. The two footnotes are the risk
and were written against it: both describe what gets recorded and stop. The
standard-drink footnote could easily have read "for when you don't want to
fuss with details" — an editorial about the user — and instead states the
mechanism and the fact that skipping costs nothing, which is the reassurance
the user actually asked for and is verifiable rather than soothing.

**"or skip it — the drink counts either way"** is the one clause doing
persuasive work, and it earns its place: the report's worry was that a drink
logged without details might not be tracked properly. That sentence answers a
factual question about the app's behaviour. It is not encouragement.

**"no size or strength recorded"** describes an absence without calling it
incomplete. "Missing size" or "details needed" would turn a row the user chose
into a chore the app is nagging about — a small version of exactly the goal
framing this app refuses.

**Neither option is named as the default in the interface.** The picker shows
two options with no badge, no "recommended", and no ordering claim beyond
reading order.

**No exclamation marks.** No celebration on adding details, and adding them
produces no confirmation beyond the row changing.
