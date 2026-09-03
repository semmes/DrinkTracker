# Tallyist 1.2 Implementation Spec

Hand this to Claude Code. Each feature section is self-contained, so you can paste one at a time and implement them in separate sessions. Read "Project constraints" and "App Review consistency" first, in every session. They govern every decision below.

Target: iOS 26, SwiftUI + SwiftData + CloudKit private database, ComponentsKit for UI controls.

---

## Project constraints

These are not preferences. They are claims Tallyist made to Apple in the 1.0 App Review response, and every feature in this build has been shaped to keep them true.

1. **No accounts.** No sign-in, no identity, no friend graph.
2. **No servers and no external services.** Apple frameworks only. No network calls added in this build.
3. **No goals, streaks, scores, or advice.** The app measures. It does not coach, rank, congratulate, or warn.
4. **No user data shared between users.** Nothing leaves the user's own private iCloud database.
5. **No consumption guidelines.** The app gives no medical advice, no diagnosis, no recommended limits.

**Copy rule for everything new: report, never instruct.**

Good: "Last drink 47 min ago."
Bad: "You've gone 47 minutes without a drink." "Consider slowing down." "Nice work."

The first states a fact. The second two set a target and pass judgment, which is the thing this app deliberately does not do.

**Default rule:** every new behavioral surface ships optional and off, or neutral.

---

## Feature A: Appearance setting (Light / Dark / System)

Lowest risk, fully independent. Build this first.

### Model

```swift
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    var label: String {
        switch self {
        case .system: "System"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }
}
```

Storage: `@AppStorage("appearancePreference")` in the app target's standard `UserDefaults`. Do **not** put this in an App Group. The widget is intentionally excluded (see below).

### Application point

Apply once, at the root scene. Do not scatter `.preferredColorScheme` across individual views.

```swift
@main
struct TallyistApp: App {
    @AppStorage("appearancePreference")
    private var appearanceRaw = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(
                    AppearancePreference(rawValue: appearanceRaw)?.colorScheme
                )
        }
    }
}
```

Sheets and full screen covers presented from inside this hierarchy inherit the override. Any presentation that creates a separate window scene does not, so check those if any exist.

### Settings UI

A picker in the existing Settings screen, labeled "Appearance", placed above the standard drink setting. Segmented or inline list, your call. Three options in the order System, Light, Dark.

### The actual work: color audit

This is roughly 80% of the effort on this feature. Grep for hardcoded colors (`Color(red:green:blue:)`, hex initializers, `.white`, `.black`) and move each one into an asset catalog Color Set with Any and Dark appearances.

Surfaces to check, in priority order:

1. **Calendar shading by amount.** Highest risk. A light mode ramp that runs pale to saturated inverts badly on a dark background. Author a separate dark ramp rather than reusing the light one. Verify the zero/empty state stays visually distinct from the lightest non-zero step in both schemes.
2. **Trends charts.** Swift Charts picks up some semantic colors but not custom ones. Check axis labels, gridlines, the "Your average" reference line, and any area fills.
3. **Widget.** It should keep following the system appearance, which is what users expect and what Apple's guidance points to. Confirm it still reads correctly in both, independent of the app setting.
4. **ComponentsKit controls.** Verify the library resolves `colorScheme` from the environment at render rather than caching a theme at init. If it caches, force a refresh on change. As a last resort, `.id(colorScheme)` on the subtree containing its controls.

Prefer semantic system colors (`.primary`, `.secondary`, `Color(.systemBackground)`, `Color(.secondarySystemGroupedBackground)`) anywhere a custom color is not carrying meaning.

### Known caveats, not bugs

These sheets are system drawn and follow the device appearance, not this setting. Do not try to override them.

- The StoreKit purchase sheet on the tip jar
- The Health permission sheet
- The notification permission alert
- The system share sheet

### Accessibility

- Test with Increase Contrast and Reduce Transparency on, in both schemes.
- Calendar shading must not be the only channel carrying amount. Confirm VoiceOver reads the number, not just the color.
- Text contrast at least 4.5:1 in both schemes.

