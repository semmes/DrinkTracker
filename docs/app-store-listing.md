# App Store listing — paste-ready metadata

**Status:** draft for first submission · **Owner:** Shawn · App Store Connect →
App Information / the version page. Everything here has been through the same
1.4.3 tone review as the app's own copy: factual, no celebration, no verdicts.

## App Information

| Field | Value |
|---|---|
| Name | **Tallyist** |
| Subtitle (30 chars max) | `Your drinks, tallied.` |
| Primary category | Health & Fitness |
| Privacy Policy URL | `https://github.com/semmes/DrinkTracker/blob/main/docs/privacy-policy.md` |
| Support URL | `https://github.com/semmes/DrinkTracker/blob/main/docs/support.md` |
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
Privacy Policy: https://github.com/semmes/DrinkTracker/blob/main/docs/privacy-policy.md
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
Appearance: choose Light, Dark, or System in Settings.

Trends now reach further — Quarter and Year views — and can show a
published population reference: your weekly average beside a 2020
national survey of US adults who drink, computed on your device from a
bundled statistic. Nothing about your log leaves your phone.

Session pace, off by default: while you're logging, Today can show how
many drinks this sitting, when it started, and how long since the last.
Turn it on in Settings.

Export your whole log as a CSV from Settings, and share any month as an
image from the calendar.

Also: a drink imported from Apple Health can take details — tap it and
add the type, size, and strength.
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
- The CSV export and the month share image are user-initiated, one-way
  exports of the user's own data through the system share sheet, with no
  identifiers in the files.
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
  are part of the tone. For 1.2, existing screenshots remain valid;
  optionally refresh Trends (the four-range picker) or add a dark-mode
  shot now that appearance is a setting.
- The tip-jar IAPs must be submitted for review with the first version that
  contains them (select all three products on the version page).
