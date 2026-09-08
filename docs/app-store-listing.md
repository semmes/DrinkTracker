# App Store listing — paste-ready metadata

**Status:** 1.0 and 1.1 live; 1.2 submitted 2026-09-03 and awaiting App
Review; 1.3 material ready to paste (reviewed 2026-09-07) · **Owner:** Shawn ·
App Store Connect → App Information / the version page. Everything here has
been through the same 1.4.3 tone review as the app's own copy: factual, no
celebration, no verdicts.

## App Information

| Field | Value |
|---|---|
| Name | **Tallyist** |
| Subtitle (30 chars max) | `Your drinks, tallied.` |
| Primary category | Health & Fitness |
| Privacy Policy URL | `https://semmes.github.io/Tallyist/privacy/` |
| Support URL | `https://semmes.github.io/Tallyist/support/` |
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
- No new permissions, no new privacy label categories, no new third-party
  code. There are still no accounts and no servers of any kind.
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
  the sheet's type control shows five glyph-and-name segments.
- The tip-jar IAPs must be submitted for review with the first version that
  contains them (select all three products on the version page).
