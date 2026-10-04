# App Store listing — paste-ready metadata

**Status:** 1.0 (2026-08-25), 1.1 (2026-09-01), 1.2 (2026-09-05) and 1.3
(2026-09-20) live — the dates are the store's own (its version history, and
for 1.0 the app's release date), read on 2026-09-23, when the owner reported
1.3's approval; 1.4 submitted for review on 2026-09-26 (the owner; build
1.4 (1)), carrying the Apple Watch app and Apple Health on Trends together
(ADR-0054), and rejected on 2026-10-04 on two metadata items, a promotional
image (2.3.2) and the Terms of Use link (3.1.2(c)). **1.4 was never
released:** the same day the owner renamed that version 1.5 in App Store
Connect, attached a 1.5 build from `main` and resubmitted it with the
subscription group and both recurring tips, so 1.5 carries 1.4's features and
the Trends work of ADR-0058 and ADR-0059 ("The rejection of 1.4 (1),
2026-10-04" says what happened). 1.5's What's New and reviewer notes below
are the combined ones handed over for that submission ·
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
recurring tips exist (guideline 3.1.2(c) and Apple's subscriptions page: each
recurring tip's title, period and price, and the Terms of Use and privacy links).

## App Information

| Field | Value |
|---|---|
| Name | **Tallyist** |
| Subtitle (30 chars max) | `Your drinks, tallied.` |
| Primary category | Health & Fitness |
| Privacy Policy URL (App privacy page) | `https://tallyist.co/privacy/` (from 1.4) |
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
— Press and drag across the calendar to fill several days at once
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
auto-renews monthly) or A Drink Every Year ($99.99/year, auto-renews yearly).
Tips unlock nothing. Recurring tips renew automatically until cancelled in
your App Store account settings, at least 24 hours before the period ends.
If you allow notifications, Tallyist reminds you a week before each renewal
so you can cancel first if you want.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://semmes.github.io/Tallyist/privacy/
```

Notes on the description, so edits keep it compliant:
- **Guideline 3.1.2(c) and Apple's subscriptions page**
  (developer.apple.com/app-store/subscriptions/) are why the tip paragraph
  names each subscription's title, duration, and price per period, and why
  both links appear verbatim: "your app and App Store metadata must include
  links to your Terms of Use and Privacy Policy". (This line credited
  3.1.2(a) until 2026-09-26; that section is about permissible uses.)
  Keep all of that if you rewrite the rest. If ASC prices ever change, change
  them here in the same breath.
- **Guideline 1.4.3** is why there are no health claims, no "drink less"
  framing, and no promises — the description only says what the app does.

### Description for 1.4

*Also the description for 1.5, since 1.4 was never released. On 2026-10-04
the owner added the two link lines that close (A) and (B) to the text in App
Store Connect, after App Review found no Terms of Use link (guideline
3.1.2(c)); which text was there before is visible only in App Store Connect.*

**Paste one of these before 1.4 is submitted.** The live description (the
owner's own, read 2026-09-23 and described in the status block above) has no
subscription paragraph, which guideline 3.1.2(c) and Apple's subscriptions
page require while recurring tips are sold, and it says nothing about the two
things 1.4 adds. Guideline 2.5.1 asks
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
— Press and drag across the calendar to fill several days at once
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
auto-renews monthly) or A Drink Every Year ($99.99/year, auto-renews yearly).
Tips unlock nothing. Recurring tips renew automatically until cancelled in
your App Store account settings, at least 24 hours before the period ends.
If you allow notifications, Tallyist reminds you a week before each renewal
so you can cancel first if you want.

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

Tallyist is free, and everything in it is free. There's an optional tip jar: a one-time $4.99 tip, or recurring support at A Drink Every Month ($4.99/month, auto-renews monthly) or A Drink Every Year ($99.99/year, auto-renews yearly). Tips unlock nothing. Recurring tips renew automatically until cancelled in your App Store account settings, at least 24 hours before the period ends. If you allow notifications, Tallyist reminds you a week before each renewal.

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

*Never published: 1.4 was resubmitted as 1.5 on 2026-10-04, and this text is
folded into What's New (1.5) below.*

Reviewed under 1.4.3 (`docs/copy-review-1.4.3.md`, "1.4 release"). The store
shows the first lines and hides the rest behind "more", so the watch and the
Health figures come first. No sync timing is promised: the watch's sync has
not yet run on a TestFlight build (the reviewer notes say the same). It is
wrapped here for reading, and the store keeps line breaks (1.2's shipped notes
break mid-sentence), so join each paragraph onto one line before pasting and
keep the blank lines between paragraphs.

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

The tip jar in Settings now offers a recurring tip too, monthly or yearly.
Tips unlock nothing.
```

The last paragraph was added on 2026-09-26, when the owner decided the
recurring tips go on sale with 1.4 (guideline 2.3.12 asks What's New to
describe product changes, and 1.4 is the first version that sells them). It
went through the same review. If App Review rejects the subscriptions and they
are removed from the submission, remove this paragraph too.

## Reviewer notes (1.4) — paste into App Review notes

*Superseded on 2026-10-04 by the reviewer notes (1.5) below, which carry this
block's claims for the combined release. The block here is the revision
written after the rejection; 1.4 (1) was submitted while this file held the
2026-09-26 text, which still had the "Other changes" item (3,958 bytes).*

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
(`Claude outputs/1.4-screenshots/app-store-upload/iphone-6.9-1320x2868/iphone-06b-health-quarter-light.png`,
the copy without an alpha channel) in App Review Information, because a review device usually has no Health data
for these types and the section is designed to show nothing then.

**Length:** App Store Connect's Notes field holds 4,000 bytes ("The Notes
field can contain up to 4000 bytes", Platform version information), and a
character outside ASCII counts as more than one. The block below is 3,938
bytes, all ASCII. The recurring tips' item was added on 2026-09-26 (3,958
bytes then). On 2026-10-04, after the rejection, it gained where each
subscription's title, period and price and the two links are, as App Review
asked, and the "Other changes" item (Trends' comparisons in one card, the iOS
27 fixes, the unreadable-log message) was dropped to make room: What's New
says the same and nothing in it is a claim App Review checks. A first draft
ran to 5,236 and was cut; any addition has to fit the same limit, so count
before pasting (`wc -c`).

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
  with the user's permission, the next time it opens after the drink syncs.
