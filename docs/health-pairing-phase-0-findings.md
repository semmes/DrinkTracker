# Tallyist health pairing — Phase 0 findings

Companion to `docs/tallyist-health-pairing-plan.md` and
`docs/design/health-pairing/README.md`. Research only: no product code was
written to produce any of this.

Everything here was checked on **2026-09-21**, on a Mac with Xcode 27.0 (the
iOS 27.0 SDK) and the iOS 26.5 and 27.0 simulator runtimes. Each answer says
what is true, how it is known, and what it forces. Where a thing could not be
verified it says **unverified**, in those words, because Phase 1 is built on
this page and a confident guess here costs more than an open question.

Four kinds of source appear below, and they are not worth the same:

- **Apple, published.** Developer documentation, the SDK headers on this Mac,
  Apple Support, App Store Connect Help, the App Review Guidelines. Quoted
  verbatim.
- **Observed.** The Health app itself, driven by hand in a simulator and read
  off the screen. True of that build, and the strongest evidence there is for
  what a reader will see beside Tallyist's figure.
- **Apple, unpublished.** Names and one constant read out of the HealthKit
  binary that ships in the simulator runtime. True of that build; not API, not
  a contract, and Apple may change it without saying so.
- **Not Apple.** One developer-forum responder. Quoted, and weighed as one
  person's statement.

---

## The five answers, in one table

| # | Question | Answer | Status |
|---|---|---|---|
| 1 | Which date does Health give a night's sleep? | The date of the morning. 23:40 on the 14th to 07:10 on the 15th is the 15th's sleep. The rule: a sleep day runs 18:00 to 18:00 local time and is named for the date it ends on. A session that crosses 18:00 is kept whole. Everything asleep inside the day is summed, naps included | **Verified on screen** in the Health app (iOS 27.0 simulator, five typed sessions), and it agrees with a constant read from HealthKit's binary (iOS 26.5) and a forum statement. Apple publishes no rule. Not yet checked against real watch data |
| 2 | What does `appleSleepingWristTemperature` return? | An **absolute** wrist temperature in °C, one aggregated sample per night. Health shows it as a change from a baseline Health computes itself after about five nights. That baseline is not in HealthKit | **Verified**, Apple published. How Health computes the baseline is undocumented |
| 3 | What does a year-range `HKStatisticsCollectionQuery` cost on a device? | **Not measured.** It can only be answered by a probe on a real device with real data. None was written | **Open until Phase 2.** The owner decided on 2026-09-21 to measure it there, on a timing line in Settings' Diagnostics |
| 4 | Is Health data on an iPad that was never paired to the watch? | Yes, by Apple's account. iPadOS 17 and later has its own HealthKit store and HealthKit syncs it, given the same Apple Account with Health syncing on | **Verified** as documented. **Unverified** on hardware, type by type |
| 5 | Do these reads change App Store Connect's questionnaires? | No new form and no changed answer, provided the feature stays what the plan says it is. One questionnaire already applies to this app because of its category | **Verified** against Apple's published pages. What App Store Connect shows this account is the owner's to look at |

Beyond the five, the research turned up **four things the plan does not know**,
each of which changes a later phase. They have their own section near the end,
"What the plan does not know".

---

## 1. Which date the Health app gives a night's sleep

### What Apple publishes: nothing

No Apple page states the rule. Checked, and silent on it:

- `HKCategoryTypeIdentifier.sleepAnalysis` and `HKCategoryValueSleepAnalysis`
  in the developer documentation, and `HKCategoryValues.h` in the iOS 27.0
  SDK. They describe the values and that samples overlap. Nothing about days.
- Apple Support, "Track your sleep on Apple Watch and use Sleep on iPhone"
  (support.apple.com/en-us/108906, published 2026-09-14) and the iPhone User
  Guide's "View your sleep history in Health on iPhone" (the iOS 27 page).
- There is no public HealthKit API for a sleep day. `HKStatisticsCollectionQuery`
  does not apply: "You can only use statistics collection queries with quantity
  samples."

The nearest thing to a published hint is in the Support article, about the
Sleep Score: "Every morning after you wake up, you'll receive a Sleep Score
rating from 0-100. This is based on your previous night's sleep."

