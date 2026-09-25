# App Store listing — paste-ready metadata

**Status:** 1.0 (2026-08-25), 1.1 (2026-09-01), 1.2 (2026-09-05) and 1.3
(2026-09-20) live — the dates are the store's own (its version history, and
for 1.0 the app's release date), read on 2026-09-23, when the owner reported
1.3's approval; 1.4 in preparation, carrying the Apple Watch app and Apple
Health on Trends together (ADR-0054), with its description, What's New and
reviewer notes below ·
**Owner:** Shawn · App Store Connect → App Information / the version page.
Everything here has been through the same 1.4.3 tone review as the app's own
copy: factual, no celebration, no verdicts — except 1.3's as-shipped What's
New, which is recorded as a fact, not offered for pasting.

**Where the live listing differs from this file** (read 2026-09-23; the owner
edited App Store Connect directly): the subtitle reads **"Alcoholic Drink
Tracker"**, not the one in the table below, and the What's New that shipped for
1.1 and for 1.3 is the owner's own shorter text rather than the draft here —
1.3's is recorded under its heading. 1.2's went out as drafted, its dashes
turned to commas and colons. The Privacy Policy and Support URLs on the listing
are still the `semmes.github.io/Tallyist/` ones, which redirect to `tallyist.co`
since 2026-09-24; the table below gives the addresses to set with 1.4
(ADR-0024, amended 2026-09-24).

**The description differs too** (read 2026-09-23 through the iTunes lookup API,
which the read above did not check). The live one is 581 characters, the owner's
own, and not the text under "Description" below. Three things in it disagree with
the record: it says "Log a drink in two taps", where the app and this file say one;
it says "Everything lives in Apple Health on your device", where the privacy policy
says the log lives in the app's own database and Health is optional; and it has no
subscription paragraph, which the note under "Description" says must stay while
recurring tips exist (guideline 3.1.2(a): each recurring tip's title, period and
price, and the Terms of Use and privacy links).

## App Information

| Field | Value |
|---|---|
| Name | **Tallyist** |
| Subtitle (30 chars max) | `Your drinks, tallied.` |
| Primary category | Health & Fitness |
| Privacy Policy URL | `https://tallyist.co/privacy/` (from 1.4) |
| Support URL (version page) | `https://tallyist.co/support/` (from 1.4) |
| Marketing URL (version page) | `https://tallyist.co/` (from 1.4, optional) |
| License Agreement | Apple's standard EULA (leave the custom EULA field empty) |

## Description

```
Tallyist keeps an honest count of what you drink, so you can see your own
pattern. One tap per drink, like tick marks on a napkin — except this napkin
does charts.

No goals, no streaks, no lectures, no judgement. Tallyist reports; it never
grades.

— Log a drink in one tap, from the app or the home-screen widget
— A counter you can turn up or down, not a form to fill in
— Calendar of your days, shaded by amount — including days with none, which
  count as a fact of their own
— Press and drag across the calendar to fill a stretch of days at once
— Weekly, monthly, quarterly, and yearly totals with your own average — never
  a target
— Export your whole log as a CSV any time; it's your record
— Log by voice with Siri, or from Shortcuts and the Action button
— Standard-drink math for the US, UK, and Australia, switchable any time
— Saves to Apple Health if you allow it, so a doctor can see the full picture
  if you choose to share it

Private by design: no account, no server, no ads, no analytics. Your log lives
on your device, syncs through your own private iCloud, and the developer
cannot read any of it.

Tallyist is free, and everything in it is free. If it earns a place on your
home screen, there's an optional tip jar ("Buy me a drink") — a one-time
$4.99 tip, or recurring support at A Drink Every Month ($4.99/month,
auto-renews monthly) or A Drink Every Year ($4.99/year, auto-renews yearly).
Tips unlock nothing. Recurring tips renew automatically until cancelled in
your App Store account settings, at least 24 hours before the period ends;
Tallyist itself reminds you a week before each renewal so you can cancel
first if you want.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://semmes.github.io/Tallyist/privacy/
```

Notes on the description, so edits keep it compliant:
- **Guideline 3.1.2(a)** is why the tip paragraph names each subscription's
  title, duration, and price per period, and why both links appear verbatim.
  Keep all of that if you rewrite the rest. If ASC prices ever change, change
  them here in the same breath.
- **Guideline 1.4.3** is why there are no health claims, no "drink less"
  framing, and no promises — the description only says what the app does.

