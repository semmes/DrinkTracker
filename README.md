# Drink Tracker

**Being mindful.**

Native iOS/iPadOS drink tracking app.

**Working on this?** Read [`docs/PRD.md`](docs/PRD.md) first — it holds the invariants
any change has to respect, what counts as verified, and the roadmap. Settled decisions
live in [`docs/decisions/`](docs/decisions/). This README covers building, running, and
current status.

## Running it

```bash
open DrinkTracker.xcodeproj
```

Xcode resolves ComponentsKit on first open. Then pick a simulator and run. From the
command line:

```bash
xcodebuild -project DrinkTracker.xcodeproj -scheme DrinkTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Signing and provisioning

Everything derives from two values in [`Config/Signing.xcconfig`](Config/Signing.xcconfig).
Both targets read it, so the bundle identifiers, the App Group, and the iCloud
container cannot drift apart.

```
DEVELOPMENT_TEAM  =                  # your 10-character Team ID
BUNDLE_ID_PREFIX  = com.shawnsemmes  # a domain you control
```

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

**Simulator needs nothing.** It doesn't require signing, so `DEVELOPMENT_TEAM` can
stay empty and everything above already works — verified: the App Group container is
created and the SwiftData store lands inside it.

**For a device you need a paid Apple Developer Program membership** ($99/yr; the free
tier does not grant App Groups or iCloud). Then:

1. Xcode → Settings → Accounts → add your Apple ID.
2. Put your Team ID in `Config/Signing.xcconfig`.
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
| [ComponentsKit](https://github.com/componentskit/ComponentsKit) | 1.7.1 (up-to-next-major) | SPM, remote | `SUButton`, `SUCard`, `SUSlider`, `SUProgressBar`, `SUSegmentedControl` |
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

- **ComponentsKit** — buttons everywhere, the ABV slider, and all trend-screen cards
  and progress bars.
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
                              DrinkDraft, TrendSummary
  Tests/                      24 tests, all passing
Shared/                     compiled into BOTH targets
                              AppGroup, AppSettings, DrinkEntry (SwiftData),
                              DrinkRepository, LogDrinkIntent
DrinkTracker/               App target
  DesignSystem/               AppTheme, GlassTokens, FlowLayout
  Persistence/                DrinkStore (HealthKit-aware wrapper)
  Services/                   HealthKitService, DrinkTrackerShortcuts
  Features/                   Onboarding, Today, DrinkDetail, Trends, Settings
DrinkTrackerWidget/         Widget extension target
```

`Shared/` sits outside both file-system-synchronized groups and is added to each
target's compile phase explicitly. That's deliberate: a synchronized folder belongs
to exactly one target, so shared sources have to live outside them.

### App Group

The app and widget share `group.com.example.DrinkTracker` — both the SwiftData store
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

## Known spec discrepancies

Three places where the brief contradicts itself. All are implemented **as literally
written**, with tests pinning the current behaviour so nothing is silently "corrected".
Each is a one-line change if you want it to go the other way.

1. **Spirit and Other defaults don't hit 1.0 standard drinks.** The brief says every
   default size/ABV pair should resolve to "almost exactly 1.0", and calls that
   load-bearing. But its own table gives Spirit `1 oz @ 40%` = **0.67** and Other
   `8 oz @ 10%` = **1.33**. Beer and Wine do land on 1.0. To satisfy the invariant,
   Spirit's default would need to be the 1.5 oz shot (already a listed size option),
   and Other would need 6 oz @ 10% or 8 oz @ 7.5%.

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

## Known issue: the widget's one-tap logging is unverified

The widget builds, installs, registers, appears in the gallery, and **reads** the
shared store correctly — it shows the same live total as the app, in the same units,
which proves the App Group and shared SwiftData store work.

**Tapping its Beer button does not log a drink**, and I could not determine why.
What is established:

- `LogDrinkIntent` is present in the extension's `Metadata.appintents`, so it is
  registered.
- `perform()` is never entered — `Diagnostics.lastWidgetLog` stays absent after a tap,
  and the breadcrumb is the very first line of the method.
- It is not a crash; no crash report is generated.
- An earlier build did reach `appintents:Execution` and produced a runtime-issue
  fault, which is what led to the CloudKit-configuration fix above. Since that fix,
  dispatch stopped happening at all.
- Ruled out: stale widget archive (the widget visibly re-rendered against each new
  build), `.buttonStyle(.plain)` suppressing interaction (removed), and App Group
  availability (defaults and store are both shared correctly).

This may be a limitation of synthetic touch injection against a widget's
out-of-process view hierarchy in the Simulator rather than a defect in the app —
**worth trying by hand on a real device before debugging further.**

### How to diagnose it on a device

**Settings → Diagnostics** (debug builds only) shows the App Group status and what
the widget's intent did last:

| Reading | Meaning |
|---|---|
| `never ran` | The tap never reached the intent. The fault is dispatch, not the write. |
| `entered` / `container-opened` | It started and died partway — the step name says where. |
| `failed: …` | The intent ran and the write threw. The error is shown. |
| `saved` | It worked. |

**Isolate it first with Shortcuts.** The app registers "Log a beer in Drink Tracker"
as an App Shortcut, which runs the *same* `perform()` body in the app's process
rather than the extension's. Run it from the Shortcuts app or by asking Siri:

- **It logs a drink** → the intent and the SwiftData write are fine, and the fault is
  specifically the widget button's dispatch.
- **It fails** → the intent itself is broken, and the widget is a red herring.

This test can't be done in the Simulator: Shortcuts isn't installed there, which is
why it's still outstanding.

## Logging several of the same drink

Called **repeat logging**, never "party mode" — a settled decision, not a placeholder.
Read [ADR-0001](docs/decisions/0001-repeat-logging-is-not-party-mode.md) before
touching any of this copy.

- **One-tap repeat.** Once something is logged today, a row appears under quick-add
  reading "Another beer · 12oz · 5%". One tap logs an identical drink at the current
  time. It's a *new entry*, not an edit, so the original is untouched.
- **Quantity.** The drink sheet has a "How many" stepper (1–12). The live estimate
  and the button both reflect it — "≈ 3 standard drinks", "Log 3 drinks".

Quantity saves **N separate entries**, not one entry with a count — see
[ADR-0003](docs/decisions/0003-quantity-saves-separate-entries.md). Verified: logging
3 wines produced three rows, and removing one took the total from 8.9 to 7.9 while
leaving the other two.

The stepper sits at 1 unless touched, so the two-tap fast path is unaffected. It's
hidden when editing, where fanning one entry into several would be a strange thing
for an edit to do.

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

## Not built

- **The widget offers no size/ABV choice** — one tap logs the type's default. That is
  intentional (it mirrors the sheet's fast path), and corrections happen in the app.
- **No bulk edit or export.** Entries are managed one at a time.