### Acceptance criteria

- Setting persists across launch
- Changing it updates immediately, no relaunch
- All four surfaces above are legible in both schemes
- Widget appearance is unaffected by the app setting
- No hardcoded colors remain outside the asset catalog

---

## Feature B: Session pace view

This replaces the "stopwatch since last drink" idea. Read the rationale before building, because it determines the shape.

### Why this shape and not a stopwatch

NIAAA defines binge drinking as a pattern that brings blood alcohol concentration to 0.08% or higher, which for adults is "five or more drinks (male), or four or more drinks (female), in about two hours."

The operative variable is **pace**, meaning drinks inside a rolling window. It is not elapsed time since one drink. Those come apart in exactly the case that matters: someone six drinks deep at ten minute intervals sees a stopwatch that keeps resetting to near zero. A stopwatch reads calmest precisely when the pace is fastest. So the primary number is the rolling count, and elapsed time is supporting context.

### Definitions

- **Session**: a run of drinks where each is within `sessionGapThreshold` of the previous one. Default 4 hours.
- **Session start**: timestamp of the first drink in that run.
- **Elapsed since last**: now minus the timestamp of the most recent drink.
- **Rolling two hour count**: number of drinks with timestamps in `[now - 2h, now]`.
- **Session end**: when elapsed since last exceeds `sessionGapThreshold`. Nothing is written or recorded. It simply stops displaying.

### Visibility rules

The card appears on the Today screen only when **both** are true:

1. The user enabled it in Settings. Off by default.
2. At least one drink is logged within the last `sessionGapThreshold`.

The card disappears when the session ends.

**Three hard rules. Do not violate these, they are the difference between a measurement tool and a shame mechanic:**

- It never shows a running count of time without a drink outside an active session. An ever increasing "time since last drink" is a streak, and a streak that resets to zero punishes the user at the exact moment they are least able to handle it.
- It never persists or displays a longest gap record. Nothing about gaps goes into SwiftData or UserDefaults.
- It sends no notifications. None. Not in 1.2, not behind a toggle.

### Display

Three values, flat, no judgment:

```
3 drinks this session
Started 9:14 PM
Last drink 47 min ago
```

Optional fourth line, shown **only** when the rolling two hour count is 3 or more:

```
3 in the last 2 hours
```

Style it with slight emphasis (weight or a subtle secondary background). Do **not** escalate color to red or amber, do not add a warning icon, do not add an exclamation. The number is the signal. Urgency styling turns this into a coach, which breaks constraint 3.

### Implementation notes

Live updating text without a timer:

```swift
Text(lastDrinkDate, style: .relative)
```

`Text(_:style:)` with `.relative`, `.timer`, or `.offset` renders and updates itself. Do **not** drive this with a repeating `Timer` publisher, and do not wrap the screen in a one second `TimelineView`. Those wake the app constantly for a value that changes once a minute.

For logic that must actually recompute (the rolling two hour count crossing the display threshold), wrap only that subview:

```swift
TimelineView(.periodic(from: .now, by: 60)) { context in
    // recompute rolling count against context.date
}
```

Put session computation in a pure function over the entry array so it is unit testable and lands in the existing domain logic CI suite:

```swift
struct DrinkSession {
    let start: Date
    let entries: [DrinkEntry]
    var count: Int          // sum of quantities, not entry count
    var lastEntryDate: Date
}

func currentSession(from entries: [DrinkEntry],
                    now: Date,
                    gapThreshold: TimeInterval) -> DrinkSession?

func rollingCount(from entries: [DrinkEntry],
                  now: Date,
                  window: TimeInterval) -> Int
```

Never read `Date()` inside these functions. Inject `now` so tests can drive the clock.

### Settings

One toggle: "Show session pace". Off by default. One line of plain explanation beneath it, something like "Shows how many drinks you've logged in the current sitting." Optionally expose the gap threshold as 3, 4, or 6 hours, but default to 4 and keep it unobtrusive.