### Description for 1.4

**Paste one of these before 1.4 is submitted.** The live description (the
owner's own, read 2026-09-23 and described in the status block above) has no
subscription paragraph, which guideline 3.1.2(a) requires while recurring tips
exist, and it says nothing about the two things 1.4 adds. Guideline 2.5.1 asks
that an app's HealthKit use be indicated in its description, and 1.4 is the
first version that reads anything from Health beyond alcohol. Either text below
fixes both. They differ only in voice.

**(A) The reviewed description, updated for 1.4.** One bullet changed (the
first) and one added:

```
Tallyist keeps an honest count of what you drink, so you can see your own
pattern. One tap per drink, like tick marks on a napkin — except this napkin
does charts.

No goals, no streaks, no lectures, no judgement. Tallyist reports; it never
grades.

— Log a drink in one tap, from the app, the home-screen widget, or your
  Apple Watch
— A counter you can turn up or down, not a form to fill in
— Calendar of your days, shaded by amount — including days with none, which
  count as a fact of their own
— Press and drag across the calendar to fill a stretch of days at once
— Weekly, monthly, quarterly, and yearly totals with your own average — never
  a target
— Export your whole log as a CSV any time; it's your record
— Log by voice with Siri, or from Shortcuts and the Action button
— Standard-drink math for the US, UK, and Australia, switchable any time
— Saves to Apple Health if you allow it, so a doctor can see the full picture
  if you choose to share it
— If you turn it on, Trends can show your resting heart rate, sleep, heart
  rate variability, and wrist temperature from Apple Health beside your log,
  as your own averages on nights you logged drinks and on nights you recorded
  as no alcohol. They are read on your device and never stored

Private by design: no account, no server, no ads, no analytics. Your log lives
on your device, syncs through your own private iCloud, and the developer
cannot read any of it.

Tallyist is free, and everything in it is free. If it earns a place on your
home screen, there's an optional tip jar ("Buy me a drink") — a one-time
$4.99 tip, or recurring support at A Drink Every Month ($4.99/month,
auto-renews monthly) or A Drink Every Year ($4.99/year, auto-renews yearly).
Tips unlock nothing. Recurring tips renew automatically until cancelled in
your App Store account settings, at least 24 hours before the period ends;
Tallyist itself reminds you a week before each renewal so you can cancel
first if you want.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://tallyist.co/privacy/
```

**(B) The owner's live description, corrected.** The owner's own words, with
four changes: "two taps" is "one tap", which is what the app does; the Apple
Watch and the Health figures on Trends are named, with the size choice
said to be the iPhone's, since the watch logs a type at its default size; "Everything lives in Apple
Health on your device" is replaced, because the log lives in the app's own
storage and Health is optional; and the subscription paragraph and the two
links are restored.

```
How much do you actually drink in a week? Most people can't say, the count slips away between Tuesday and Saturday.
Tallyist gives you an honest picture, without the lecture. Log a drink in one tap, on your iPhone or your Apple Watch. Beer, wine, spirits, or anything else. On iPhone, pick a size, and Tallyist does the math for you. Adjust the details after if you want to, nothing blocks you from logging fast.

See your day, your week, your month. Just the numbers, no streaks, no scores, no judgment either direction. If you turn it on, Trends can also show your resting heart rate, sleep, heart rate variability and wrist temperature from Apple Health beside your log, as your own averages. They are read on your device and never stored.
Your log lives on your device and syncs through your own private iCloud. Saving to Apple Health is optional. No account to create, no signup, nothing sold or shared.

Tallyist is free, and everything in it is free. There's an optional tip jar: a one-time $4.99 tip, or recurring support at A Drink Every Month ($4.99/month, auto-renews monthly) or A Drink Every Year ($4.99/year, auto-renews yearly). Tips unlock nothing. Recurring tips renew automatically until cancelled in your App Store account settings, at least 24 hours before the period ends, and Tallyist reminds you a week before each renewal.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://tallyist.co/privacy/
```

Both went through the 1.4.3 review with 1.4's other copy
(`docs/copy-review-1.4.3.md`, "1.4 release"). The prices are ASC's as recorded
here; check them against ASC before pasting.

## Keywords (100 chars max)

```
drink,tracker,alcohol,tally,counter,log,standard drinks,units,sober,health,habit,diary
```

## Promotional text (170 chars, changeable without review)

```
An honest tally of what you drink. One tap to log, a calendar of your days,
no judgement anywhere. Free, private, no account.
```

## What's New (first version)

```
First release: one-tap logging, the home-screen widget, calendar with
drag-to-fill, trends, Apple Health, and iCloud sync.
```

## What's New (1.1)

```
Your history from other apps, automatically: drinks recorded in Apple
Health by any app now appear in Tallyist — counter, calendar, and
trends — clearly labeled and counted as logged. Grant Health access
and your past shows up on the next launch.

Also: the calendar day sheet's counter now works exactly like Today's —
plus logs, minus removes, undo included.
```

## What's New (1.2)

```
One tap now records one standard drink, with no type — add the type,
size, and strength afterwards, or skip them; it counts either way. Once
you describe a drink, the next taps record another of it for the rest
of the day, and "Record a standard drink instead" is the way back; each
day starts back at a standard drink. If you'd rather one tap always
repeated the drink you log most, that's in Settings: What the counter
logs.

Appearance: choose Light, Dark, or System in Settings.

Trends now reach further — Quarter and Year views — and can show a
published population reference: your weekly average beside a 2020
national survey of US adults who drink, computed on your device from a
bundled statistic. Nothing about your log leaves your phone. Tap a bar
— or drag across the bars — to see what it holds: the day, week, or
month, its total, what was logged by type, and for a week or month, days
with drinks, days recorded as no alcohol, and days with nothing logged.

Session pace, off by default: while you're logging, Today can show how
many drinks this sitting, when it started, and how long since the last.
Turn it on in Settings.

Export your whole log as a CSV from Settings, and share any month or
year as an image from the calendar — the grid and the same four figures
the calendar shows: days with drinks, days with none, the total, and the
average on days with drinks. The calendar's summary can cover the last 30
days or the month shown, and the year view carries the same four figures
for the year.

Siri and Shortcuts: "Log a beer in Tallyist", "Log drinks in Tallyist"
(Siri asks which and how many), or "Record no alcohol in Tallyist" —
logging without touching the screen.

Also: a drink imported from Apple Health can take details — tap it and
add the type, size, and strength. And a day another app recorded in
Apple Health as zero drinks now appears as a no-alcohol day, labeled
"From Apple Health".

Fixed: with drinks imported from Apple Health in the log, one-tap logging
could copy one of them — an entry that records a count and a time, but no
size or strength — and add it as an empty drink.
```

## Reviewer notes (1.2) — paste into App Review notes

These restate the claims made in the 1.0 Resolution Center response, which
every 1.2 feature was shaped to keep true (see docs/tallyist-1.2-spec.md,
"App Review consistency").

```
Notes on what's new in 1.2:

- The appearance setting is a display preference only.
- The session pace view is optional and OFF by default. It shows counts
  and elapsed time within a 4-hour window. It is not a goal, a streak,
  or a timer to beat, and it sends no notifications.
- The population reference on Trends uses a bundled, published statistic
  (Alcohol Research Group, 2020 National Alcohol Survey), named and dated
  in the app. It is not data from other users, and no network request is
  made — the app still contains no networking code.
- The CSV export and the month and year share images are user-initiated,
  one-way exports of the user's own data through the system share sheet,
  with no identifiers in the files. Each image carries only the user's own
  calendar and the four figures the app already shows for that period, with
  unlogged days stated — no comparison to anyone, no goal, no score.
- The calendar summary reports the user's own counts and totals over a
  chosen span — the last 30 days, the month shown, or the year shown. It
  compares nothing to any other period or person, sets no target, and is
  not shared or sent anywhere.
- Tapping a bar on Trends shows the facts behind it — the period's dates,
  its total, and what was logged by type, from the user's own log; for a
  week or month, the same four figures the calendar's summary card shows,
  computed over the bar's own days by the same code. Nothing is compared
  to a target, to the average line, or to other people; nothing about the
  selection is stored; nothing leaves the device.
- Siri/Shortcuts support uses App Intents only. Every phrase is
  user-initiated; the app never speaks first, sends no notifications, and
  makes no suggestions. Spoken replies state only what was written to the
  user's own log.
- The HealthKit contract is tighter, not looser: drinks imported from
  Health are read-only mirrors, and no screen offers to edit or delete
  one. The one thing a user can do with a single-drink import is add the
  type, size, and strength on Tallyist's side ("Add details"); that
  annotates the app's own row and never writes to, edits, or deletes the
  other app's Health sample. Deleting a logged drink still retracts only
  samples this app wrote. A zero-count sample another app wrote is shown
  as a no-alcohol day on the same terms — read-only, labeled, and removed
  when the sample is; nothing is written to Health for it. No new Health
  data type is read: it is the same alcoholic-beverages category, with a
  value of zero.
- Logging a drink without stating its type is a recording preference, not
  a new kind of data. The entry stores the standard-drink definition the
  app already uses for its totals, and the user can add the type, size,
  and strength later or leave them out. Nothing is inferred about the
  user and nothing is sent anywhere.
- No new permissions, no new privacy label categories, no new third-party
  code. There are still no accounts and no servers of any kind.
```

## What's New (1.3)

**As shipped** — the owner's own text, written in App Store Connect, the store's
What's New from 2026-09-20 until 1.4's replaces it (its version history keeps
it); word for word, wrapped here.
It has not been through the 1.4.3 review, and its "streak" is a word the
description above disclaims ("No goals, no streaks").

```
Re-designed the Today screen around the counter with a shared color scale.
Added a Cocktail drink type and custom icons throughout, and lets you share a
year in review as an image. Trends now compares your habits to published US
averages over your last 12 months, breaks out weekday vs. weekend drinking,
and tracks your longest alcohol free streak.
```

**The reviewed draft**, which did not ship:

```
Share a year in review: from the year view, a year that has ended can be
shared as an image of its twelve months — the same four figures the year
view shows (days with drinks, days with none, the total, and the average
on days with drinks), then standard drinks by month as a bar chart with
your monthly average drawn across it. The calendar image of the year is
still there; the share button offers both.

Trends' population reference now covers your last 12 months once your
record is a year old — the span the survey it cites asked about — and says
which span it covers. It also shows how many days you logged drinks on,
beside a published average for US adults who drink. A year that has ended
gets the same comparison on the year view. And a new By weekday card lists
what you logged on each day of the week, with your Friday-to-Sunday and
Monday-to-Thursday days counted, beside a published rate for US adults.

Settings gains a Comparisons section. Each of the three published
comparisons on Trends can be turned off, and the weekly-average comparison
can be placed against the survey's men's or women's column instead of all
adults — the same published table, a different column, with the sentence
saying which. The weekend comparison now appears for ranges of a month or
more.
Trends also gains a card for the longest run of days recorded as no alcohol
in the range shown; it counts only days marked that way, so a day with
nothing logged does not extend it.

The Today screen is rebuilt around the counter. The number now sits on the
same colour scale the calendar uses, so a day reads the same on both, and a
legend names the bands. The calendar's scale gains a step: the top band
splits into 6–9 and 10+ instead of one open-ended 6+. Under the counter, a
control shows which drink plus is repeating and logs a plain standard drink
instead in one tap. Add specific opens the full drink sheet whenever you
want it.

The drink sheet gains a fifth type, Cocktail, measured as the whole drink:
it opens at 4 oz at 15%, one standard drink, with 3 oz and 6 oz sizes a tap
away and a Custom field that asks for the ounces in the glass. Beer gains a
40 oz bottle size. Every drink type now has its own icon, shown
beside its name on the sheet's type control, on today's list, in History
and in Trends; the standard drink, Apple Health entries and days recorded
as no alcohol have theirs too. Siri understands "Log a cocktail in
Tallyist".

The app's five screens are now tabs — Today, Calendar, Trends, History and
Settings, each with its name — so any screen is one tap from any other, and
Settings is a page of its own rather than a sheet. The calendar's year
button now says Year.
```

## Reviewer notes (1.3) — paste into App Review notes

These restate the claims made in the 1.0 Resolution Center response and
kept through 1.2 (see docs/tallyist-1.3-spec.md, "App Review consistency").

```
Notes on what's new in 1.3:

- The year-in-review image is a user-initiated, one-way export of the
  user's own data through the system share sheet, like the month and year
  images in 1.2. It carries the same four figures the year view already
  shows for that year, a bar per calendar month of the user's own totals,
  and a "your average" line computed by the same rule as the Trends
  screen's, all on the device by the same code. No comparison to other people
  or to any guideline, no goal, no score, no identifier in the file, and
  nothing recorded about whether or where it was shared. It is offered
  only for a year that has ended; the app never prompts anyone to share.
- The population reference is unchanged in kind: a bundled, published
  statistic, computed on the device, with no network request. Its window
  now follows the length of the user's record (four weeks, then twelve
  months, matching the survey's own twelve-month measure), and the same
  comparison appears for a calendar year that has ended. Two further
  bundled, published, dated statistics sit beside the user's own counts —
  a mean number of drinking days (NESARC-III, 2012–13) and a weekend rate
  of days with a drink (NHANES 2005–10) — each a descriptive figure, each
  named with its source and year in the app. None is a guideline, a
  limit, a risk figure, or a category; the app never classifies the user
  and never compares to a threshold. The new By weekday card lists the
  user's own log by day of the week, with no ranking, and beside the user's
  Friday-to-Sunday and Monday-to-Thursday counts prints the weekend rate
  named above (Liang and Chikritzhs, 2015) — the same bundled figure, a
  rate and never a threshold.
- On the Trends screen, dragging across the bars reads one bar at a time in
  the chart card's header — the period's dates, its total, and for a week or
  month bar two of the four figures the calendar's summary card already shows
  (days with drinks, and the average on those days) and the longest run of
  days recorded as no alcohol inside that bar, all computed over the bar's
  own days by the same code. The selection lasts the touch and clears when
  the finger lifts. A selection reached with VoiceOver holds between steps
  and shows a fuller block below the chart with what was logged by type.
  Nothing is compared to a target, to the average line, or to other people;
  nothing about the selection is stored, and nothing leaves the device. (This
  corrects one line in the 1.2 notes: a *tap* does not open the type
  breakdown on iOS 26 — a held, accessibility-stepped selection does.)
- Trends adds one figure: the longest run of days recorded as no alcohol,
  as a card for the range shown and as the third fact in the bar readout.
  It counts only days the user explicitly recorded as alcohol-free (in the
  app, or as another app's Health zero), as a maximum over the chosen
  range, recomputed from the log each time: never a current count, never
  stored, no target, no reaction when it changes, "None recorded" at zero.
  It cannot grow by not logging — a day with nothing recorded ends a
  run, so only recording more lengthens it. It is not a streak but a count
  of the days the user has or has not had drinks, so their pattern can be
  read; the app keeps no streak and sets no goal.
- The Today screen's redesign is a display change: the counter takes the
  calendar's colour scale (the same bands, from the same code), that scale
  gains a step at the top (6–9 and 10+ where 6+ was), and one preference
  was removed. The optional, off-by-default session pace figure carries the
  same calendar colour from 6 standard drinks up — an amount on the app's
  one scale, not a warning; nothing red, no icon, no notification. No new
  data is recorded, nothing is inferred, and nothing leaves the device.
- A fifth drink type, Cocktail, is a label on the user's own entry, stored as
  the same two facts as every other type — the drink's volume and its
  strength, defaulting to one standard drink. A 40 oz
  size for beer is one more preset over the same facts. The drink icons are
  the app's own bundled artwork, replacing system symbols on the same
  surfaces. No new kind of data, no new permission, no network.
- The three published comparisons on Trends are each a setting the user can
  turn off (all on by default), and the weekly-average comparison can be
  placed against the survey's men's or women's column instead of its total.
  The columns are the same published table's own (Alcohol Research Group,
  2020), bundled with the app and renormalised the same way; the sentence
  names the column it read. The choice is a display preference stored on
  the device, like the region setting: the app records nothing about the
  person, asks no gender, and offers no option the survey does not publish.
  No comparison to a threshold, no ranking, no network.
- The screens moved into a standard tab bar (Today, Calendar, Trends,
  History, Settings) and Settings became a page instead of a sheet. A
  navigation change only: the same screens, the same controls on them, and
  nothing new recorded or read.
- No new permissions, no new privacy label categories, no new third-party
  code. There are still no accounts and no servers of any kind.
```

## What's New (1.4)

Reviewed under 1.4.3 (`docs/copy-review-1.4.3.md`, "1.4 release"). The store
shows the first lines and hides the rest behind "more", so the watch and the
Health figures come first. No sync timing is promised: the watch's sync has
not yet run on a TestFlight build (the reviewer notes say the same).

```
Tallyist is now on Apple Watch. Tap plus to log a drink, hold it to say what
it was, or record today as no alcohol. Today's count can sit on your watch
face or in the Smart Stack, and the watch syncs with your iPhone through
iCloud.

Trends can now show figures from Apple Health beside your log: resting heart
rate, sleep, heart rate variability, and wrist temperature, each as your
average on nights you logged drinks and on nights you recorded as no alcohol.
Each is off until you turn it on, and none of these figures is stored.

Trends' three comparisons now share one card, and the drinking days and
weekend figures, yours and the published ones, are drawn as bars. On iOS 27,
text on cards is easier to read and the range and settings pickers switch on
a single tap.
```

## Reviewer notes (1.4) — paste into App Review notes

These restate the claims made in the 1.0 Resolution Center response and kept
through 1.3, and add what 1.4 introduces: a watchOS app, a HealthKit read
permission for four types, and the remote-notification background mode. The
closing line of the 1.2 and 1.3 notes ("No new permissions…") is **not**
repeated, because 1.4 does add a permission; what replaces it says exactly what
is new. The claims table behind every sentence is in
`docs/tallyist-1.4-spec.md`, "App Review consistency". Two plans asked for these
notes to be written as though the 1.0 conversation were being reopened; they
are. Neither the word "monitoring" nor any watch model appears in them, on
purpose (`docs/health-pairing-phase-0-findings.md`, ADR-0053).

**Attach** the Trends screenshot of the Apple Health card
(`Claude outputs/1.4-screenshots/iphone-6.9/iphone-06b-health-quarter-light.png`)
in App Review Information, because a review device usually has no Health data
for these types and the section is designed to show nothing then.

**Length:** App Store Connect's Notes field holds 4,000 characters. The block
below is 3,779. A first draft ran to 5,236 and was cut; any addition has to fit
the same limit, so count before pasting (`wc -c`).

```
What's new in 1.4. The four claims of our 1.0 response hold: no goals,
streaks, scores or advice; no user-generated content shared between users;
no accounts; no external services.

1. Apple Watch app (new)
- A companion app for logging on the wrist. Plus logs a drink (Double Tap
  too, while the app is on screen), a hold of plus logs a chosen type, minus
  removes today's newest drink, and a button records today as no alcohol. It
  requires the iPhone app.
- No account and no network requests of its own. Its log syncs through the
  user's own private iCloud database, the iPhone app's container. The iPhone
  sends the watch two settings over WatchConnectivity (region and what plus
  logs); no drink travels that way.
- No HealthKit entitlement. The iPhone app saves a watch drink to Health,
  with the user's permission, the next time it is opened after the drink
  syncs.
- Complications show today's count; the rectangular one has a plus. Counts
  are marked privacy-sensitive, so watchOS redacts them on a locked watch.
  No notifications, streaks or scores.

2. Background mode: remote-notification (iPhone and watch)
- Lets the silent notifications CloudKit sends for the user's private
  database update the store while the app is closed. No visible
  notification, no push server of ours. The iPhone project has set this
  since 1.0, but it first reaches the built Info.plist in 1.4.

3. Apple Health on Trends (new, optional read permission)
- If turned on, Trends shows resting heart rate, sleep, heart rate
  variability and sleeping wrist temperature, each as the user's average on
  nights with drinks logged and on nights recorded as no alcohol, side by
  side with night counts. That is the whole feature.
- Off by default: one switch per metric in Settings, or a one-time card on
  Trends. Permission is requested only then, separately from the alcohol
  permission; never at onboarding, and never again after "Not now".
- Read on the device for one render: nothing these reads return is saved,
  synced, written to Health or sent anywhere. App Privacy stays Data Not
  Collected. The purpose string and the privacy policy
  (https://tallyist.co/privacy/) name the four types.
- No difference is computed; neither figure is coloured, bolded, signed or
  ranked. No diagnosis, advice, threshold, goal, score, notification, or
  inference about drinking from physiology. Today is never included.
- Below a minimum number of nights on both sides, or with no readings,
  nothing is shown.
- To see it: when, among the five days from six days ago through two days
  ago, the log has drinks on two days and two other days recorded as no
  alcohol (both can be entered from the calendar), Trends at Week shows the
  card with dashes, and accepting it shows the permission sheet. Figures
  need Health readings for those nights, normally from an Apple Watch; sleep
  can be added by hand (Health, Browse, Sleep, Add Data). The attached
  screenshot is from a simulator with sample Health data. It shows three
  rows, because an app cannot write wrist temperature to Health.
- Review builds show a Diagnostics section in Settings. Its "Last Health
  read" rows hold a metric name, a day count, the read's duration, and which
  part of the app read it and when; never a value.

4. Other changes
- Trends' three comparisons share one card, two of them drawn as bars. Same
  sources, same figures.
- iOS 27 readability and control fixes, shorter Settings wording, and
  clearer errors: an unreadable log now says so instead of showing an empty
  day.

New in 1.4: the watch app, a HealthKit read for four types behind switches
that start off, and the remote-notification background mode. No new privacy
label categories, no third-party code, no accounts, no servers.
```

## Reminders for the version page

- Age rating: answer the alcohol question honestly — "Alcohol, Tobacco, or
  Drug Use or References: Infrequent/Mild" lands the app at 17+, which is
  correct for this category.
- App Privacy: **Data Not Collected** (matches the privacy manifests; see
  docs/privacy-policy.md for the reasoning App Review can follow).
- Screenshots: Today (counter), Calendar (with a drag selection), Trends,
  the widget. Nothing staged with high counts — the numbers in screenshots
  are part of the tone. For 1.3, retake Today (the counter now carries the
  day's colour, with the legend and the plus pill), Calendar (the four-band
  legend) and Trends (the chart card's header readout and the By weekday
  card) — both the iPhone and the iPad sets — keeping the counts low per the
  note above; the widget shot is unchanged. Any shot showing drink rows or
  the drink sheet is stale as well: the drink glyphs are new (ADR-0036) and
  the sheet's type control shows five glyph-and-name segments. And every
  in-app shot is stale in one more way since ADR-0040: the tab bar is now on
  every screen (along the bottom on iPhone, the top on iPad), Today has no
  toolbar, and the calendar's toolbar reads "Year" — retake the whole in-app
  set, not only the three named above.
- The tip-jar IAPs must be submitted for review with the first version that
  contains them (select all three products on the version page).

**For 1.4 specifically** (added 2026-09-24):

- **Description:** paste (A) or (B) from "Description for 1.4". The live one
  lacks the 3.1.2(a) subscription paragraph and says nothing about the Health
  reads, and 1.4 is the version a reviewer will read it beside.
- **App Privacy stays Data Not Collected**, and no answer changes. The
  reasoning, checked against the build rather than assumed, is in
  `docs/tallyist-1.4-spec.md` ("App Privacy"). The regulated medical device
  declaration (App Information → App Store Regulations & Permits) stays "No".
- **Age rating:** no question's answer changes. The Health figures give no
  diagnosis, guidance or recommendation, so "Medical or Treatment Information"
  and "Health or Wellness Topics" are unaffected
  (`docs/health-pairing-phase-0-findings.md`). The lookup API reads 17+ today.
- **Screenshots:** the watch needs its own set (Apple Watch, one size is
  enough; 416 × 496 from a 46mm simulator is an accepted size), and every
  in-app iPhone and iPad shot is still stale since the tab bar. Candidate sets
  from a seeded scratch simulator are in `Claude outputs/1.4-screenshots/` in
  the main checkout, with a README saying what each shows and how it was
  made. Nothing there is uploaded.
- **App Review Information:** paste "Reviewer notes (1.4)" (3,779 characters,
  under the field's 4,000) and attach the Health card screenshot it names.
- **The website's addresses.** On the 1.4 version, set the Privacy Policy URL
  (App Information) to `https://tallyist.co/privacy/`, and the Support URL and
  Marketing URL (the version page) to `https://tallyist.co/support/` and
  `https://tallyist.co/`. App Store Connect takes these only with a version,
  which is why they wait for 1.4; until then the listing's `semmes.github.io`
  addresses redirect to the same pages, and they go on redirecting afterwards.
  Tick **Enforce HTTPS** in `semmes/Tallyist` → Settings → Pages first
  (ADR-0024, amended 2026-09-24).
- **When 1.4 is live,** set `platform_state: 2` in `semmes/Tallyist`'s
  `_config.yml` (the site's own file, not a mirrored one). The support page
  then answers the watch question with "Yes" and drops "From version 1.4".
- **Before submitting,** run one TestFlight build across a phone and a watch
  on one iCloud account: log on each, with each app closed in turn, and on
  the watch from the Smart Stack card's plus. The watch's sync has never run
  on a TestFlight build (Production CloudKit and production push). The What's
  New and the notes promise no timing for this reason. If ADR-0055 is merged,
  that build is also its device check: tap the card's plus with the watch app
  force-quit and note when the drink reaches the phone (ADR-0055,
  "Verification").
