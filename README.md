# Drink Tracker

**Being mindful.**

Native iOS/iPadOS drink tracking app, built from `drink-tracker-design-brief.md` and
`drink-tracker-claude-design-plan.md`.

## Running it

```bash
open DrinkTracker.xcodeproj
```

Xcode resolves ComponentsKit on first open. Then pick a simulator and run. From the
command line:

```bash
xcodebuild -project DrinkTracker.xcodeproj -scheme DrinkTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Before running on a device you need to set `DEVELOPMENT_TEAM`, change
`PRODUCT_BUNDLE_IDENTIFIER` off `com.example.DrinkTracker`, and update the iCloud
container in `DrinkTracker/DrinkTracker.entitlements` to match.

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
  Tests/                      19 tests, all passing
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
   what happens to history when someone changes region. Entries record the region
   they were logged under as provenance, but totals are always computed in the
   *current* region. The alternative — freezing each entry's units — makes totals
   meaningless, since it sums UK units and US standard drinks together. Changing the
   setting re-expresses history; it doesn't alter what was drunk.

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
**worth trying by hand on a real device before debugging further.** After a tap,
check `AppGroup.defaults.string(forKey: Diagnostics.lastWidgetLogKey)`: absent means
the intent never dispatched, `failed: …` means the write itself broke.

## Not built

- **A Settings screen exists now**, but only carries the region setting and Health
  status. There is no way to view or delete individual past entries.
- **The widget offers no size/ABV choice** — one tap logs the type's default. That is
  intentional (it mirrors the sheet's fast path), and corrections happen in the app.