### Edge cases, all of which need tests

- **Backdated entries.** A drink added to yesterday from History must not create or resurrect a session now.
- **Edited timestamps.** Changing an entry's time recomputes the session.
- **Deletions.** Deleting the only recent drink hides the card.
- **Quantity based logging.** If the model stores a quantity per entry rather than one row per drink, the session count sums quantities. Logging "3" at once is one entry with count 3, not three sessions.
- **Identical timestamps.** Multiple entries at the same instant must not break ordering.
- **Time zone changes and DST.** Compute from absolute timestamps only. Never from calendar day boundaries.
- **Device clock changes.** A backwards clock jump must not produce a negative elapsed time in the UI.
- **CloudKit sync arriving mid session.** An entry synced from another device must fold into the current session correctly.

### Acceptance criteria

- Card hidden when the feature is off
- Card hidden when no drink in the last 4 hours
- Card appears within one render after logging a drink
- Relative time updates without user interaction and without a repeating timer in the app
- No gap value persisted anywhere
- No notification code paths added
- All edge cases above covered by unit tests

---

## Feature C: Population reference line

This replaces the friends leaderboard. It delivers the part of social comparison that has evidence behind it, with no accounts, no sharing, and no ranking.

### Why this shape

The evidence base for social feedback on drinking is personalized normative feedback, and it works by showing people that they **overestimate** how much their peers drink. It corrects a misperception using anonymous aggregate numbers. A live friend leaderboard does the opposite: it makes real, identified consumption visible, which can normalize whatever the group's actual level happens to be. Norms interventions have documented backfire effects for exactly this reason.

So: an anonymous population reference, computed on device, against a published statistic. No other Tallyist users involved.

### Open dependency, resolve before building

The exact reference statistic needs sourcing and verification first. This is a research task, not a coding task. Do it before writing any UI.

Requirements for the statistic:

- From a citable public source (CDC/NCHS, NIAAA, or SAMHSA/NSDUH are the obvious candidates)
- Has a stated year
- Expressed in, or convertible to, grams of pure ethanol per week
- Describes adults who drink, not all adults, or the comparison is misleading

Two acceptable feature shapes depending on what you can actually source:

- **Shape 1, preferred.** A full percentile distribution of drinks per week. Enables "lower than roughly 60% of US adults who drink."
- **Shape 2, fallback.** A single central tendency (median or mean drinks per week). Enables a second labeled reference line on the Trends chart, sitting alongside the "Your average" line you already have. This is the simpler build and it matches the existing visual pattern.

If neither can be sourced cleanly, cut the feature. Do not estimate a number and present it as a statistic.

### Data file

Bundle it as a static JSON resource. No network call, ever.

```json
{
  "source": "<publisher, report title>",
  "source_url": "<url>",
  "year": 2024,
  "region": "US",
  "population": "adults who reported drinking in the past year",
  "unit": "grams_ethanol_per_week",
  "median": 0,
  "percentiles": [
    { "p": 10, "value": 0 },
    { "p": 25, "value": 0 }
  ]
}
```

**Unit conversion is mandatory.** The user's standard drink setting (US 14 g, UK 8 g, AU 10 g) must be converted to grams of ethanol before comparing against the file, and converted back for display. Skipping this makes the comparison silently wrong for UK and AU users. Cover all three settings in tests.

### Display and copy

Shape 2 (the fallback and simpler build): a second reference line on the existing Trends chart, labeled with the source, rendered visually subordinate to "Your average".

Shape 1: one line of text on the Trends screen.

```
Your average is about 4 drinks a week.
That's lower than roughly 60% of US adults who drink.
Source: <publisher>, <year>.
```

Copy rules:

- "lower than", never "better than"
- No congratulation and no warning in either direction
- The source name and year are visible in the UI, not buried
- A tappable note explains that this is a published population reference, **not** other Tallyist users
- Hide the whole thing until the user has at least 4 weeks of logged data, or the number is noise

