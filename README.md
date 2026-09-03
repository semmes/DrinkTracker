# Drink Tracker

**Being mindful.**

Native iOS/iPadOS drink tracking app.

**Working on this?** Read [`docs/PRD.md`](docs/PRD.md) first — it holds the invariants
any change has to respect, what counts as verified, and the roadmap. Settled decisions
live in [`docs/decisions/`](docs/decisions/), and the visual language in
[`docs/design-system.md`](docs/design-system.md). This README covers building,
running, and current status.

## Running it

```bash
open DrinkTracker.xcodeproj
```

Xcode resolves ComponentsKit on first open. Then pick a simulator and run. From the
command line:

```bash
xcodebuild -project DrinkTracker.xcodeproj -scheme DrinkTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Keeping a clone in step with main

Changes land on `main` continuously. To pick them up without watching for a
notification:

```bash
./scripts/sync-main.sh            # check once, fast-forward if behind
./scripts/sync-main.sh --watch    # keep checking, ctrl-C to stop
./scripts/install-sync-agent.sh   # run it via launchd, no terminal needed
```

**It refuses more often than it acts, on purpose.** It will not touch anything if
you have uncommitted work, if you are on a branch other than `main`, or if the
update isn't a clean fast-forward — it says why and exits quietly. A watcher that
can eat your changes is worse than no watcher, and one that shouts every minute
gets turned off.

macOS notifications say what landed. When the update touches `project.pbxproj`,
`Package.resolved`, or a scheme, it says so explicitly:

> **Xcode caches the project file.** If those change while the project is open,
> Xcode can keep showing the old target list, and the next build is against stale
> structure. Close and reopen the project when the notification mentions it.

Pulling is not building. Every sync still needs ⌘R to reach the device, and a
widget change needs the widget removed and re-added — iOS caches extensions
aggressively enough to give a convincing false negative.

## Naming

Three names, currently not all the same:

| Where | Value |
|---|---|
| App Store listing | **Tallyist** |
| Home screen icon | **Tallyist** (`INFOPLIST_KEY_CFBundleDisplayName`) |
| Bundle identifier | `com.shawnsemmes.DrinkTracker` |
| Repository, targets, types | `DrinkTracker` |

"DrinkTracker" was unavailable on App Store Connect, so the **listing** was renamed
to Tallyist. That is deliberately the only thing that changed.

**The bundle identifier was not touched, and shouldn't be casually.** `AppGroup.identifier`
is computed from the running bundle (invariant 4), so changing it moves the App Group
and the iCloud container — the app would open a new, empty store and the existing log
would appear to vanish. It isn't deleted, it's just somewhere the app no longer looks.
Any future bundle rename needs a migration, or an explicit decision to abandon what's
there.

The home screen label now matches the listing. The bundle identifier and codebase
deliberately do not — see below — so the icon says Tallyist while the internals stay
`DrinkTracker`. The app icon is a generated placeholder (white tally marks on the
ramp's dark blue, `scripts/make-app-icon.py`); replace `AppIcon.png` when a real one
exists.

## Signing and provisioning

Everything derives from two values in [`Config/Signing.xcconfig`](Config/Signing.xcconfig).
Both targets read it, so the bundle identifiers, the App Group, and the iCloud
container cannot drift apart.

```
DEVELOPMENT_TEAM  = TN2VF665NJ       # 10-character Team ID (not a secret)
BUNDLE_ID_PREFIX  = com.shawnsemmes  # a domain you control
```

Both are filled in, so a device build needs nothing beyond an Apple ID signed into
Xcode. Fork this and you'll want your own `DEVELOPMENT_TEAM`.

Derived automatically:

| | |
|---|---|
| App | `$(BUNDLE_ID_PREFIX).DrinkTracker` |
| Widget | `$(BUNDLE_ID_PREFIX).DrinkTracker.Widget` |
| App Group | `group.$(BUNDLE_ID_PREFIX).DrinkTracker` |
| iCloud container | `iCloud.$(BUNDLE_ID_PREFIX).DrinkTracker` |

`AppGroup.identifier` is computed from the running bundle rather than hardcoded, so
a Swift literal can't fall out of step with the entitlement — a mismatch wouldn't
fail the build, it would silently give the app and the widget separate stores.

**Simulator needs nothing.** It doesn't require signing at all — verified: the App
Group container is created and the SwiftData store lands inside it.

**For a device you need a paid Apple Developer Program membership** ($99/yr; the free
tier does not grant App Groups or iCloud). Then:

1. Xcode → Settings → Accounts → add your Apple ID.
2. Team ID is already set in `Config/Signing.xcconfig`.
3. Select the **DrinkTracker** target → Signing & Capabilities → confirm your team is
   picked and "Automatically manage signing" is on. Repeat for
   **DrinkTrackerWidgetExtension**.
4. Build to the device. Automatic signing registers both App IDs, the App Group, and
   the iCloud container for you.

If step 4 reports the App Group can't be created, register it once by hand at
[developer.apple.com](https://developer.apple.com/account) → Identifiers → App Groups,
using exactly the name in the table above, then rebuild.

## Design systems installed

| Package | Version | How | Used for |
|---|---|---|---|
| [ComponentsKit](https://github.com/componentskit/ComponentsKit) | 1.7.1 (up-to-next-major) | SPM, remote | `SUButton`, `SUCard`, `SUSlider`, `SUSegmentedControl` |
| AutoLayout | 1.x | transitive dep of ComponentsKit | — |
| SwiftUI / Swift Charts / SwiftData / HealthKit | system | — | UI, trend charts, storage, Health sync |

ComponentsKit is themed once in `DrinkTracker/DesignSystem/AppTheme.swift` so it sits
inside Apple's material system rather than introducing a second visual language:
accent pinned to system blue, shadows pulled back because Liquid Glass surfaces carry
their own depth. Its stock container radii (16/20/26) already match iOS 26 continuous
corners, so those are left alone.

`GlassTokens.swift` holds spacing, radii, and type roles. It deliberately defines **no
colors** — everything uses system semantic colors so the app inherits Liquid Glass's
automatic light/dark and vibrancy behaviour. Verified in both appearances.

### Where each system is used

The plan's Open Question #1 asked how widely to use ComponentsKit. Current split:

- **ComponentsKit** — buttons everywhere, the ABV slider, and all trend-screen cards.
  No progress bars: `SUProgressBar` was removed from the rest-day card because a bar
  that fills implies a target, and this app doesn't set them. See
  [the copy review](docs/copy-review-1.4.3.md).
- **Native SwiftUI** — size pills (bespoke per the brief), the sheet itself, and the
  quick-add row, which uses `GlassEffectContainer` so the four buttons merge as one
  glass mass the way Apple's own controls do.
- **Swift Charts** — `BarMark` plus a dashed `RuleMark` for the average. Deliberately
  inside the mark set Swift Charts renders well natively; no radial or multi-axis
  charts, per the plan.

The drink-detail sheet uses a native `.sheet` with `.presentationDetents` rather than
ComponentsKit's `SUBottomModal`, so it gets real system detents, drag-to-dismiss, and
accessibility behaviour for free.

## Layout

```
DrinkTracker.xcodeproj      two targets: the app and the widget extension
DrinkTrackerCore/           Swift package — pure domain logic, no UI, no persistence
  Sources/                    Region, DrinkType, StandardDrink, LoggedDrink,
                              DrinkDraft, TrendSummary, DayIntensity,
                              CalendarGrid, RecentSummary, SessionPace,
                              PopulationReference (+ bundled JSON), LogExport,
                              DisplayStrings (+ the package's string catalog)
  Tests/                      150 tests, all passing
Shared/                     compiled into BOTH targets
                              AppGroup, AppSettings, DrinkEntry + AlcoholFreeDay
                              (SwiftData), SchemaVersions, DrinkRepository,
                              LogDrinkIntent (all four intents)
DrinkTrackerTests/          xctest bundle — 52 tests, the SwiftData layer in-memory
DrinkTracker/               App target
  DesignSystem/               AppTheme, GlassTokens, FlowLayout, CountStepper,
                              IntensityPalette, AppearancePreference
  Persistence/                DrinkStore (HealthKit-aware wrapper)
  Services/                   HealthKitService, DrinkTrackerShortcuts, TipJar,
                              CloudKitStatusProbe
  Features/                   Onboarding, Today, DrinkDetail, Calendar, Trends,
                              Settings
DrinkTrackerWidget/         Widget extension target
```

`Shared/` sits outside both file-system-synchronized groups and is added to each
target's compile phase explicitly. That's deliberate: a synchronized folder belongs
to exactly one target, so shared sources have to live outside them.

### App Group

The app and widget share `group.com.shawnsemmes.DrinkTracker` — both the SwiftData store
and `AppSettings`. **Both targets must open the store with identical configuration.**
A CloudKit-mirrored store opened without CloudKit still *reads* fine but silently
fails to *write*, which is why `SharedModelContainer.make()` takes no options.

The domain layer is a separate package on purpose: SwiftData's `@Model` macro only
expands inside Xcode, so keeping the math in plain value types makes it testable
without a simulator. `DrinkEntry` is a thin SwiftData shell that maps to and from
`LoggedDrink`.

```bash
cd DrinkTrackerCore && swift test
```

The SwiftData layer is tested separately, because `@Model` only expands inside Xcode:

```bash
xcodebuild test -project DrinkTracker.xcodeproj -scheme DrinkTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DrinkTrackerTests
```

Both run on every pull request — see [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

### Two CI systems, one job each

| | |
|---|---|
| **GitHub Actions** | Domain tests, simulator build, integration tests — every pull request |
| **Xcode Cloud** | Archive, sign, and upload to TestFlight |

Verification stays on Actions because it is fast and costs nothing; distribution
moved to Xcode Cloud because it authenticates from the Apple ID already in Xcode, so
**no signing secrets live in this repository.** See
[ADR-0008](docs/decisions/0008-two-ci-systems-with-one-job-each.md).

If Xcode Cloud's source-control step asks for access to the **componentskit**
organisation, skip it. That is a third party nobody here can authorise, and it is not
needed: both packages are public, and the Actions build resolves them on every run
with no credentials. Only `semmes/DrinkTracker` has to show a checkmark.

**Build numbers** are stamped by [`ci_scripts/ci_post_clone.sh`](ci_scripts/ci_post_clone.sh):
the repo pins every target at build 1 for reproducible local builds, and Xcode Cloud
overwrites that with its own always-increasing `CI_BUILD_NUMBER` before archiving —
TestFlight refuses any build number it has already seen. Local and Actions builds
never run the script and stay at 1.

`ITSAppUsesNonExemptEncryption` is declared `NO` in the app target, so TestFlight
builds skip the per-build export-compliance question. That answer is load-bearing:
the app ships no encryption beyond Apple's own frameworks (HTTPS, CloudKit,
HealthKit). If that ever changes, remove the key and answer honestly in App Store
Connect.

## Known spec discrepancies

Three places where the brief contradicts itself. Two are now settled decisions with
records; the remaining one is implemented **as literally written**, with tests
pinning the behaviour so nothing is silently "corrected".

1. **~~Spirit and Other defaults don't hit 1.0 standard drinks.~~** *Settled.* The
   one-drink invariant is real, and Spirit now defaults to the 1.5 oz shot — 0.6 fl
   oz of ethanol at 40%, the US definition exactly. Other stays at 8 oz @ 10% as a
   deliberate exception: it has no presets and no typical serving to anchor to, so
   its default seeds the Custom field rather than describing a real drink. See
   [ADR-0005](docs/decisions/0005-spirit-defaults-to-the-1_5-oz-shot.md).

2. **The UK figures don't describe the same quantity.** The brief says "0.28 fl oz /
   8g". 8 g of ethanol is ~0.343 US fl oz, not 0.28 — and 0.28 fl oz is ~6.5 g. The
   published UK unit is 8 g, so the code derives from grams and ignores 0.28.

3. **Region is a display lens, not a property of the drink.** The brief doesn't say
   what happens to history when someone changes region. Totals are always computed in
   the *current* region — see
   [ADR-0002](docs/decisions/0002-region-is-a-display-lens.md).

## Notes

- **Deployment target is iOS 26.0, not 27.** The newest SDK on this machine is iOS
  26.5, and ComponentsKit gates its `BackgroundStyle.liquidGlass` at iOS 26.0. Liquid
  Glass is the iOS 26 design language, so everything the brief asks for is available.
  If you move to an iOS 27 SDK, bumping `IPHONEOS_DEPLOYMENT_TARGET` is the only change.
- **Swift language mode is 5.** The compiler is Swift 6.3; bumping to language mode 6
  is likely to surface strict-concurrency work in ComponentsKit, not in this code.
- **No account creation anywhere**, per the brief. Identity is the user's existing
  iCloud account via SwiftData + CloudKit. If iCloud is unavailable the app falls back
  to a local store rather than blocking.
- **HealthKit failures are silent by design.** The log lives in SwiftData, so denied or
  unavailable Health degrades the app to local-only rather than blocking a log.
- **Tone guardrails** are respected: no streaks, no goals, no congratulation or warning.
  The chart's average line is labelled "Your average", never a target, and the rest-day
  card counts days without framing them as wins.

## The widget's one-tap logging — resolved

**Verified working on a device (2026-08).** The fault was never dispatch or
registration: `LogDrinkIntent.drinkType` was a non-optional `@Parameter` with no
default, and a parameter the system cannot resolve is one it wants to *ask* about —
which Shortcuts can do and a home-screen widget cannot. The tap was abandoned during
parameter resolution, before `perform()` was entered: no crash, no log, identical at
every widget size. `default: .beer` made resolution infallible, and the button's own
value still wins when it arrives.

The diagnostic scaffolding that found it stays: **Settings → Diagnostics** (Debug and
TestFlight builds) shows the App Group status, store mode, iCloud sync state, which
process last built an intent, and what the last tap did. The full protocol lives in
[`docs/device-test-widget-dispatch.md`](docs/device-test-widget-dispatch.md).

## Count-first logging

Today leads with a single counter that **is** the day's log: plus records a drink
the moment it's tapped, minus removes the most recent one (undoable, same as a
swipe-delete), and standard drinks appear as a caption underneath. One tap per
drink, no confirm step. On an empty day, "Record no alcohol today" makes the zero
explicit — and deleting your last drink deliberately does *not* auto-mark the day,
because removing an entry says nothing about abstinence.

By default a counted drink is one standard drink with no type stated — the region's
own definition, exactly 1.0 in every region — and the type, size, and strength can
be added afterwards or left out (ADR-0023). Describing a drink makes ＋ repeat *it*
for the rest of that day, "Record a standard drink instead" is the way back, and
each day starts over. Settings → "What the counter logs" restores the older rule:
the type you log most often, at the size and strength you last logged it
(`DrinkDraft.quickCount` — the same rule the calendar's day sheet and the widget
use, shared code). Every entry is a real, individually editable drink with its own
HealthKit sample, per ADR-0003.

**The typed path didn't go anywhere.** "Log by type — size and strength" discloses
the beer/wine/spirit/other row and the repeat control, and the preference persists,
so granular users set their Today once. See
[ADR-0009](docs/decisions/0009-count-first-logging.md).

A drink saved onto a day marked alcohol-free clears the marker — evidence beats
assertion, enforced in `DrinkRepository.saveOrThrow` so the app, calendar, and
widget all agree.

## Logging several of the same drink

Called **repeat logging**, never "party mode" — a settled decision, not a placeholder.
Read [ADR-0001](docs/decisions/0001-repeat-logging-is-not-party-mode.md) before
touching any of this copy.

- **The counter.** Repeated taps on Today's ＋ are the primary way to log several —
  each tap is its own entry.
- **One-tap repeat.** Under "Log by type", a row reading "Another beer · 12oz · 5%"
  logs an identical drink at the current time. A *new entry*, not an edit.
- **Backfilling a count.** The calendar's day sheet carries the same live counter
  as Today: plus logs a drink dated that day, minus removes the day's most recent
  (undoable) — see [ADR-0013](docs/decisions/0013-the-day-sheet-counter-is-the-days-log.md).

The drink sheet itself no longer carries a "How many" stepper — the counter made it
a second way to do the same thing, and removing it clears the sheet for size and
strength, which are its actual job.

However it is said, several drinks save as **N separate entries**, never one entry
with a count — see
[ADR-0003](docs/decisions/0003-quantity-saves-separate-entries.md).

## Correcting the log

Logging is one tap from the widget and two from the app, so logging the wrong thing
is easy — correcting it has to be just as easy.

- **Today** lists what you've logged today under the metric. Swipe left to remove,
  swipe right or tap to edit.
- **History** (the list icon) shows every day, grouped, with the day's total in each
  header. Same swipe actions.
- **Removing is undoable** for 10 seconds via a bar at the bottom. Undo re-saves the
  same entry by id, so it returns to its original position and time rather than
  appearing as a new drink at the current time. It also rewrites the HealthKit
  sample the deletion retired.
- **Adding a forgotten drink**: the `+` in History opens the sheet with a drink-type
  picker and a date/time control, so it lands where it actually happened.

The quick-add path is deliberately untouched by this: no type picker, no time
control, still two taps. The extra controls appear only when editing an existing
entry or adding one retroactively — the cases where "now" is the wrong answer.

## Siri, Shortcuts, and hands-free logging

Four App Shortcuts, so the log is reachable without touching the screen —
which is also the accessibility path for anyone who can't
([ADR-0019](docs/decisions/0019-siri-logging-splits-instant-from-conversational.md)):

- **"Log a beer in Tallyist"** — instant, at the type's defaults. Same entry a
  widget tap makes.
- **"Log a drink in Tallyist"** — typeless, seeded like Today's counter.
- **"Log drinks in Tallyist"** — conversational: Siri asks which drink and how
  many; size and strength can ride along from a configured shortcut.
- **"Record no alcohol in Tallyist"** — marks today, and says so.

The split between the first and third is load-bearing. `LogDrinkIntent` (the
widget's) must never have a parameter the system could prompt for — a widget
can't answer, and the tap is abandoned before `perform()` ever runs, which is
exactly the failure that once broke one-tap logging. Its new size/ABV/quantity
parameters are optional or defaulted for that reason. `LogDrinksIntent` is the
opposite by design: no defaults, so Siri asks. Voice-supplied values get the
app's own bounds (`DrinkDraft.forIntent`, tier-1 tested) — ABV clamps to the
type's range, quantity to the counter's 12, and N drinks are N separate
entries, never a count on one. Every reply states what was written; Siri never
speaks unprompted, and no notification exists on any of these paths.

## Session pace

Off by default, in Settings. While a sitting is active — a drink logged
within the last 4 hours — Today shows a card with three flat facts: drinks
this session, when it started, time since the last. A fourth line, the
rolling two-hour count, appears at 3 or more, styled with weight only. The
card reports pace because pace, not time-since-last, is the variable that
matters: a since-last stopwatch reads calmest exactly when a run is fastest.
It never runs outside a session (that would be a streak), persists nothing
about gaps, and sends no notifications — settled law in
[ADR-0017](docs/decisions/0017-session-pace-reports-a-window-not-a-streak.md).
Sessions are runs of absolute timestamps (`SessionPace` in the core package,
clock injected, tier-1 tested), so midnight and DST can't split them, and a
backdated entry can't resurrect one.

## The population reference

Trends carries one comparison line once four weeks of history exist: the
user's 4-week average against the Alcohol Research Group's **2020 National
Alcohol Survey** distribution of weekly drinks — "That's lower than roughly
30% of US adults who drink." A bundled JSON in the core package, no network
call ever; the comparison runs in grams so the regional unit setting can't
skew it; the renormalization to adults-who-drink is stated in the file, the
UI note, and pinned row-by-row in tier-1 tests. Source and year are always
visible. No thresholds, no guidelines, no other users — see
[ADR-0018](docs/decisions/0018-population-reference-is-a-bundled-statistic.md).

## Calendar and year view

The chart on Trends answers *how much*. The calendar answers *which days*.
Trends spans four ranges: rolling 7- and 30-day windows with daily bars, and
calendar-bucketed **Quarter** (last 13 weeks, weekly bars) and **Year** (last
12 months, monthly bars) — the trailing week/month is partial, "so far", like
the current month in the year calendar. The dashed average line matches the
bars' scale (per day, per week, per month) and, on bucketed charts, averages
*completed* periods only, so it never sags just because a new week started.
Totals are always expressed in the current region, a year of history included
(invariant 3). Same three stats everywhere; still no deltas, no targets.

- **Month view** — every day shaded by how much was logged. Tap any past day to
  record it. Future days are dimmed and inert; a calendar you can scroll forward
  into invites logging drinks that haven't happened.
- **Year view** — twelve months at once. Cells are 11pt, far below a touch target,
  so nothing there is tappable: it is a reading surface, and days are edited in the
  month view.
- **Summary window** — the card under the month grid covers the last 30 days by
  default, or the month shown (whole when past, through today when current)
  via the picker above it; the year view carries the same four figures for the
  year shown. Future days are never counted as unlogged, the window's day count
  sits beside its title, and an average over no drinking days prints "—".
  Same figures, no delta between windows
  ([ADR-0006](docs/decisions/0006-a-summary-not-a-score.md),
  [ADR-0026](docs/decisions/0026-the-calendar-summary-covers-the-window-you-choose.md)).
- **Recording a past day** is a count, not a size and a strength. Reconstructing
  exact volumes days later is guesswork, and demanding precision someone doesn't
  have produces worse data than accepting the number they do remember. It seeds
  type, size, and ABV from what you usually log, and every entry it creates stays
  individually editable.
- **The day sheet's counter is the day's log** — the same live ± as Today: plus
  records a seeded drink dated that day the moment it's tapped, minus removes the
  day's most recent entry (undoable). An empty day's "Record no alcohol" button
  makes the zero an explicit statement, same as Today
  ([ADR-0013](docs/decisions/0013-the-day-sheet-counter-is-the-days-log.md)).
- **Filling several days at once** — touch and hold a day, then drag across a run
  of days; an action bar offers one answer for all of them — **Mark no drinks** in
  one tap, or **Log drinks…** for a counted answer through the bulk sheet. Days
  that already have a record are never touched by a bulk fill (the selection wash
  itself shows which days will be written); the per-day sheet remains both the way
  to change a recorded day and the VoiceOver path
  ([ADR-0011](docs/decisions/0011-bulk-fill-never-touches-a-recorded-day.md)).

### Sharing a month or a year

The calendar's share button renders the visible month, and the year view's
renders the visible year, as an image — the period's name, where the record
stops ("Through September 2") and how many days it covers, the calendar's
four figures (days with drinks, days with none, total, average on days with
drinks) with unlogged days named, the grid (twelve mini grids for a year),
the five-entry legend, a small wordmark — through the system share sheet
([ADR-0027](docs/decisions/0027-the-calendar-shares-a-month-or-a-year-as-its-own-figures.md)).
Every figure is one the calendar already shows for that period, from the
same function; the old per-week average is gone. One-way and user-initiated every time: the PNG is built at
share time from raw data (no temp file, nothing persisted, nothing recorded
about whether or where it went), renders in the app's current appearance,
and carries no identifying metadata (orientation, resolution, and pixel
dimensions only — verified by chunk inspection). No comparison to anyone.

### Alcohol-free days are recorded, not inferred

`AlcoholFreeDay` is a separate model because **"no entries" and "no alcohol" are
different facts**. Every day before the app was installed has no entries; treating
that as abstinence would have the year view claim a history that never happened. So
the calendar has five states, not four, and blank means *no record* — the year view
says so in as many words, and prints how many of its days are actually accounted
for.

The repository refuses to mark a day that already has drinks. Keeping a dormant
contradictory marker would be worse than refusing: it would reassert itself the
moment those entries were removed, claiming abstinence the user never stated.

The person recording can also be the user in *another* app
([ADR-0025](docs/decisions/0025-a-health-zero-is-a-recorded-no-alcohol-day.md)):
a `numberOfAlcoholicBeverages` sample with a value of zero is that app's way
of recording the same fact, and it mirrors here as a marker carrying the
sample's id — read-only ("From Apple Health", no remove control), removed when
the sample is, cleared by a logged drink like any marker. A day with no Health
record stays blank; nothing is inferred.

### The colour ramp

`IntensityPalette` is the only place in the app that defines literal colours,
with one named companion, `ShareCardInk` — the ground and inks of an exported
image, which has no host surface to inherit from (ADR-0027) —, and
[`GlassTokens`](DrinkTracker/DesignSystem/GlassTokens.swift) still defines none. The
exception is narrow and deliberate: in a heatmap the colour *is* the data, and data
has to be specified rather than inherited from the system.

A green→yellow→orange→red ramp — the obvious choice, and what comparable apps use —
is wrong twice over. Under protanopia and deuteranopia those hues collapse toward
the same yellow-brown, and they sit at similar lightness so nothing survives to
separate them; the worst pair in it is *no alcohol* against *1–2 drinks*, which is
the distinction the calendar most needs to carry. It also delivers a verdict, which
the tone rules and `QuickLogWidget` both rule out.

A single blue hue stepped light→dark fixes both. Lightness survives every form of
colour vision deficiency **and** greyscale, and darker reads as *more*, not *worse*.

| | 1–2 | 3–5 | 6+ |
|---|---|---|---|
| Light | `#86b6ef` | `#2a78d6` | `#0d366b` |
| Dark | `#184f95` | `#3987e5` | `#9ec5f4` |

Both modes pass monotone lightness, adjacent ΔL ≥ 0.06, light-end contrast ≥ 2:1,
and single-hue checks. Dark is stepped independently against the dark surface rather
than inverted, because an inverted ramp falls outside the band at both ends.
**Re-validate these values if you change them; don't eyeball them.**

Alcohol-free is deliberately *not* a step in that ramp — palest blue would read as
"a small amount of drinking" rather than "none". It gets a neutral fill plus an
outline, so it stays separable from both neighbours with no colour at all.

## Exporting the log

Settings → Export log hands the whole record to the system share sheet as one
CSV — the answer to "show this to my doctor"
([ADR-0015](docs/decisions/0015-export-is-a-csv-of-the-log.md)). Chronological,
three row shapes in one timeline: drinks logged here (with volume and ABV),
drinks imported from Apple Health (count only — nothing invented, per
[ADR-0014](docs/decisions/0014-health-import-is-count-based-and-read-only.md)),
and days recorded as alcohol-free. Totals are expressed in the *current* region
with a per-row `unit` column naming it; volume and ABV ride along so the math
can be rechecked. The file is rendered by `LogExport` in `DrinkTrackerCore`, so
its exact shape is pinned by tier-1 tests; generation happens at share time,
off the main actor, and nothing leaves the device unless the user picks a
destination.

## Privacy

`PrivacyInfo.xcprivacy` ships in **both** targets — Apple evaluates each bundle
separately, and the app's manifest does not cover the widget's appex.

Both declare no tracking and an empty `NSPrivacyCollectedDataTypes`. The drink log is
health data, but it leaves the device only through the user's own private CloudKit
database and their own HealthKit store: there is no account system, no server, and no
networking code in the app at all. Both declare `NSPrivacyAccessedAPICategoryUserDefaults`
with reason `CA92.1` — the App Group case — which is `AppGroup.defaults`.

**If a backend is ever added, `NSPrivacyCollectedDataTypes` stops being empty** and the
App Store nutrition labels change with it.

Every user-visible string has been reviewed against App Store guideline 1.4.3 — see
[`docs/copy-review-1.4.3.md`](docs/copy-review-1.4.3.md), which records what was
changed and what was checked and left alone.

### The privacy policy

[`docs/privacy-policy.md`](docs/privacy-policy.md) is the canonical policy. It is
published from the separate public repository `semmes/Tallyist`, and that URL —
not a file in this repository — is what App Store Connect points to (ADR-0024):

    https://semmes.github.io/Tallyist/privacy/

The same text ships natively in the app (`PrivacyPolicyView`, Settings → About →
Privacy Policy) because guideline 5.1.1 wants the policy accessible *inside* the
app too, and a native screen works offline and respects Dynamic Type. **All three
copies change together** — the canonical file here, `PrivacyPolicyView`, and the
published copy in `semmes/Tallyist` — and a policy edit that touches only some of
them is a bug.

## The tip jar

Settings → **Buy me a drink**: a $4.99 consumable at quantity 1–10 (Apple's
per-transaction cap, stated in the UI) and two auto-renewing subscriptions
(monthly / yearly), all through In-App Purchase — guideline 3.1.1 rules out
Apple Pay for digital tips, and the StoreKit sheet is the same one-confirm
experience anyway. Tips unlock nothing; a local notification reminds the user a
week before each renewal so cancelling first is always realistic. Design
reasoning and the 1.4.3 review of the metaphor: [ADR-0012](docs/decisions/0012-the-tip-jar.md),
[copy review](docs/copy-review-1.4.3.md).

**Simulator testing works today**: `DrinkTracker.storekit` is wired into the
shared scheme, so purchases run against the local StoreKit test environment
with no App Store Connect setup. **Real devices and TestFlight need App Store
Connect**: sign the Paid Applications agreement (banking + tax under
Agreements), then create the three products with exactly the IDs in ADR-0012's
table. The code reads prices from StoreKit, so price changes in App Store
Connect need no code change.

Because the subscriptions auto-renew, guideline 3.1.2(a) applies: the app links
Apple's standard EULA ("Terms of Use") and the privacy policy beside the
subscription controls and in Settings → About, and the App Store description
must state each subscription's title, duration, and price alongside the same
two links — paste-ready metadata lives in
[`docs/app-store-listing.md`](docs/app-store-listing.md).

## Localization

**The app is not localized yet, but the catalogs are populated.** Four string
catalogs (app, widget, the core package's own, and `AppShortcuts.xcstrings`) hold
304 keys, kept in exact agreement with extraction by running
`xcrun xcstringstool sync <Catalog>.xcstrings --stringsdata …` against a clean
build's `.stringsdata` files — a command-line build emits those but never writes
back into a catalog; only the Xcode GUI does. Language choice and translation are
deferred by decision.

Plural forms are declared per region (`Region.unitNamePlural`, `unitName(for:)`)
rather than built by appending `"s"`, which six call sites used to do. That isn't
localization; it means a catalog has one place to replace instead of six.

[`docs/localization-status.md`](docs/localization-status.md) lists what remains and
the order to do it in — interpolated sentences and `== 1` ternaries both need the
catalog populated first.

## Health works in both directions

Tallyist writes its entries to Apple Health, and — since
[ADR-0014](docs/decisions/0014-health-import-is-count-based-and-read-only.md) —
reads back what *other* apps recorded there, so a switcher's history appears
automatically. External samples carry only a count and a time, so imported
entries are **count-based** (one beverage = one drink, in every region — no
invented volume or strength) and **read-only** (HealthKit forbids deleting
another app's samples, so a Tallyist-side edit could never propagate; change
the drink where it was logged and the mirror follows, deletions included).
The sync is an anchored query on the foreground sweep, deduped by sample UUID,
with the app's own samples filtered out by source so backfill and import can
never echo into each other. Zero-valued samples are the other app's no-alcohol
days and mirror as markers on the same terms
([ADR-0025](docs/decisions/0025-a-health-zero-is-a-recorded-no-alcohol-day.md));
the anchor carries a generation, so an install that walked past zeros under
1.1's reading walks history once more and picks them up.

The one door out of read-only is **adoption**
([ADR-0016](docs/decisions/0016-adoption-turns-an-import-into-a-typed-entry.md)):
tap or swipe a single-count import in History ("Add details") and type in the
real type, size, and strength. The entry is rewritten in place — same
identity, same timestamp, same external sample id — and joins the standard-
drink math under the region lens. Health is never touched: the external
sample stays the Health record, the kept sample id blocks both re-import
duplication and a backfill echo, and source-deletion sync stops applying
because the entry now carries facts the user stated. Multi-count imports
("3 drinks") stay read-only — splitting them has no honest Health story yet
(the ADR says why, and how to reopen).

## Not built

- **The widget offers no size/ABV choice** — one tap logs the type's default. That is
  intentional (it mirrors the sheet's fast path), and corrections happen in the app.
- **No bulk edit.** Entries are managed one at a time. (Export shipped —
  see "Exporting the log".)
- **No score.** A single figure summarising 30 days is a target, and the cheapest way
  to protect a target is to stop logging. See
  [ADR-0006](docs/decisions/0006-a-summary-not-a-score.md).
- **No social or sharing features.** Not requested, and comparison is a verdict by
  another route.
