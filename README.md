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
DrinkTracker.xcodeproj
DrinkTrackerCore/          Swift package — pure domain logic, no UI, no persistence
  Sources/                   Region, DrinkType, StandardDrink, LoggedDrink,
                             DrinkDraft, TrendSummary
  Tests/                     17 tests, all passing
DrinkTracker/             App target
  DesignSystem/              AppTheme, GlassTokens, FlowLayout
  Persistence/               DrinkEntry (SwiftData), DrinkStore
  Services/                  HealthKitService, AppSettings
  Features/                  Onboarding, Today, DrinkDetail, Trends
```

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

3. **Region is stored per-entry.** The brief doesn't say what happens to historical
   totals when someone changes their region. Entries record the region in effect when
   logged, so past numbers don't silently shift.

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

## Not built

- **Home-screen quick-log widget.** Called out in the plan as not-yet-designed; needs
  its own WidgetKit extension target and an App Group so the widget and app share the
  SwiftData store.
- **A Settings screen.** The region setting is captured during onboarding and stored,
  but the brief's "you can set this later" has nowhere to happen yet.
- **UK/Australia unit swap is implemented but unreachable** past onboarding, for the
  same reason.