- Complications show today's count; the rectangular one has a plus. Counts
  are marked privacy-sensitive, so watchOS redacts them on a locked watch.
  No notifications, streaks or scores.

2. Background mode: remote-notification (iPhone and watch)
- Lets the silent notifications CloudKit sends for the user's private
  database update the store while the app is closed. No visible
  notification, no push server of ours. Set in the iPhone project since
  1.0, it first reaches the built Info.plist in 1.4.

3. Apple Health on Trends (new, optional read permission)
- If turned on, Trends shows resting heart rate, sleep, heart rate
  variability and sleeping wrist temperature, each as the user's average on
  nights with drinks logged and on nights recorded as no alcohol, side by
  side with night counts.
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
  alcohol (the calendar can enter both), Trends at Week shows the
  card with dashes, and accepting it shows the permission sheet. Figures
  need Health readings for those nights, normally from an Apple Watch; sleep
  can be added by hand (Health, Browse, Sleep, Add Data). The attached
  simulator screenshot uses sample Health data and shows three rows, as no
  app can write wrist temperature to Health.
- Review builds show a Diagnostics section in Settings. Its "Last Health
  read" rows hold a metric, a day count, a duration, the process that read
  it and a time; never a value.

4. Recurring tips (new in-app purchases)
- Settings > About > Buy me a drink: a monthly and a yearly auto-renewable
  tip beside the one-time one. They unlock nothing. Each row shows the
  tip's title and its price per month or per year. Privacy Policy and Terms
  of Use (Apple's standard EULA) links are at the bottom of that screen, and
  the App Store description ends with both links.
- After subscribing, the app asks for notification permission, for a
  reminder a week before each renewal.

New in 1.4: the watch app, a HealthKit read for four types behind switches
that start off, the remote-notification background mode, and two recurring
tips. No new privacy label categories, no new third-party code, no accounts,
no servers.
```

## The rejection of 1.4 (1), 2026-10-04

App Review rejected 1.4 (1) on two items (submission
9737e7ce-75ea-4311-9e53-54eb8657faa3, reviewed on an iPad Air 11-inch (M3)).
Both are metadata. Apple's help ("Reply to App Review messages"): "If your app
was rejected for a metadata issue, you can resubmit the same build after
resolving the issue." So no build is needed, and nothing is cut from `main`,
which is the 1.5 train. The tip jar (`SupportView.swift`, `TipJar.swift`) and
the Settings route to it are the same at 98e494b, the commit 1.4 (1) was
archived from, as on `main` at 7971151. Only the StoreKit test file's yearly
price differs ($99.99 on `main`), and the store build does not carry that file.

**Guideline 2.3.2, the promotional image.** Apple's words: "Your promotional
image includes text that is small or otherwise hard to read." This is an in-app
purchase's Image section (App Store promotion). It is not the version's
Promotional Text and not the App Review Screenshot. No record here made or
asked for one, so which item carries it shows only in App Store Connect (the
rejected item under Resolve). Three things from Apple's help:
- "An image is required if you want to promote your In-App Purchase on your
  App Store product page or set up win-back offers."
- "Your app must support the PurchaseIntent API in order for the App Store to
  display your promoted product pages." For a promotion shown to all users:
  "If you select this option, but haven't implemented the PurchaseIntent API,
  your In-App Purchase won't be visible on the App Store."
- Images "should not be screenshots, and should not be confused with your app
  icon", are "usually seen at small sizes", and are 1024 × 1024, JPG or PNG,
  "72 dpi, RGB, flattened and no rounded corners".

Tallyist has no `PurchaseIntent` handling (nor StoreKit 1's
`shouldAddStorePayment`) and no offer-code sheet, and no record here sets up a
win-back offer, so an image does nothing for 1.4. **Recommended: remove it**
rather than redraw it. In the item's
Image section, "move your pointer over it and click the remove icon (—)", and
leave the item unpromoted. Promoting a tip later needs the `PurchaseIntent`
handling first, in a build, and then a text-free image for each promoted item.

**Guideline 3.1.2(c), the Terms of Use.** Apple's words: "The following
information needs to be included in the App Store metadata: a functional link to
the Terms of Use (EULA) (if you are using the standard Apple Terms of Use
(EULA), include a link in the App Description, and if you are using a custom
EULA, add it in App Store Connect)." Descriptions (A) and (B) end with that
link, but what 1.4's Description field held when it was submitted shows only in
App Store Connect. Make it end with these two lines, keep App Information's
License Agreement on Apple's standard EULA, and check that the Privacy Policy
URL reads `https://tallyist.co/privacy/`:

```
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://tallyist.co/privacy/
```

The app's half already holds in 1.4 (1). Each recurring row shows the product's
`displayName` over "<price> per month · cancel any time" (or "per year"), and
the screen's footer links Privacy Policy (the in-app policy) and Terms of Use
(Apple's standard EULA). Apple asks for two more things: a screen recording with
the reply, and "this information in the Notes field of the App Review
Information section in App Store Connect for future submissions". The reviewer
notes (1.4) above now carry it, in item 4.

**In App Store Connect** (Apple's help, "Manage a submission with unresolved
issues"): App Review, Resolve next to the submission, then Edit next to each
rejected item, make the change, and Add for Review. Once every rejected item is
edited, Resubmit to App Review. "You can edit items in a submission once before
resubmission", so make all of an item's changes in one edit. And "you can't add
back removed items to the same submission", so remove a subscription only for
the contingency under "For 1.4 specifically". Paste the reviewer notes (1.4)
above into the version's App Review Information before resubmitting.

**The screen recording.** On a phone with 1.4 (1) from TestFlight, start a
screen recording and open Settings → About → Buy me a drink. Hold on the
Recurring rows so both names and prices can be read, scroll to the bottom, tap
Terms of Use (Apple's page opens in Safari), come back, and tap Privacy Policy.
If that build shows no Recurring section, the sandbox is not serving the
subscriptions to it (on 2026-09-26 it served only the one-time tip). Record an
Xcode Run of the DrinkTracker scheme on an iPhone simulator instead (in the
Simulator, File → Record Screen), where the scheme's StoreKit configuration
supplies both rows at App Store Connect's prices. That screen and the route to
it are the same code as in 1.4 (1), and neither shows a version number.

**The reply** (Reply to App Review, with the recording attached; copy review,
2026-10-04):

```
Hello,

Thank you for the review. We have addressed both items and are resubmitting the same build, 1.4 (1).

Guideline 3.1.2(c): The description now ends with a link to the Terms of Use, Apple's standard EULA (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), followed by our privacy policy (https://tallyist.co/privacy/), which is also the Privacy Policy URL. In the app, Settings > About > Buy me a drink shows each auto-renewable subscription's title and its price per month or per year, with Privacy Policy and Terms of Use links at the bottom of the screen. The attached screen recording shows that screen and both links. The Notes field in App Review Information now says where to find them.

Guideline 2.3.2: We removed the promotional image. These in-app purchases are not promoted on the App Store.
```

If more than one item had an image, say "images". If the image is replaced
rather than removed, the last paragraph becomes "Guideline 2.3.2: We replaced
the promotional image for <name> with one that has no text."

**What happened (2026-10-04).** The reply above was not sent: the release went
back as 1.5 instead, in the steps below. They are as the owner reported them.

- **Where the image was.** On *A drink every month*
  (`com.shawnsemmes.DrinkTracker.support.monthly`), the only item with one:
  `image.png`, 122,540 bytes. Its promotion was set to "Display this promotion
  to all App Store users", with Displayed checked, until the owner unchecked
  it. No record here says who uploaded it, and the owner did not remember
  doing so. On the promotion page App Store Connect itself warned: "These
  in-app purchases or subscriptions can't be promoted on the App Store because
  your latest approved binary doesn't include the required StoreKit APIs."
- **Why the website would not remove it.** Apple's API keeps a subscription's
  image on a subscription version, and only a version in
  `PREPARE_FOR_SUBMISSION` can change ("Working with subscription versions",
  App Store Connect API 4.4.1). This image's version was `READY_FOR_REVIEW`,
  attached to the submission. A script the owner ran with their own API key
  (`Claude outputs/1.4-rejection/delete_promo_image.py`, untracked) read that
  state, and Apple refused both changes it tried: removing the promotion
  ("Promoted purchase has an image. Please delete the image first.",
  `ENTITY_ERROR.ATTRIBUTE.INVALID.UNMODIFIABLE`) and deleting the image
  ("Version is not in modifiable state.",
  `STATE_ERROR.SUBSCRIPTION_VERSION_UNMODIFIABLE`).
- **Why Resolve could not fix it either.** App Review had filed both issues
  against the app version, so on the Resolve page only the version had Edit;
  the subscription could only be removed. The owner removed *A drink every
  month* from the submission (it then read Developer Rejected), deleted the
  image on the website, and Add for Review failed with "Unable to Add for
  Review. Something went wrong. Try again.", since Apple does not let a
  removed item back into the same submission.
- **What was submitted.** The owner changed the version number on the version
  page from 1.4 to 1.5 (the API's `versionString`), replaced build 1.4 (1) with
  a 1.5 build that Xcode Cloud archived from `main`, added the two link lines
  to the description, re-added the subscriptions for review and submitted. The
  app code on `main` is the same from 525f208 (ADR-0059's merge) through
  36ec5e6, the head that day, so any 1.5 build from that range is the same
  app. **Not reported:** the build number, whether the old submission was
  cancelled, whether the combined What's New and notes below were pasted as
  they are, and whether a screen recording was attached.
- **For next time.** An in-app purchase's Image is optional and promotes
  nothing in this app, which has no `PurchaseIntent` handling (ADR-0012's
  amendment of 2026-10-04): leave it empty. If App Review files an in-app
  purchase's problem against the app version, that item stays locked in the
  submission. Removing it keeps it out of that submission for good ("you
  can't add back removed items to the same submission"). Cancelling the
  whole submission is the other route Apple's help documents (the version
  becomes Developer Rejected and review starts over); whether that unlocks a
  subscription's image was not tried here.

## What's New (1.5)

Combined on 2026-10-04, when 1.4 was resubmitted as 1.5: 1.4's paragraphs and
the 1.5 draft of 2026-10-01, the watch first because the store shows only the
first lines. One sentence changed in the merge: 1.4's "Trends' three
comparisons now share one card, …" became "The comparisons share one card, …"
at the end of the Trends paragraph, and its iOS 27 sentence became a paragraph
of its own. Every other sentence is word for word from the two reviewed texts
(`docs/copy-review-1.4.3.md`, 2026-10-04). One paragraph per line, as handed
over for pasting; 1,467 characters.

```
Tallyist is now on Apple Watch. Tap plus to log a drink, hold it to say what it was, or record today as no alcohol. Today's count can sit on your watch face or in the Smart Stack, and the watch syncs with your iPhone through iCloud.

Trends can now show figures from Apple Health beside your log: resting heart rate, sleep, heart rate variability, and wrist temperature, each as your average on nights you logged drinks and on nights you recorded as no alcohol. Each is off until you turn it on, and none of these figures is stored.

Trends now compares the range you pick. At Week, Month, Quarter and Year, the weekly average, the drinking days and the weekend days cover the same days as the chart above them, and the Quarter line is the same weekly average the comparison shows. Week now shows all three comparisons. The comparisons share one card, and the drinking days and weekend figures, yours and the published ones, are drawn as bars.

If your log is newer than the range, the figures that count days start from your first record, and Trends shows that date.

At Quarter and Year, you can now choose how the chart is divided: by day or week at Quarter, and by day, week or month at Year. The dashed line shows your daily, weekly or monthly average to match.

On iOS 27, text on cards is easier to read and the range and settings pickers switch on a single tap.

The tip jar in Settings now offers a recurring tip too, monthly or yearly. Tips unlock nothing.
```

## Reviewer notes (1.5) — paste into App Review notes

Combined on 2026-10-04 for the 1.5 submission: 1.4's notes as revised after
the rejection, with a Trends item from the 1.5 draft of 2026-10-01, cut to fit
the field. 3,953 bytes, all ASCII, 67 lines (the field holds 4,000 bytes, and
1.4's 3,958-byte notes fitted it; count with `wc -c` after any change). What the
merge cut is either said elsewhere or not a claim App Review checks:
- From the watch item, "No notifications, streaks or scores." (the opening
  line already says no streaks or scores); from the background mode, its
  history ("Set in the iPhone project since 1.0, it first reaches the built
  Info.plist in 1.4.").
- From the Health item, "Below a minimum number of nights on both sides, or
  with no readings, nothing is shown.", the hint that sleep can be added by
  hand in Health, and why the attached screenshot shows three rows. The
  Diagnostics bullet is shorter.
- From the 1.5 draft, the Quarter line's sentence and the names of the three
  surveys. Item 5 keeps that the comparisons follow the range picked from
  four weeks of record, the "Since" date, that they are bundled, dated,
  sourced and computed on the device, and the filter button.

The 1.5-only notes of 2026-10-01 (1,746 bytes) are superseded by this block.

```
What's new since 1.3 (1.4 was not released). The four claims of our 1.0
response hold: no goals, streaks, scores or advice; no user-generated
content shared between users; no accounts; no external services.

1. Apple Watch app (new)
- A companion app for logging on the wrist. Plus logs a drink (Double Tap
  too, while the app is on screen), a hold of plus logs a chosen type, minus
  removes today's newest drink, and a button records today as no alcohol. It
  requires the iPhone app.
- No account or network requests of its own. Its log syncs through the
  user's private iCloud database (the iPhone app's container). The iPhone
  sends it two settings over WatchConnectivity; no drink travels that way.
- No HealthKit entitlement. The iPhone app saves a watch drink to Health,
  with the user's permission, the next time it opens after the drink syncs.
- Complications show today's count; the rectangular one has a plus. Counts
  are marked privacy-sensitive, so watchOS redacts them on a locked watch.

2. Background mode: remote-notification (iPhone and watch)
- Lets CloudKit's silent notifications for the user's private database
  update the store while the app is closed. No visible notification, no
  push server of ours.

3. Apple Health on Trends (new, optional read permission)
- If turned on, Trends shows resting heart rate, sleep, heart rate
  variability and sleeping wrist temperature, each as the user's average on
  nights with drinks logged and on nights recorded as no alcohol, side by
  side with night counts.
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
- To see it: when, among the five days from six days ago through two days
  ago, the log has drinks on two days and two other days recorded as no
  alcohol (the calendar can enter both), Trends at Week shows the card with
  dashes, and accepting it shows the permission sheet. Figures need Health
  readings for those nights, normally from an Apple Watch. The attached
  simulator screenshot uses sample Health data.
- Review builds show Settings > Diagnostics, whose "Last Health read" rows
  list the metric, days, duration, process and time; never a value.

4. Recurring tips (new in-app purchases)
- Settings > About > Buy me a drink: a monthly and a yearly auto-renewable
  tip beside the one-time one. They unlock nothing. Each row shows the
  tip's title and its price per month or per year. Privacy Policy and Terms
  of Use (Apple's standard EULA) links are at the bottom of that screen, and
  the App Store description ends with both links.
- After subscribing, the app asks for notification permission, for a
  reminder a week before each renewal.

5. Trends (changed)
- The comparisons now cover the range the user picks, once the log holds
  four weeks; a log newer than the range counts from its first record and
  says "Since" that date. Still bundled, dated statistics named with their
  sources and computed on the device; none is a guideline or risk figure.
- A filter button by the legend at Quarter and Year divides the bars by
  day, week or month; the choice is not stored.

New since 1.3: the watch app, a HealthKit read for four types behind
switches that start off, the remote-notification background mode, and two
recurring tips. No new privacy label categories, third-party code,
accounts or servers.
```

## Reminders for the version page

- Age rating: answer the alcohol question honestly. This line used to say
  "Infrequent/Mild" lands the app at 17+, which was never right. The live
  product page shows **18+**, with "Frequent" for Alcohol, Tobacco, Drug Use
  or References (read 2026-09-26). The lookup API's 17+ is the same answer on
  Apple's scale for devices before OS 26, where frequent is 17+; infrequent
  would be 12+ there and 13+ on OS 26
  (`docs/health-pairing-phase-0-findings.md`, "Seen in passing"). What App
  Store Connect holds is visible only there.
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
  contains them. Apple's rule, then and now, is per type: the first in-app
  purchase of each type is submitted with a new app version. The 1.4 bullet
  on in-app purchases below applies it to the two recurring tips.

**For 1.4 specifically** (added 2026-09-24):

*1.4 became 1.5 on 2026-10-04 ("The rejection of 1.4 (1), 2026-10-04"), so
what follows applies to the 1.5 submission, and "1.4" in it means that
version.*

- **Description:** paste (A) or (B) from "Description for 1.4". The live one
  lacks the 3.1.2(c) subscription paragraph and says nothing about the Health
  reads, and 1.4 is the version a reviewer will read it beside. The recurring
  tips go on sale with 1.4, so keep the subscription paragraph, and make its
  names and prices match what App Store Connect holds for the two
  subscriptions (the next bullet). (A) is wrapped for reading here and the
  store keeps line breaks, so join each paragraph of (A) onto one line before
  pasting; (B) is already unwrapped.
- **App Privacy stays Data Not Collected**, and no answer changes. The
  reasoning, checked against the build rather than assumed, is in
  `docs/tallyist-1.4-spec.md` ("App Privacy"). The regulated medical device
  declaration (App Information → App Store Regulations & Permits) stays "No".
- **Age rating:** no question's answer changes. The Health figures give no
  diagnosis, guidance or recommendation, so "Medical or Treatment Information"
  and "Health or Wellness Topics" are unaffected
  (`docs/health-pairing-phase-0-findings.md`). The product page shows 18+ with
  "Frequent" alcohol references (2026-09-26), not the 17+ this file used to
  give.
- **The recurring tips go on sale with 1.4** (the owner, 2026-09-26). The
  live product page lists one in-app purchase, "Buy the creator a drink" at
  $4.99, and neither subscription. On 2026-09-26 the App Store's sandbox also
  returned only that product to a simulator build of 1.4, so the two
  subscriptions are not yet in a state it serves; missing metadata is the
  usual reason. Apple's help says a first auto-renewable subscription "must be
  submitted with a new app version", "together with its subscription group",
  in "the same draft submission". In App Store Connect (Account Holder, Admin
  or App Manager), Monetization → Subscriptions:
  1. **The group** ("Support" in the StoreKit file). Add an English (U.S.)
     display name, which people "will see … when they manage subscriptions on
     their devices". Suggested: "Recurring tip" (copy review, 2026-09-26). Set
     App Name Display Options.
  2. **Each subscription**, both at the same level, as the StoreKit file has
     them:
     - Product ID exactly `com.shawnsemmes.DrinkTracker.support.monthly` or
       `…support.yearly`, as `TipJar.swift` has them. "The product ID isn't
       editable after you save the In-App Purchase."
     - Duration 1 month or 1 year ("can't be changed after you submit for
       review"), price $4.99 for the monthly tip and $99.99 for the yearly
       one (ADR-0012, amended 2026-09-26), the app's storefronts, Family
       Sharing off as in the StoreKit file.
     - Localization: a Display Name (2 to 30 characters) and a Description
       (45 at most). The StoreKit file has "A drink every month" and "A drink
       every month. Cancel any time." and the yearly equivalents; the
       descriptions (A) and (B) say A Drink Every Month and A Drink Every Year.
       Whatever goes in here, use the same names in the description.
     - App Review Screenshot (required): Settings → About → Buy me a drink
       with both rows showing. Take it from an Xcode Run of the DrinkTracker
       scheme on a simulator, where the scheme's StoreKit configuration
       supplies the rows. A TestFlight build shows them only once the sandbox
       serves the subscriptions, which it may not do while their metadata,
       this screenshot included, is incomplete. Keep the StoreKit file's
       names and prices the same as App Store Connect's, so the screenshot
       matches what the reviewer's build shows.
     - Review Notes ("should not exceed 4000 characters"). A draft, the
       owner's to change: "A
       voluntary recurring tip to the developer of a free app. It unlocks
       nothing; every feature is free for everyone. Guideline 3.1.1 allows
       tips to the developer. If the subscriber allows notifications, the app
       reminds them a week before each renewal, and Manage or cancel is on the
       same screen. Where: Settings > About > Buy me a drink."
     - Image (App Store promotion): leave it empty (added 2026-10-04). App
       Review rejected 1.4 (1) over one under guideline 2.3.2, and promoting
       a tip does nothing for this build, which has no `PurchaseIntent`
       handling. "The rejection of 1.4 (1), 2026-10-04" has the details.
  3. **Add for Review:** each subscription in Prepare for Submission with no
     missing metadata, platform iOS and version 1.4, with the group added too
     ("If you're submitting a subscription and the subscription group hasn't
     been approved yet, add the subscription group to the submission as
     well"), all in the same draft submission as the 1.4 version. The group
     alone is not enough: a draft holding the version and the group but
     neither subscription showed "Unable to Submit for Review. New
     subscription groups must be submitted with an auto-renewable
     subscription from within that group." (2026-09-26). Each subscription is
     added from its own page, with its own Add for Review.
  - **If App Review rejects the tips.** Guideline 3.1.2(a) says "If you offer
    an auto-renewable subscription, you must provide ongoing value to the
    customer", and these unlock nothing, so a rejection is a real possibility
    (ADR-0012's amendment of 2026-09-26). The version waits on them: "All
    items submitted together must be Accepted to complete the submission."
    Remove them from the submission, click Resubmit, and edit three texts
    first. In the description, (A) or (B), cut the tip paragraph to the
    one-time tip: end its tip-jar sentence at "a one-time $4.99 tip." and
    delete the whole "Recurring tips renew automatically…" sentence. Paste
    What's New without its last paragraph. In the reviewer notes, delete item
    4 (numbered 5 until 2026-10-04) and change the closing line's list back to "…a HealthKit read for four
    types behind switches that start off, and the remote-notification
    background mode." The 1.4 build handles that case: with no subscription on
    sale the tip jar shows no Recurring section, which was checked on a
    simulator against the sandbox's real reply.
  - **The reminder promise (decided 2026-09-26).** The descriptions (A) and
    (B), the base description, the support page and the README now say "If
    you allow notifications, Tallyist reminds you a week before each renewal",
    the owner's choice once the fix made the reminder depend on it (a device
    that has never been asked schedules none until the tip jar is opened
    there). The app keeps it for a year of renewals past its last launch or
    foreground (ADR-0012's amendment, Costs). The privacy policy's "the app
    offers a local reminder" already fitted and is unchanged.
  - **Apple Watch.** The same help page says "In-App Purchases and
    subscriptions aren't supported on Apple Watch. To submit an Apple Watch
    app version, remove all in-app purchases and subscriptions from the
    submission." Tallyist has no Apple Watch app version in that sense:
    "Watch-only apps are considered part of the iOS platform in App Store
    Connect", and "To offer your app on iPhone and Apple Watch, create an iOS
    app in Xcode that includes a watchOS counterpart." 1.4 is an iOS version
    and the watch targets import no StoreKit, so the sentence does not
    describe it. If the Add for Review dialog does not offer iOS 1.4, record
    its message and use the contingency above.
- **Screenshots:** the watch needs its own set (Apple Watch, one size is
  enough; 416 × 496 from a 46mm simulator is an accepted size), and every
  in-app iPhone and iPad shot is still stale since the tab bar. Candidate sets
  from a seeded scratch simulator are in `Claude outputs/1.4-screenshots/` in
  the main checkout, with a README saying what each shows and how it was
  made. Nothing there is uploaded.
  - **Upload from `app-store-upload/`, not the folders beside it.** Apple's
    specification says "Images can't include alpha channels or
    transparencies". The simulator screenshots taken for 1.4 (`simctl io …
    screenshot`) were all RGBA PNGs, although every pixel was opaque. The
    files in `app-store-upload/` are RGB copies with the same pixels, except
    a 4 × 4 simulator speck painted out of the top-left corner of the nine
    `-light` iPhone files, and its README gives a recommended order.
  - **The iPhone set.** Up to 10 files per size. After uploading the 6.9"
    set, delete 1.3's 6.5" set (8 files at 1284 × 2778). Apple uses the 6.5"
    set for the 6.3" and 6.1" iPhones, so if it stays, every iPhone smaller
    than 6.9" goes on showing 1.3's screens. The 1320 × 2868 files cannot be
    scaled to 1284 × 2778 without cropping, because the aspect ratios differ.
  - **The iPad set.** The 13" set is "Required if app runs on iPad". The four
    live iPad shots carry over and meet it, though they are out of date.
  - **The description.** Apple's help for watchOS apps says "Ensure your
    description includes the app's functionality on Apple Watch." Descriptions
    (A) and (B) each name the watch in one clause. A line saying what the watch
    does would need the 1.4.3 review before it is pasted.
- **App Review Information:** paste "Reviewer notes (1.4)" (3,958 bytes,
  under the field's 4,000) and attach the Health card screenshot it names.
  Their closing line said "no third-party code" until 2026-09-26, which was
  false: the app has linked ComponentsKit and AutoLayout through Swift Package
  Manager since 1.0. It now says "no new third-party code", as the 1.2 and 1.3
  notes did. "Sign-in required" stays unchecked, since the app has no
  accounts; check that the contact details carried over from 1.3 are current.
- **The website's addresses.** For 1.4, set the Privacy Policy URL to
  `https://tallyist.co/privacy/`. Apple's help puts that field in the sidebar
  under App privacy (Privacy Policy, Edit), and says "Any changes to the URLs
  releases with your next app version". Then set the Support URL and Marketing
  URL on the version page to `https://tallyist.co/support/` and
  `https://tallyist.co/`. The Marketing URL is not new: the live listing's is
  `https://semmes.github.io/Tallyist/`. Until 1.4 the listing's
  `semmes.github.io` addresses redirect to the same pages, and they go on
  redirecting afterwards. Enforce HTTPS is already on: the owner ticked it on
  2026-09-24 (CLAUDE.md, the bullet "The website's own pages are built…"), and
  `http://tallyist.co/` answers 301 to https.
- **The TestFlight build** (added 2026-09-26):
  - **Which build.** The last code change on the 1.4 train is the tip jar's
    renewal fix (ADR-0012's amendment of 2026-09-26), which the recurring
    tips need now that they go on sale. Submit a build from its merge or
    later; one from earlier (the previous last change was PR #150, merged as
    15a4f9f) lacks it. A manual archive has to come from a checkout pulled to
    it.
  - **Xcode Cloud already archives main.** Its "Archive - iOS" action
    succeeded on 146d92d, 15a4f9f, 9891976 and b8eb04b (2026-09-26: 0 errors,
    32 deprecation warnings), so the private `contract/` submodule does not
    stop it; nothing in the build uses `contract/`.
  - **Xcode version.** The hardware passes from 2026-09-22 on (the four
    Health rows, the watch-to-phone check, ADR-0055's test) ran on Xcode 27.0
    builds, the watch passes of 2026-09-14 to 16 on 26.6, and 1.3 was archived
    with 26.6 against the iOS 26.5 SDK. A manual archive on this Mac uses
    27.0. Xcode Cloud uses the version set in its workflow's Environment,
    which only App Store Connect shows.
  - **Testing.** Internal testing is enough for the pass.
    `ITSAppUsesNonExemptEncryption` is `NO` on the iOS app. Whether that also
    covers the embedded watch app will show at the first upload.
  - **The recurring tips.** TestFlight buys through the sandbox, so once the
    sandbox serves the subscriptions (their metadata complete in App Store
    Connect), Settings → About → Buy me a drink shows both rows with their
    names and prices; subscribe to one to see "Renews" and "Manage or
    cancel". The App Review Screenshot comes from an Xcode Run instead (the
    checklist above). Settings → Diagnostics (test builds) has a "Recurring
    tip" line: which tip, whether it renews or ends, how many reminders the
    system holds and when the next is due, and whether notifications are on.
    TestFlight renews on an accelerated schedule, so there the first reminder
    is already past and the rest are counted a month apart from an expiration
    much nearer than a month; the line shows what the system holds, not what a
    production subscriber would get. The reminder itself can be seen from Xcode instead: Run the
    DrinkTracker scheme on a simulator (the scheme's StoreKit configuration
    applies), subscribe to the monthly tip, and the line shows a reminder a
    week before the renewal at the configuration's default time rate; cancel
    it in Debug → StoreKit → Manage Transactions, then leave the tip jar and
    open it again (a cancellation there makes no transaction, and the app
    re-reads it when the tip jar opens or the app returns to the foreground),
    and it reads "Ends …" with no reminders pending. Cancelling through the tip
    jar's own "Manage or cancel" sheet is re-read when the sheet closes.
  - **Which drinks to judge.** The phone and the watch run Xcode builds, which
    sync to CloudKit Development. The TestFlight build syncs to Production,
    which is a separate database. Judge the pass only on drinks logged after
    the TestFlight build is installed. The TestFlight build opens the same
    local store on each device, so the rows the Xcode builds wrote stay in
    it, including the six test drinks from 2026-09-24. Whether it then
    exports them to Production was not checked. Removing the test drinks
    before the install keeps the readings clean.
- **When 1.5 is live** (this said 1.4 until 2026-10-04), set
  `platform_state: 2` in `semmes/Tallyist`'s `_config.yml` (the site's own
  file, not a mirrored one). The support page then answers the watch question
  with "Yes" and drops "From version 1.5",
  and the home and Apple Watch pages stop saying "Coming soon", which names no
  release and would otherwise stay up.
- **Before submitting,** run one TestFlight build across a phone and a watch
  on one iCloud account: log on each, with each app closed in turn, and on
  the watch from the Smart Stack card's plus. The watch's sync has never run
  on a TestFlight build (Production CloudKit and production push). The What's
  New and the notes promise no timing for this reason. ADR-0055 is merged, so
  that build is also its device check: force-quit the watch app and confirm it
  is not running, tap the card's plus, leave that drink alone for twenty
  minutes, then follow the rest of ADR-0055's "Verification" and note when the
  drink reaches the phone. *(1.4 was submitted on 2026-09-26, and whether this
  pass ran first was not reported. The build in review, 1.4 (1), is the one
  TestFlight has, so the pass can still run on it.)*