### Guardrails

Do not build any of these, now or later in this build:

- Ranking against other Tallyist users
- Opt-in data sharing of any kind
- Any identifier, account, or friend graph
- A comparison against NIAAA heavy drinking thresholds or Dietary Guidelines limits. Those are consumption guidelines, and constraint 5 says the app does not give them. A descriptive population statistic is a fact. A threshold is a recommendation.

### Acceptance criteria

- Zero network calls added, verified by inspection
- Correct under all three standard drink settings
- Hidden below 4 weeks of data
- Source and year visible in the UI
- No new privacy label categories

---

## Feature D: Share card (optional, cut if the build runs long)

One way image export. The user renders their own month and sends it wherever they want through the system share sheet. Nothing is received, nothing is synced, no graph exists.

### Implementation

`ImageRenderer` over a purpose built SwiftUI view, then `ShareLink`. Do not screenshot the live Trends view. Build a dedicated layout sized for Messages.

Content: month name, total, average per week, and the calendar grid. No comparison to anyone. A small wordmark is fine, nothing more.

> **Superseded in part by ADR-0027 (2026-09-03):** the card carries the calendar's own four figures (days with drinks, days with none, total, average on days with drinks) with unlogged days named, and the per-week average was removed — it was not on the in-app calendar, divided by the whole month even mid-month, and is a rate in the unit consumption guidelines are quoted in. A year card shares from the year view on the same terms.

### Rules

- User initiated every single time. No prompts, no "share your month" nudges, no badges.
- No identifier in the image or its metadata.
- The image is generated on demand and not persisted.
- Nothing is logged about whether or where it was shared.

### Acceptance criteria

- Renders correctly in both light and dark appearance
- Legible at Messages thumbnail size
- No file left behind in the container after sharing

---

## App Review consistency

The 1.0 Resolution Center response made four specific claims. This table is the reason each feature above has the shape it does. Verify it still holds before submitting.

| Claim made in 1.0 | Status in 1.2 |
|---|---|
| "no goals, streaks, scores, or advice" | Preserved. The session card reports counts and elapsed time inside a window, sets no target, and keeps no record. The population reference is a neutral descriptive statistic with no encouragement or warning. |
| "No user-generated content is shared between users" | Preserved. Nothing is shared. The share cards (a month or a year) are user initiated one way image exports through the system share sheet, carrying only the user's own grid and the calendar's four figures. |
| "There are no accounts of any kind" | Preserved. |
| "External services, tools, and platforms ... None" | Preserved. The population reference is a bundled static resource. No network calls added. |

### Notes to add to the 1.2 review submission

- The appearance setting is a display preference only.
- The session pace view is optional and off by default. It shows counts and elapsed time within a 4 hour window. It is not a goal, a streak, or a timer to beat, and it sends no notifications.
- The population reference uses a bundled published statistic, named and dated in the app. It is not data from other users. No network request is made.
- The share cards (a month or a year) are user initiated image exports containing only the user's own data and no identifier.
- No new permissions. No new privacy label categories. No new third party code.

### Stop conditions

If implementation starts heading toward any of the following, stop and reconsider rather than building it. Each one breaks a claim above and turns a routine update into a fresh, harder review of an app that just cleared one.

- An account system or any sign-in
- A server, backend, or third party service
- A friend graph or contact import
- Shared or public CloudKit databases
- Push notifications about drinking
- A streak counter or a longest-gap record
- Any ranking against other people
- Comparison against clinical thresholds presented as limits

---

## Build order

1. **Feature A.** Independent, lowest risk, blocks nothing. Ship this first so the color audit is done before new surfaces get added.
2. **Feature B.** The real new value in this build. Depends on A only in that new views should use the audited palette.
3. **Feature C.** Start the source research early since it gates the build. If the statistic does not come together cleanly, cut it without guilt.
4. **Feature D.** Optional. First thing to cut.

Suggested split for Claude Code sessions: one session per feature, pasting Project constraints plus that feature's section.