Developers have asked Apple exactly this question on the forums ("all we want
is total sleep for a given day and that the date for the sleep is the same as
Apple Health displays", thread 725166, Feb 2023) and were not told the rule.

### What the Health app does, seen on screen

With nothing published, the rule was read off the Health app itself: a
throwaway iOS 27.0 simulator (iPhone 17, runtime 24A434, US Eastern time),
the Health app's own Browse, Sleep, Add Data form, five "Asleep" entries typed
by hand, and the Sleep chart read back after each one. No code was written, and
the simulator was deleted afterwards. Four of the screenshots are in
`docs/health-pairing-phase-0-evidence/`.

Before any data went in, the day view already showed the shape of the answer:
the chart headed "Sep 21, 2026" runs its time axis **6 PM, 12 AM, 6 AM, 12 PM**.
A day in Sleep starts at 6 PM the evening before.

| # | Typed in | Where Health put it | What it settles |
|---|---|---|---|
| 1 | Mon Sep 14, 11:40 PM to Tue Sep 15, 7:10 AM | Under **Tue** in the week headed "Sep 13–19, 2026", which is the 15th. Entry 4's callout names the date | The plan's own example. A night belongs to the date of its morning |
| 2 | Fri Sep 18, 8:00 PM to 11:00 PM, the same evening | Under **Sat**. The callout reads "Asleep 3 hr, Sep 19, 2026" | The boundary is 6 PM, not midnight. Neither the start's calendar date nor the end's would give Saturday |
| 3 | Wed Sep 16, 4:00 PM to 8:00 PM, two hours each side of 6 PM | Whole, under **Thu**, drawn from 4 PM to 8 PM. Nothing under Wed | A session that crosses 6 PM is **not split**. It goes to one day |
| 4 | Tue Sep 15, 2:00 PM to 3:30 PM, a nap | Under **Tue**, beside the night from entry 1. The callout reads "Asleep 9 hr, Sep 15, 2026" | **Naps are summed in.** 7 h 30 m and 1 h 30 m make the 9 hours |
| 5 | Sun Sep 13, 1:00 PM to 7:00 PM, five hours before 6 PM and one after | Whole, under **Sun** | With entry 3: a crossing session is filed by where its middle lies. An even split goes to the later day |

The week's "Avg. Time Asleep" read 7 h 30 m after entry 1, 5 h 15 m after
entry 2, 4 h 50 m after entry 3, 5 h 20 m after entry 4 and 5 h 30 m after
entry 5. Those are 7.5 ÷ 1, 10.5 ÷ 2, 14.5 ÷ 3, 16 ÷ 3 and 22 ÷ 4: every figure
confirms the filing above, and the divisor is the number of **days that have
data**, not seven.

What this did not cover: every entry was a single hand-typed "Asleep" sample. A
night from a watch is an in-bed sample and many stage samples, from a source
Health ranks against others. See "Still unverified" below.

### What HealthKit's own code says: 18:00, named for the morning

The HealthKit framework has an internal notion of a **sleep day**, and the
public SDK's link stub lists its names. In
`HealthKit.framework/HealthKit.tbd` of the iOS 27.0 SDK:
`_kHKSleepDayBoundaryHour`, `HKSleepDaySummary`, `HKSleepDaySummaryQuery`,
`morningIndex`, `morningIndexRange`.

The iOS 26.5 simulator runtime (build 23F77) ships HealthKit as a standalone
binary, so the constant can be read:

    nm -arch arm64 -m …/HealthKit.framework/HealthKit | grep SleepDayBoundary
    00000000004e7038 (__TEXT,__const) external _kHKSleepDayBoundaryHour

The eight bytes at that address are `12 00 00 00 00 00 00 00`: the integer
**18**. The same binary carries the selectors
`hk_sleepDayStartForMorningIndex:calendar:`,
`hk_sleepDayEndForMorningIndex:calendar:`,
`hk_sleepDayIntervalForMorningIndex:calendar:`,
`hk_dateIntervalByMappingToSleepDayWithMorningIndex:calendar:`,
`bedtimeDateIntervalForMorningIndex:calendar:` and
`wakeDateComponentsForMorningIndex:calendar:`.

So inside HealthKit a sleep day is an interval with a start and an end, its
boundary hour is 18, and it is identified by the index of its **morning**.

The iOS 27.0 runtime keeps its frameworks only in a shared cache, so the value
could not be read there; the 27.0 SDK still exports the symbol. The two halves
cover each other: the constant was read on 26.5, and the 6 PM behaviour was
watched on 27.0.

### What one forum responder says

Apple Developer Forums, thread 745369, "HKCategoryValueSleepAnalysis Sending
incorrect sleep data", January 2024, from the responder `jcafaro`: "You're just
fetching the last 24 hours but the dates in the Health app are based from
6pm-6pm." The same responder in thread 706334, May 2022: "instead of bucketing
by a midnight to midnight day, bucket by a 6pm - 6pm bounded day." The page
does not mark the responder as Apple staff, so this is weighed as one
developer's statement. It agrees with the screen and with the binary.

### The answer

A session starting 23:40 on the 14th and ending 07:10 on the 15th appears in
Health under **the 15th**. The rule, as observed:

1. A sleep day runs from 18:00 to 18:00, local time, and carries the date it
   ends on, which is the date of the morning inside it.
2. A session is filed whole, under the sleep day that holds its middle. It is
   never clipped at 18:00.
3. A day's Time Asleep is everything asleep that was filed under it, naps
   included.
4. An average over a span divides by the days that have data.

### Still unverified, and how each gets settled

| Open point | Why it matters | How to settle it |
|---|---|---|
| A real night from a watch, not a typed sample | A watch writes an in-bed sample and many stage samples. Whether Health files each sample, or the assembled period, by its middle cannot be told apart with single samples, and only matters for a night that crosses 18:00 | Tier 4, which the plan already lists: Tallyist's figure for a night against the Health app's, on the owner's phone |
| Which samples count when two sources overlap | Health ranks sources ("the data source at the top will take priority over others", support.apple.com/en-us/108779). A plain sum of overlapping samples over-counts, which is also the first thing the forum responder asks about in thread 745369 | Tier 4, on a phone with a second sleep source. Phase 4 has to merge overlaps whatever Health does |
| What happens after a time zone change | Apple recommends `HKMetadataKeyTimeZone` on sleep samples "for best results when analyzing sleep samples". Whether Health maps a night by the sample's zone or the phone's current one is unknown | Tier 4, after travel. Until then Phase 1's time zone vectors pin Tallyist's rule, not Health's |
| iOS 26 on screen | The screen was watched on 27.0 and the constant read on 26.5; neither was done on both | Repeat entry 2 on the 26.5 simulator. Ten minutes |

### What it forces

1. **Health's sleep day is the key, and it is named for the morning.** For the
   night that follows the evening of day N, Health's date is N+1, and what
   belongs to it is every session whose middle falls between 18:00 on N and
   18:00 on N+1, local time. Phase 1's `DrinkingNight` needs that interval on
   its sleep side whatever it chooses for drinks.
2. **The plan's main-session rule is a divergence from Health.** The plan
   wants "the main sleep session whose start falls in that window, not every
   nap in it". Health's figure for a night includes the next afternoon's nap. The
   plan's own third rule in "A drinking night is not a calendar day" says to
   match Health or document the divergence loudly, and the design's tier 4
   acceptance check is that the two figures agree. So Phase 1 either sums
   everything in the sleep day, as Health does, or keeps main-session-only and
   says so in the source note. It cannot do the second quietly. This is a Phase
   4 behaviour, but it is a Phase 1 signature: a night's sleep is a set of
   sessions, not one.
3. **The drink window is a separate decision, and the plan's two candidates
   both have an edge.** The window has to give every drink to exactly one night
   and every night to exactly one Health sleep day. 18:00 to 06:00 leaves a
   drink at 14:00 belonging to no night. Noon to noon gives a drink at 11:00 to
   the night whose sleep has already ended. Phase 1 states one and defends it,
   as the plan says; this page supplies only the interval it has to line up
   with.
4. **Health's average is over days with data.** Tallyist's two figures are
   averages over nights that have a value, which is the same convention. A
   night with no sleep recorded is absent from the count, never a zero.
5. **No date is ever printed.** The design shows two averages and two night
   counts, never a night's date, so Tallyist naming a night for its evening
   while Health names it for its morning cannot surface as a disagreement. What
   can surface is membership: which sessions went into the figure. That is the
   thing to match.
6. **`now` has a job.** See the resting heart rate note below: the newest day's
   figure is provisional, and the domain is where a night gets held back until
   its figure has settled.

### The design's open question: which day's resting heart rate pairs with which night

The design README leaves this to Phase 0. What Apple publishes
(`HKQuantityTypeIdentifier.restingHeartRate`):

> "It is an estimation of the user's lowest heart rate during periods of rest
> … the system estimates the resting heart rate by analyzing sedentary heart
> rate samples throughout the day. Because the resting heart rate estimates
> become more accurate as the day progresses, the system may delete earlier
> samples and replace them with better estimates. Apple Watch replaces only
> the samples written by the watch for the current or previous day."

The SDK header marks the type `count/min, Discrete (Temporally Weighted)`.

So resting heart rate is a figure for a **calendar day**, built up across that
day. It is not a nightly figure, which is why the design retitled the card
"Your averages". The plan's "no night-boundary problem" is too strong: the
type has no boundary of its own, but the pairing still has to pick a day.

Two candidates, for Phase 1 to choose between and defend:

- **The day after.** The evening of N pairs with the resting heart rate of
  N+1. That is the same date Health gives the night's sleep, so one key serves
  every metric in the table.
- **The same day.** The evening of N pairs with the resting heart rate of N,
  most of which was measured before the first drink.

Two facts the choice has to live with. The figure for today and for yesterday
can still be rewritten by the watch, so a night whose health day is not yet
complete is provisional. And a community write-up of Health exports notes that
after travel a day can hold two resting heart rate samples and the next none
("because of time zone issues, you can end up with two on one day and none on
another"); a daily statistics bucket absorbs the first case and leaves the
second as a night with no data.

**Unverified:** the start and end dates the watch puts on a resting heart rate
sample. No Apple page says. The owner can read it off their own phone: Health,
Browse, Heart, Resting Heart Rate, Show All Data, tap a row.

---

## 2. What `appleSleepingWristTemperature` returns

### What is true

From Apple's documentation for the type, verbatim:

> "A supported watch measures temperature from both sensors every five seconds
> overnight during sleep. The watch then aggregates this data to a single
> `appleSleepingWristTemperature` sample. It corrects this sample for
> environmental bias and calculates a single value that represents the wrist
> temperature over the entire night."

> "Apple Watch records the absolute wrist temperature value; however, Health
> displays this data as a relative value, based on a person's baseline. Health
> needs to calculate this baseline, so it won't display the wrist temperature
> until it has gathered about five nights of data. However, Apple Watch records
> `appleSleepingWristTemperature` samples starting with the first night, and
> you can read them immediately from the HealthKit store."

> "These samples are read-only. You can request permission to read the samples
> using this identifier, but you can't request authorization to share them."

And from the iOS 27.0 SDK, `HKTypeIdentifiers.h`: `// degC, Discrete
(Arithmetic)`, available from iOS 16.0.

| | |
|---|---|
| Value | Absolute wrist temperature. Not a deviation |
| Unit | Degrees Celsius. Any temperature unit converts |
| Cadence | One sample per night. The five-second sensor readings are not in HealthKit |
| Baseline | Computed by the Health app, after about five nights. Not exposed: no HealthKit header in the 27.0 SDK mentions a baseline for it |
| To get a sample at all | Apple's page: "ensure Sleep Focus is on and that someone is wearing Apple Watch while sleeping". Apple Support (102674, published 2026-09-14): "Sleep Focus must be enabled for at least 4 hours a night for about 5 nights" for the baseline |
| Hardware | Apple Support: "Apple Watch Series 8 or later, any model of Apple Watch Ultra, or Apple Watch SE 3" |

**Unverified:** how Health computes its baseline (the window, mean or median,
how it treats a new watch beyond "it takes about 5 nights to re-establish").
Apple does not say.

### What it forces

1. **Tallyist cannot show Health's number.** Health's deviation is measured
   from a baseline only Health has. Whatever Phase 6 shows will differ from the
   figure in the Health app for the same night, so the label has to say what
   the figure is. The design's temperature note already does.
2. **A deviation converts to Fahrenheit by scale alone.** An absolute
   temperature converts with the offset (×9/5, +32); a difference converts
   without it (×9/5). Running a deviation through `Measurement` or `HKUnit` as
   though it were a temperature adds 32 degrees to it. Convert the absolute
   values first and subtract after, or scale the difference by hand, and pin it
   with a tier 1 vector.
3. **A baseline taken from the same nights ties the two signs together.** If
   every night's deviation is measured from the median of all the nights in
   range, the two column averages, weighted by their night counts, add up to
   the gap between that range's mean and its median, which is close to zero.
   So unless the columns barely differ they land on opposite sides of zero, by
   construction. "+0.21" beside "−0.08" then states the direction of the
   difference between the columns, which is the thing rule 1 says the app
   never signs. The design already gives the sign its own line in the copy
   review; this is the arithmetic behind that caution. HealthKit stores the
   absolute value, and two absolute figures side by side are the idiom of
   every other row ("62 bpm", "58 bpm"). Phase 6 decides; its ADR should argue
   this rather than inherit the median.
4. **The hardware list in the plan is short by one.** The plan says Series 8
   and later. Apple now lists the SE 3 as well. It changes nothing in code,
   since an unsupported watch is the no-data state, but the Settings caption
   and any reviewer note should not name models.

---

## 3. What a year of `HKStatisticsCollectionQuery` costs

**Not measured, and not estimated.** The question asks for a measurement on a
real device for each of the three quantity types. That takes an app with the
HealthKit entitlement, run on a phone that holds a year of real watch data,
with its owner tapping the permission sheet. It is a probe, and the Phase 0
brief says to stop and ask rather than write one.

What can be said without measuring, all from Apple's pages, and none of it a
cost:

- Apple publishes nothing about the query's cost.
- The documented cadences bound what a year holds. Resting heart rate is a
  daily estimate. Wrist temperature is one sample per night. For heart rate
  variability Apple says only "The system automatically records samples on
  Apple Watch"; how many a day is **unverified**.
- Sleep is not a statistics query at all. It is category samples, one for each
  stretch of each stage plus the in-bed sample, read with a sample query and
  assembled by hand. How many that is a night is **unverified**, and its cost
  is a separate measurement, for Phase 4.
- A collection query's buckets are anchored wherever the anchor date puts them.
  Anchored at 18:00, a one-day interval is exactly Health's sleep day, which is
  the shape the nightly types want. Anchored at midnight it is the calendar
  day, which is the shape resting heart rate wants.

### Decided: measure it inside Phase 2

Decided by the owner, 2026-09-21: **the second of the two ways below.** Phase 2
puts the read layer's query time on a line in Settings' Diagnostics, and the
number is read off the owner's phone as a tier 4 item on that pull request.
What Phase 2 owes this page in return: the measured time for a year range,
added to this section, and a plain statement if the cost turns out to argue
against reading on every render.

Two limits on that line, so it does not become the thing the plan forbids:

- **It carries a duration and the range it covers, and nothing else.** Not a
  sample count and not a count of days with data: either is a fact derived from
  Health, and the Diagnostics breadcrumbs live in the App Group's defaults,
  which is exactly where nothing read from Health may be written.
- **It measures what the build reads.** Phase 2 adds resting heart rate alone,
  so that is the type it can time. Sleep, heart rate variability and wrist
  temperature are timed on the same line by the phases that add their reads.

The two ways that were on the table, kept for the record. Neither blocks
Phase 1, which is pure domain and imports no HealthKit.

- **A throwaway probe now.** A single-view app in a scratch directory outside
  the repository, signed with the owner's team, run once on the owner's iPhone.
  It requests the three read types, runs each year-range daily collection query
  several times cold and warm, and prints the wall time and the bucket count.
  Nothing from it is committed except the numbers, added to this page.
- **Measure inside Phase 2.** The read layer's query time, a duration and never
  a health value, goes on a line in Settings' Diagnostics section, which
  TestFlight builds already show and App Store builds do not, and the
  measurement becomes a tier 4 item on Phase 2's pull request.

The second is less work and measures the code that will ship. The first keeps
the promise that the answer comes before the build. Either way the number is
the owner's phone's to give.

---

## 4. Health data on an iPad that never met the watch

### What is true

Apple's documentation, `isHealthDataAvailable()`:

> "By default, HealthKit data is available on iOS, watchOS, and visionOS.
> HealthKit data is also available to iPads running iPadOS 17 or later … The
> HealthKit framework is available on devices running iPadOS 16 and earlier
> and macOS 13 and later, but your app can't read or write HealthKit data.
> Calls to `isHealthDataAvailable()` return `false`."

"About the HealthKit framework", under "Syncing data between devices":

> "iPhone, Apple Watch, and visionOS each have their own HealthKit store.
> iPadOS 17 and later also has its own HealthKit store. … HealthKit
> automatically syncs data between these devices."

Apple Support, iPad User Guide, "Back up your Health data in iCloud on iPad":

> "If you sign in with your Apple Account, your health and fitness information
> in the Health app is stored automatically in iCloud."

> "For your Health app data to sync across devices, make sure your devices are
> signed in to the same Apple Account, are connected to the internet, and are
> updated to the latest OS version."

The switch is Settings, the account name, iCloud, Health, "Sync with iPad".
The iPad guide's introduction says the Health app there "securely stores your
health information from iPhone, iPad, and Apple Watch".

Tallyist's floor is iOS 26.0, its device family is `1,2`, and it sets no
`UIRequiredDeviceCapabilities`, so by Apple's account every iPad it installs
on has a HealthKit store, and `HealthKitService`'s existing
`isHealthDataAvailable()` guard passes there.

So: an iPad on the same Apple Account, with Health syncing on, holds the
watch's data although it was never paired to the watch. With syncing off, or
on a different account, it holds none, and that is the no-data state.

### Unverified

- That each of the four types actually arrives on an iPad, and how far behind
  the phone it runs. Apple's statement is general. One look at the Health app
  on an iPad settles it.
- That permission is asked again on the iPad. Each device has its own HealthKit
  store; whether an answer given on the phone carries over is not stated.

### What it forces

1. **The plan's expectation is out of date.** It says the feature "may show
   nothing" on an iPad. In the ordinary case it will show the table. Absence
   stays the correct behaviour where syncing is off; it is no longer the
   expected one.
2. **Three strings in the design are wrong on an iPad.** The source note, the
   Settings footnote and the offer's body all say "on this iPhone". Phase 3
   needs a wording that is true on both, and it goes through the copy review
   like the rest.
3. **Everything that is per device is per device twice.** The offer's answered
   flag and the switches live in device-local settings, so an iPad makes its
   own offer once. That is consistent with a permission sheet that is also per
   device, and the design's acceptance check about iCloud sync should be read
   that way.

---

## 5. App Store Connect's questionnaires

### What is true

**App Privacy stays Data Not Collected.** Apple's App Privacy Details page:

> "'Collect' refers to transmitting data off the device in a way that allows
> you and/or your third-party partners to access it for a period longer than
> what is necessary to service the transmitted request in real time."

> "Data that is processed only on device is not 'collected' and does not need
> to be disclosed in your answers."

The page's Health data type names the HealthKit API explicitly, so the moment a
health value left the device the answer would change. Read, compute, render,
discard keeps it true.

**The age rating questionnaire has two health questions, and neither answer
changes.** App Store Connect Help, "Age ratings values and definitions":

> "Medical or Treatment Information: Content that provides diagnoses or
> guidance around the management of medical conditions or health and wellness."

> "Health or Wellness Topics: Content that provides self-care or lifestyle
> recommendations. May include: calorie tracking, dieting advice, or exercise
> recommendations."

The feature shows two averages of the reader's own data and gives no diagnosis,
guidance or recommendation, which is what the plan's four rules exist to
guarantee. On the rating itself these answers should not matter either:
CLAUDE.md records the app at 17+, the top of the older scale, which a frequent
alcohol answer alone produces (18+ on OS 26 and later), and neither health
answer rates higher than that. "Seen in passing", below, is why that sentence
says "should".

**The regulated medical device declaration already applies, and its answer
stays No.** App Store Connect Help, "Declare regulated medical device status":
apps available in the EU, UK or US must declare if they "have a primary or
secondary category of Health & Fitness or Medical", or answered "frequent" to
Medical or Treatment Information. `docs/app-store-listing.md` records the
primary category as Health & Fitness, so the declaration is required whether or
not this feature ships. The page describes such devices as apps "used for a
range of medical purposes, including diagnosis, prevention, monitoring, and
treatment of diseases and physiological conditions". The word to keep away from
in every string and reviewer note is *monitoring*.

**The App Review Guidelines add one rule the plan argues only from cost.**

> 5.1.3 (ii) "Apps must not write false or inaccurate data into HealthKit or
> any other medical research or health management apps, and may not store
> personal health information in iCloud."

The plan's decision 5 keeps Health values out of CloudKit because of what it
would cost. It is also a guideline. ADR "health context is read, never stored"
should cite it.

> 5.1.3 (i) "You must disclose the specific health data that you are
> collecting from the device."

> 2.5.1 "Apps should use APIs and frameworks for their intended purposes and
> indicate that integration in their app description. … HealthKit should be
> used for health and fitness purposes and integrate with the Health app."

And from HealthKit's "Protecting user privacy": the use must be "clear in both
your marketing text and your user interface", and a privacy policy is required.
So Phase 7 names the types in the policy, as the plan already says, and adds
the reads to the listing description, which the plan does not mention.

### Unverified

What App Store Connect shows this account at submission. Only the owner can
see it: App Information, then App Store Regulations & Permits.

### Seen in passing

`docs/app-store-listing.md` says the alcohol answer "Infrequent/Mild … lands
the app at 17+". Apple's table for devices before OS 26 puts infrequent or mild
alcohol references at 12+ and frequent or intense at 17+; for OS 26 and later,
infrequent is 13+ and frequent is 18+. CLAUDE.md records the app as 17+, so the
note and the rating disagree about which answer was given. A record to correct
after a look at App Store Connect, not a behaviour.

---

## What the plan does not know

### 1. A person can now grant a window of recent data instead of all of it

Apple's "Authorizing access to health data", as it read on 2026-09-21:

> "After people review data type access, a second screen prompts them to choose
> how much historical data to grant your app, either a recent limited window or
> their full history."

> "HealthKit intentionally prevents your app from distinguishing between full
> access and denied access to specific types; both cases return no entry in the
> result dictionary. Limited authorization is the only authorization state your
> app can positively identify."

The API is `earliestAuthorizedSampleDate(for:)`, marked iOS 27.0 in
`HKHealthStore.h`: "Types without a limited-access earliest date are silently
omitted from the result." The article puts no version on the second screen, so
that it is new with iOS 27 is an inference from the API's availability, and
whether iOS 26 ever shows it is **unverified**.

What it forces:

- **The span in the source line can be wrong.** "From Apple Health, last 13
  weeks" is only true if the app may read 13 weeks. With a shorter window the
  health side covers less than the range the drink side covers. The honest
  repair is to clamp the health side's start to the authorized date and name
  the span actually covered, or to show no row when the window is shorter than
  the range. Phase 2 reads the date; Phase 1's comparison type has to be able
  to carry a span that differs from the range.
- **It does not break the invisible-denial rule.** The app still cannot tell
  denied from empty. A limited window is something the person chose and the
  system tells the app about on purpose.
- **It reaches the existing import too.** ADR-0025's one-time re-walk reads
  "all Health history" for alcohol samples; under a limited window it reads
  less. Outside this feature. Noted so it is not found by surprise.

### 2. There is a second heart rate variability type

The iOS 27.0 SDK adds `HKQuantityTypeIdentifierHeartRateVariabilityRMSSD` beside
the SDNN type the plan names. Apple's page for it is empty as of 2026-09-21.
Apple Support (120277, published 2026-09-14) describes a "Recovery HRV" on Apple
Watch Series 12 and Ultra 4: "HRV is sampled while you're still, so the number
of measurements you see will vary according to your activity level."

**Unverified:** whether Recovery HRV is the RMSSD type, whether those watches
still write SDNN, and which of the two the Health app charts. Phase 5 has to
answer that before it picks a type, because a Tallyist figure in milliseconds
that is not the one on the person's wrist fails the same test as a sleep figure
that disagrees with Health.

### 3. CI cannot compile an iOS 27 symbol yet

CI's last run on `main` (2026-09-19) selected Xcode 26.6 with the iOS 26.5 SDK;
this Mac has Xcode 27.0. `earliestAuthorizedSampleDate(for:)` and the RMSSD
identifier do not exist in the 26.5 SDK, so code that names them fails to
compile in CI whatever `#available` says. Phase 2 either waits for the runner
image, or puts a compile-time check that stands in for the SDK beside the
`#available` one (Xcode 27.0 is Swift 6.4, so `#if compiler(>=6.4)`), and says
in its pull request that CI proved only the older half.

### 4. The resting heart rate figure moves after it is written

Quoted under question 1: the watch replaces the current and previous day's
samples as its estimate improves. Two consequences. No cache is a matter of
being right, not only of being tidy, since a stored value would go stale by
design. And the two newest nights are provisional, which is a reason for Phase
1 to hold a night back until its health day is complete, with `now` injected to
decide it.

---

## Where this disagrees with the plan, the design or the prompts

| Where | What it says | What was found |
|---|---|---|
| Plan, "ADRs" | Reserves 0046 to 0049 | 0046 and 0047 are taken. The next free number is **0048**, as the design README already says |
| Plan, "A drinking night is not a calendar day" | "The main sleep session whose start falls in that window, not every nap in it" | Health sums every session in its 18:00 to 18:00 day, naps included, and files a session by its middle, not its start. Matching Health and main-session-only are different figures; the plan's own rule says to pick one out loud |
| Plan, the same section | "A noon-to-noon or 18:00-to-06:00 convention are both defensible" | Those are drink windows. Health's sleep day is neither: it is 18:00 to 18:00, named for the morning |
| Plan, resting heart rate | "No aggregation to invent, no night-boundary problem" | One figure a day, yes. But it is a calendar-day figure, revised for two days, and which day pairs with which night is a real decision |
| Plan, "Two consequences to design around" | On an iPad "the feature may show nothing" | iPadOS 17 and later has its own HealthKit store and syncs. It will usually show the table |
| Design, three strings | "on this iPhone" | Wrong on an iPad, where the feature renders |
| Plan, wrist temperature | "Series 8 and later" | Apple now lists the SE 3 too |
| Plan, heart rate variability | `heartRateVariabilitySDNN` | A second type, RMSSD, arrived with iOS 27 |
| Plan, "The ask" | One sheet "covering only what has not been asked before" | The SDK header confirms there is no prompt when every type is already answered. That a partial sheet lists only the new types is **unverified** here and is already on the plan's tier 4 list. The sheet now also has a second screen, for the history window |
| Plan, decision 5 | Not storing Health values is argued from cost | It is also App Review guideline 5.1.3 (ii) |
| Prompts, Phase 0 | Committing the design folder "releases the sync LaunchAgent" | No agent is installed (`scripts/verify-watch-setup.py`: "Sync agent: not installed"), and the main clone sat three pull requests behind `origin/main` (#109 to #111) when this was written. `scripts/sync-main.sh` run by hand pauses on any untracked file, and two others remain in the main clone: `Claude outputs/` and `docs/health-pairing-prompts.md` |

---

## Sources

Observed, 2026-09-21: the Health app on a throwaway iOS 27.0 simulator (iPhone
17, runtime 24A434), five sessions typed into Browse, Sleep, Add Data, the
Sleep chart's day and week views read back after each. Screenshots in
`docs/health-pairing-phase-0-evidence/`:

- `1-day-view-axis-runs-6pm-to-6pm.png`, the empty day view for Sep 21
- `2-fri-8pm-to-11pm-is-dated-sep-19.png`, entry 2's callout
- `3-mon-night-plus-tue-nap-is-9hr-dated-sep-15.png`, entries 1 and 4 together
- `4-sessions-crossing-6pm-stay-whole.png`, all five, with entries 3 and 5
  whole under Thu and Sun

Apple developer documentation, read as the pages' own JSON on 2026-09-21:

- developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/applesleepingwristtemperature
- developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate
- developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn
- developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd
- developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/sleepanalysis
- developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis
- developer.apple.com/documentation/healthkit/hkhealthstore/ishealthdataavailable()
- developer.apple.com/documentation/healthkit/about-the-healthkit-framework
- developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- developer.apple.com/documentation/healthkit/protecting-user-privacy
- developer.apple.com/documentation/healthkit/hkstatisticscollectionquery

The iOS 27.0 SDK in Xcode 27.0, `HealthKit.framework`: `HKTypeIdentifiers.h`,
`HKCategoryValues.h`, `HKHealthStore.h`, `HKDefines.h`, `HealthKit.tbd`. The
iOS 26.5 simulator runtime (23F77), `HealthKit.framework/HealthKit`.

Apple Support, each published 2026-09-14 unless it is a user guide page:

- support.apple.com/en-us/102674, wrist temperature
- support.apple.com/en-us/108906, tracking sleep
- support.apple.com/en-us/108779, managing Health data
- support.apple.com/en-us/120277, heart rate
- support.apple.com/guide/iphone/view-your-sleep-history-iph72b370881/ios
- support.apple.com/guide/ipad/back-up-your-health-data-ipad50c1fd42/ipados
- support.apple.com/guide/ipad/intro-to-health-data-ipadb253ebdd/ipados

App Store:

- developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/
- developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/
- developer.apple.com/app-store/app-privacy-details/
- developer.apple.com/app-store/review/guidelines/

Not Apple:

- developer.apple.com/forums/thread/745369, /thread/706334, /thread/725166
- r-bloggers.com/2020/02/apple-health-export-part-i/, for the time zone note
  on resting heart rate
