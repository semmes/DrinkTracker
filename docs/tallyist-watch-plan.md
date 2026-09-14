# Tallyist on Apple Watch — build plan

Companion to `docs/tallyist-1.2-spec.md` and `docs/tallyist-1.3-spec.md`. Same
working method: read "Rules that survive to the wrist" and "Architecture" first
in every session, then take one phase at a time, pasting that phase's section
plus the constraints.

Written 2026-09-13, and revised the same day with the four decisions in items 5
to 8 below. Written against `main` at the state described in CLAUDE.md's
2026-09-10 handoff: `MARKETING_VERSION` 1.3, all twelve 1.3 features landed,
1.2 submitted and awaiting review.

**Status, 2026-09-14: Phase 0 is done and merged** — the two targets exist,
the 1.4 train is open, and the owner answered every open question (see
"Decisions this plan assumes", the dated block after item 10, and the "Done"
note at the head of Phase 0 for what deviated from the text below). Phase 1
is next.

When this was written there was no watchOS anything in the repo:
`grep -ri 'watchos\|watchkit\|complication'` across every `.swift` and `.md`
returned nothing. This is a greenfield platform inside an existing project,
which is the easy case: no migration, no divergence to unwind, and a domain
layer that already runs on macOS in CI and will therefore run anywhere.

---

## Decisions this plan assumes

You made the first eight. The last two follow from the code.

1. **The watch keeps its own SwiftData store, mirrored through the same
   CloudKit private database.** It logs with the phone out of range. There is
   also a WatchConnectivity channel, but it is not a second sync path (see
   "The two bridges"), which is what makes the pair safe rather than a source
   of duplicate rows.
2. **Complications and the Smart Stack are in scope for watch v1.** WidgetKit
   accessory families, with the ＋ running the existing `LogOneDrinkIntent`.
3. **The session reads as a row of dots**, count in small text beside them, no
   separate screen. The dots carry the intensity ramp from `.medium` up. The
   reason for the floor is a contrast measurement, in Phase 5.
4. **Add, remove, and specify all work on the watch**, with one narrow
   exception on remove that HealthKit forces (see "Forced divergences" 3).
5. **Double Tap logs a drink. Digital Crown input does not, yet.** Double Tap
   fires the frontmost app's primary action, so ＋ is assigned to it: logging
   with one hand occupied is the single best thing this platform offers a
   drink tracker. The accidental-entry risk is real and is handled in Phase 3,
   not waved away. Crown-scrolled quantity waits for a v2.
6. **The watch app requires the companion app.** No standalone install from
   the watch App Store. A standalone watch app would reach CloudKit but would
   have no region, no counter seed and no Health mirror, which is not a
   smaller app, it is one that looks broken.
7. **The floor is watchOS 26**, matching iOS 26. No availability guards, one
   API generation. It drops watches older than roughly Series 6, including
   some paired to phones that do run iOS 26, so **confirm the device list and
   check App Store Connect's watchOS version breakdown in Phase 0** before the
   target is created. This is the one decision here that is expensive to
   reverse later, because lowering a floor after shipping means auditing every
   API the watch code has used.
8. **The watch ships before the Android port.** Both want the contract repo
   wired into `tallyist-ios`, and doing it here is the lighter-stakes version
   of that job: one submodule, one vector test target, against code that
   already works. Phase 0 does it, and the Android plan's Phase 0 then finds
   half its work already done.

Two decisions this plan makes for you, both stated as recommendations with the
reopen path attached, because both are user-visible and reversible:

9. **"Specify" on the watch means the type, not the size or the strength.**
   Phase 4 argues it from invariant 2.
10. **The watch targets the 1.4 train, not the open 1.3 one.** A watchOS
    binary is a separate platform in the same App Store record, with its own
    screenshots and its own review surface, and 1.3 is a fix batch away from
    done. Bump `MARKETING_VERSION` in the first watch PR and say so in the
    commit. If you would rather ship it on 1.3, nothing else in this plan
    changes.

**Confirmed by the owner on 2026-09-14**, when Phase 0 landed:

- **10 stands.** 1.3 was submitted and is awaiting App Review, so it is frozen
  the way 1.2 was; `MARKETING_VERSION` is 1.4 on main, bumped in its own commit
  the way the 1.3 bump was.
- **7's floor is 26.0** as written. The template had defaulted the new target
  to 26.5, the installed SDK; 26.0 is what shipped. The App Store Connect
  watchOS breakdown was not checked before the target was created — the floor
  matches iOS 26's, and the check remains worth doing before the watch ships.
- **The design's five open questions** (`docs/design/watch/README.md`, and
  recorded at its end): **(1)** the watch **can** record a day as no alcohol —
  Phase 3 builds the drawn button with the phone's exact copy, and confirms
  that a user-set marker has no Health side effect the watch cannot mirror
  before it writes one; **(2)** no ＋ in `accessoryCircular`, the figure keeps
  the disc and the ＋ is `accessoryRectangular`'s; **(3)** hiding is
  per-glance, nothing stored; **(4)** so it does not govern complications,
  which the system's own redaction covers; **(5)** what `.privacySensitive()`
  renders stays a Phase 6 check. The ADRs those phases write record them.
- **The build settings Shared/ is compiled under must agree across all four
  targets.** Xcode 26's template gave the watch target main-actor default
  isolation, approachable concurrency, member-import visibility and
  string-catalog symbol generation that the other three targets do not have;
  the owner chose to match the three. The verifier now fails on any
  disagreement (its `MEANING_SETTINGS` list).

---

## Rules that survive to the wrist

The seven constraints in `docs/tallyist-1.2-spec.md` hold unchanged. Paste them
into every session. Three of them bite differently on a watch and are worth
restating in their watch form:

- **Rule 3, no goals or streaks.** A complication sits on a watch face all day.
  That is the most persistent surface this product has ever had, and the
  temptation it creates is a standing number that reads as a score. The
  complication shows the session while a session is running and today's count
  otherwise, exactly what the home-screen widget shows, and it goes blank on a
  schedule rather than accumulating (Phase 6).
- **Rule 7, optional and off.** The session dot row on the watch is behind its
  own toggle, off by default, the same as `showsSessionPace` on the phone.
- **The three hard rules of ADR-0017** are unchanged and are not negotiable on
  a new platform: no running time-without-a-drink outside an active session, no
  longest-gap record persisted anywhere, no notifications. The watch makes the
  third one tempting in a way the phone did not, because a wrist tap is cheap.
  Do not build it, not behind a toggle, not in 1.4, not later.

And the invariants in `docs/PRD.md` §2 that this work touches directly:

- **Invariant 1 (the fast path is one tap).** The watch's ＋ is now a third
  surface making that claim, and the invariant's own wording is that one tap
  "cannot mean different things in the widget and the app". That is the
  argument that makes the settings bridge mandatory rather than nice to have.
- **Invariant 3 (region is a display lens).** A watch that defaults to US while
  the phone is set to UK computes every standard-drink figure wrong, silently.
  Also the settings bridge.
- **Invariant 4 (App Group identity is computed, never a literal).**
  `AppGroup.identifier` derives its value by stripping `.Widget` off the
  running bundle id. Two new bundle ids break that derivation. Phase 1 fixes
  it, in the derivation, not with a literal.
- **Invariant 5 (both targets open the store with identical configuration).**
  Now four targets. `SharedModelContainer.make()` still takes no options.
- **Invariant 9 (the domain layer stays free of UI and persistence).** Every
  new piece of arithmetic in this plan lands in `DrinkTrackerCore` and is
  tier-1 tested. There is a lot of that here, deliberately, because tier 3 on
  watchOS means a paired device and is the slowest feedback loop in the
  project.
- **Invariant 10 (the ramp is validated, not eyeballed).** Phase 5 carries the
  measurement.

---

## Architecture

### The watch is a peer, not a mirror

```
iPhone app ──┐                             ┌── watch app
             ├─ SwiftData store (App Group)┤
iOS widget ──┘   mirrored to the user's    └── watch complication
                 private CloudKit database
     │                                              │
     └──────────── CloudKit private DB ─────────────┘
                    (the only sync path)
```

Two devices, two App Groups, two local stores, one CloudKit database. This is
precisely the arrangement two iPhones on one iCloud account already have today,
which is why it needs no new merge logic: SwiftData's mirroring already
reconciles them, and `DrinkRepository.saveOrThrow` is already idempotent by
`entryID`, so the same row arriving twice overwrites in place instead of
duplicating.

The watch app and the watch complication share the on-watch App Group the same
way the phone app and the home-screen widget share the on-phone one. Same
identifier string, different physical container, because an App Group container
is per-device.

**Nothing about this is new code.** `SharedModelContainer.make()`,
`DrinkRepository`, `LogOneDrinkIntent` and `AppSettings.storedRegion()` all
compile for watchOS as written. The work in Phase 1 is making the build system
agree, not changing the architecture.

### The two bridges

WatchConnectivity appears twice in this plan and the two uses are different in
kind. Keeping them apart is the single most important design rule here.

**Bridge 1, settings. Required, Phase 2.** Region and counter seed are stored
in `AppGroup.defaults`, which is per-device by construction and deliberately
not CloudKit-backed (`AppSettings`' own comment: the region "is about the
device's owner, and syncing it would be more surprising than helpful on a
shared iCloud account"). That reasoning is about two people sharing an iCloud
account. A paired watch is the same person, on the same wrist, so the argument
does not carry across and the values must cross. Without them the watch
computes US standard drinks for a UK user (invariant 3) and its ＋ can log a
different drink than the phone's ＋ (invariant 1). Carried as a
`WCSession.updateApplicationContext` payload, which is latest-value-wins and
survives the watch being unreachable at send time, which is exactly the
semantics a settings mirror wants.

**Bridge 2, the live session. Optional, Phase 7.** CloudKit latency between a
phone and a paired watch is typically under a minute and occasionally much
worse. That is fine for a calendar and bad for a number you glance at during
the sitting it describes. So the phone sends a compact snapshot of the last
four hours' entries, and the watch folds it into what it renders.

**The rule that makes Bridge 2 safe: it never writes a row.** Not ever, not
behind a flag. The watch unions the received entry identifiers with its own
local rows, in memory, keyed by `entryID`, computes the session over the union,
and renders that. When CloudKit delivers the real rows minutes later the union
is a no-op, because the ids already match. If the bridge wrote rows, both
devices would export the same drink to CloudKit under two different CKRecord
names, since `DrinkEntry` cannot carry `@Attribute(.unique)` (CloudKit forbids
it) and SwiftData assigns its own record identity. That is a duplicate the
product has no way to detect and no way to repair. The union-in-memory form has
the same benefit with none of that exposure.

The payload is small: for each entry inside the gap threshold, the `entryID`,
`loggedAt`, `countedDrinks`, and the standard-drink value. A heavy evening is a
few dozen of those, comfortably inside the application-context size limit.

### HealthKit: none on the watch

The watch app writes no HealthKit samples and requests no HealthKit
entitlement. Entries it logs land with `healthKitSampleID == nil`, reach the
phone through CloudKit, and the phone's existing `DrinkStore.backfillHealthKit()`
sweeps them into Health on the next foreground. That is the same path the
home-screen widget already uses, for the same reason, and it needs zero new
code.

What this buys, beyond not writing it: no HealthKit entitlement on the watch
target, no new usage-description strings, no new privacy label category, and
nothing new for a reviewer to ask about. Invariant 6 already says HealthKit is
a mirror and never a dependency; the watch is the cleanest possible expression
of that.

---

## Forced divergences

Four places where the watch cannot do what the phone does. Each gets a line in
its ADR so the reasoning survives.

### 1. The watch specifies a type; it does not refine a drink

The phone's `DrinkDetailSheet` asks type, then size pills, then an ABV slider,
at a three-quarter-height sheet that took three attempts to get right (CLAUDE.md,
2026-09-10). None of that fits a 45mm screen, and cramming it there would break
invariant 2 twice over: it turns the fast path into a form, and it asks
questions at log time that the app's whole model says to ask after.

So the watch's "specify" is the type picker alone, five glyphs, and it writes
the type's defaults. That is not a lesser feature, it is the same claim the
phone makes: beer, wine, spirit and cocktail defaults each resolve to almost
exactly one US standard drink, by construction (`DrinkType.defaultVolumeOunces`
and the ADR-0005/ADR-0037 argument behind it). A drink logged from the wrist is
as accurate as a two-tap drink logged in the app. Size and strength are
refinements, and refinements happen on the phone, after.

Reopen path: if the field reports say people want to state a size from the
wrist, the Digital Crown over `DrinkType.sizeOptions` is the obvious shape and
it is additive.

### 2. The watch has its own toggles, because settings are per-device

`showsSessionPace` and the appearance preference are app-local on the phone by
design. The watch gets its own "Show session pace" toggle, off by default,
stored in the watch's own App Group defaults. Appearance does not cross at all:
watchOS has no light mode. Everything on the watch renders against the dark
ground, which is why Phase 5's contrast work reads only the dark ramp.

Region and counter seed are the exception and they cross (Bridge 1). The
dividing line is whether the value changes what gets *computed* or only what
gets *shown*.

### 3. Remove works on the wrist only for drinks Health does not own

This is the one that needed a real decision, so here is the whole argument.

Removing an entry on the phone retires its HealthKit sample
(`DrinkStore.delete`). The watch cannot do that: the sample was written by the
phone app into the phone's HealthKit store, and the watch has neither the
entitlement nor, in general, reach. Deleting the row from the watch would leave
Health holding a sample for a drink that no longer exists, permanently, with no
symptom and no repair. That is exactly why `LogOneDrinkIntent` has no minus and
why the home-screen widget has no minus.

The watch is a full app rather than a short-lived extension, so it has a better
option than "no minus at all":

**Minus is offered when the newest entry in the current session has no
`healthKitSampleID`, and is unavailable otherwise.** Not "skips past to the
next one": skipping would silently remove a drink the user did not point at,
and on a screen this size there is no room to show which one went. Unavailable
means unavailable, with a flat line saying the entry can be removed on the
phone.

In practice this covers essentially every real case, because the entries the
watch logs are exactly the ones with a nil sample id, and they stay that way
until the phone is next foregrounded. A mis-tap corrected in the next thirty
seconds always has the control. A drink from two hours ago, after the phone has
backfilled, does not.

This is also not a new rule, it is an existing one extended. `TodayView`'s
minus already refuses to touch mirrors of another app's data (ADR-0014), and
imported entries are already read-only in the app. "Some entries cannot be
removed here" is an established shape in this product.

Reopen path, if the asymmetry proves annoying: a retirement tombstone. The
watch writes an `EntryRetirement` row carrying the entry id and the sample id,
the phone consumes it on next foreground, deletes the sample, and removes both
rows. That is a schema version bump, a CloudKit console deployment, a migration
fixture and a new record type, which is a lot of machinery for a case that may
not exist. Do not build it speculatively.

### 4. No tip jar, no export, no share card, no onboarding

StoreKit, `ShareLink` at watch size, `ImageRenderer` share cards, the CSV
export and the four-screen onboarding all stay on the phone. The watch is the
logging surface and the glance, and every one of these is a thing you do
sitting down.

The one consequence to handle: a watch app installed before the phone app has
ever run has no region and no store. It defaults to US and an empty log, which
is exactly what the widget already does in that state
(`AppSettings.storedRegion()`'s fallback). Phase 3 shows a flat line for it
rather than a number that is quietly wrong.

---

## What the wrist exposes

This is the section with no equivalent in any previous spec, and it is the one
I would read twice.

Every surface Tallyist has shipped so far goes dark on its own. A phone screen
locks. `QuickLogWidget` supports `.systemSmall` and `.systemMedium`, which are
Home Screen families, so seeing it means the phone is unlocked and in the
user's hand. The app itself is behind whatever the phone is behind.

A watch is not like that, in two specific ways:

**Always-On Display.** When the wrist drops, watchOS keeps the frontmost app
visible in a dimmed state rather than blanking it. So a screen reading "5 this
session" stays legible, on the arm resting on a bar, to anyone sitting across
from it. The user did not choose that; it is the platform default for an app
that happens to be open.

**Complications are public by construction.** A watch face is visible to
everyone who looks at the wrist, all day, with no unlock step anywhere.

For most apps this is a non-issue. For this one it is close to the centre of
the product: a judgment-free tracker whose value depends on the user being
honest with it, on a surface that can show a stranger their count. Someone who
would log a fifth drink on a phone in their pocket may not log it on a wrist
the table can read, and an app that quietly suppresses logging is worse than no
app.

Nothing in the repo addresses this yet. `grep -rn 'privacySensitive\|redact'`
across every Swift file returns nothing, because until now nothing needed it.

**What the plan does about it:**

- Every count on the watch, in the app and in all four complication families,
  is `.privacySensitive()`. Redaction then follows the system: the app's
  numbers redact in Always-On, and complications redact when the watch is off
  the wrist, which is the behaviour a user would expect if they thought about
  it and will never think about.
- The redacted form shows the glyph and the unit word with the figure
  suppressed, not a blank tile. A blank complication reads as broken and gets
  removed from the face.
- The session dot row redacts as outlines, since an outline is already this
  design system's "off the ramp" state (ADR-0007) and a row of filled dots is
  as readable across a table as a numeral.
- Phase 8 adds one line to the privacy policy's "what other people can see"
  reasoning, and one line to the reviewer notes. Neither is a new data
  category, so all three policy copies may not need touching; check rather
  than assume, since `ci.yml` enforces the dates.

Worth stating as the general rule, since it will come up again: **the watch
shows what the user already knows and hides it from everyone else by default.**
If a future surface has to choose between glanceable and private, private wins,
because this product's failure mode is a drink that never gets logged.

**And the design consequence: discreet and quick.** Redaction handles who can
read the screen. Dwell time handles how long there is a screen to read. Those
are different problems and the second one is a layout decision, made once, in
Phase 3:

- The counter screen carries the numeral, ＋, minus and the dot row, and
  nothing else. No header, no navigation chrome, no summary. Everything else
  the watch could show is a reason to keep looking at it.
- No confirmation step, no sheet, no "logged!" screen. The haptic is the
  receipt, which is the whole argument for the haptic being distinct.
- The type picker is one screen deep and returns on tap. It is the only
  navigation in the app.

The target is that logging a drink takes under two seconds from raise to
lower, and that a glance at the session takes one. An app that requires
reading is an app people put down at a table rather than use.

---

## Where this lives

**Same repository, same Xcode project.** Not a second repo, and not a second
project. This is not a preference, it is what watchOS is: the watch app ships
*inside* the iOS app bundle, at `Tallyist.app/Watch/DrinkTrackerWatch.app`, as
one App Store record and one archive. The iOS target's "Embed Watch Content"
phase copies the watch target's product, which means the two targets must live
in one project file. Three more things follow from the same fact:

- `Shared/`'s six files compile directly into all four targets as file
  references. A separate repo means a submodule or a copy, and a copy breaks
  invariant 5 on day one.
- `Config/Signing.xcconfig` is one file deriving four bundle ids, one App Group
  and one iCloud container from `BUNDLE_ID_PREFIX`.
- `ci_scripts/ci_post_clone.sh` stamps `CURRENT_PROJECT_VERSION` across one
  `project.pbxproj`, because "an embedded extension whose version disagrees
  with its host app fails App Store validation."

**The Android port is not a precedent for this.** Android is a separate repo
because it is a separate program: its own binary, its own store, its own
lifecycle, and no shared code by explicit decision. The watch is a *target*,
not a product. Applying the three-repo topology here would be copying the shape
of that decision without the reason for it.

### Keeping a session focused anyway

The concern behind wanting a separate folder is real: a watch phase should be
touching four files in `DrinkTrackerWatch/`, not carrying a 97KB CLAUDE.md and
sixty Swift files of iPhone app. Three mechanisms, none of which needs a second
repo.

**1. A worktree per phase.** This gives the separate folder, with none of the
cost:

```bash
git worktree add ../DrinkTracker-watch watch/phase-3
cd ../DrinkTracker-watch
git submodule update --init --recursive   # worktrees do not inherit these
```

Same repo, same project, own directory, own branch, merges normally. Two
notes. Each worktree needs its own `submodule update`, which matters now that
Phase 0 adds the contract. And `scripts/sync-main.sh` is safe here by design:
it refuses to act on any branch but the one it watches, so a worktree on
`watch/phase-3` is left alone.

**2. A directory-scoped `DrinkTrackerWatch/CLAUDE.md`**, written in Phase 0.
Claude Code reads nested CLAUDE.md files when working in a subtree, so this is
the cheapest focus mechanism available. Something like:

```markdown
# Working in the watch target

The phase you are on is in `docs/tallyist-watch-plan.md`. Read it, plus
"Project constraints" in `docs/tallyist-1.2-spec.md`, before anything else.

Scope: `DrinkTrackerWatch/`, `DrinkTrackerWatchWidget/`, and new pure
functions in `DrinkTrackerCore`. Editing anything in `DrinkTracker/` or
`Shared/` means you are changing the phone app, so say why first.

Never edit `project.pbxproj`. The targets exist; files added to these
folders join them automatically (synchronized groups).

No Swift toolchain here. CI is the only compile check. Say so rather than
claiming local verification.
```

That draft became `DrinkTrackerWatch/CLAUDE.md` in Phase 0, and the committed
file supersedes it. Its project-file rule is the one that survived contact:
Phase 0 was done by Claude in a **local** session with the toolchain, at the
owner's request, and Phase 1 has project-file work of its own (the package
links, the `Shared/` memberships, the shared catalog, `IntensityPalette`'s
move). So the rule is not "never", it is: a **remote** session never touches
`project.pbxproj`, because it cannot verify the edit; a local session may,
for what the plan names, and only verified the way Phase 0 was — `plutil
-lint`, `xcodebuild -list`, both schemes built for their simulators, the
verifier green, and a launch on the paired simulators for anything that
changes what a bundle contains.

**3. One clone, many worktrees.** You currently have at least two checkouts of
this repo on disk, with a LaunchAgent fast-forwarding one of them. Adding
worktrees off a *third* is how a pbxproj edit ends up in the checkout you are
not building. Pick one clone as the working one, branch worktrees off that, and
keep CLAUDE.md's existing rule in mind: pull through Xcode's Integrate → Pull,
or in a terminal with Xcode fully quit, never mixed in one sitting.

The health pairing feature has none of this ambiguity, for the record. It is a
phone feature touching `TrendsView`, `HealthKitService` and
`DrinkTrackerCore`, so it is the same repo without a question to ask.

---

## Phase 0 — the targets (yours, in Xcode, about twenty minutes)

**Done 2026-09-14, and not the way the text below says.** The owner created
the watch app target with Xcode's template on 2026-09-13, then asked Claude to
finish the rest rather than research each Xcode step; it was done by hand in
`project.pbxproj` in a local session with Xcode 26.6, in the Phase 0 PR (three
commits: the 1.4 bump on its own, the targets and their files, the verifier and
docs). What the text below asks for is what shipped, with these deviations and
findings, each recorded so the next reader does not rediscover it:

- **The template's target was `DrinkTrackerWatch Watch App`** — Xcode appends
  the suffix — and carried literal bundle identifiers (the template expands
  its identifier macro to the *resolved* value), `MARKETING_VERSION` 1.0, a
  26.5 floor, and four settings the other three targets do not set:
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY`,
  `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` and
  `STRING_CATALOG_GENERATE_SYMBOLS`. All corrected; the four are deleted so the
  target inherits what the app does, because `Shared/` compiled under two
  isolation regimes means two things (the complication's timeline provider is
  not on the main actor and could not call a main-actor `SharedModelContainer.make()`
  synchronously), and symbol generation folds case into build errors the app
  catalog tolerates (CLAUDE.md's localization notes).
- **`INFOPLIST_KEY_UIBackgroundModes` is not a setting Xcode injects** — none
  of its build specs name it, while every other key in the table is there —
  so the iOS app's built Info.plist has **never** carried `UIBackgroundModes`
  since 1.0, found by reading the built bundle. Both apps now carry an
  explicit `Info.plist` (merged with the generated one, the way the widget
  extensions carry `NSExtension`) with `remote-notification`, and the verifier
  fails on the inert setting. WatchKit's own header names that mode for the
  watch (`WKApplication.h`, `didReceiveRemoteNotification`). The phone-side
  consequence, worth the owner's device pass: CloudKit's silent pushes could
  not wake the app, so the store mirrored only while it was in the foreground.
- **A synchronized folder copies `.md` files into the bundle.** The first
  build shipped `CLAUDE.md` inside `DrinkTrackerWatch.app`; a
  `membershipExceptions` entry (the same mechanism the widgets use for
  `Info.plist`) excludes it, and the rebuilt bundle was checked.
- The complication target was written by hand on the iOS widget's shape:
  `com.apple.product-type.app-extension`, its own `Info.plist` with the
  WidgetKit extension point, `SKIP_INSTALL`, the three-entry runpath, embedded
  by the watch app through an Embed Foundation Extensions phase (`dstSubfolderSpec`
  13) plus a target dependency. Its stub is a `StaticConfiguration` over the
  four accessory families showing a system glyph; `kind` is final
  (`CounterComplication`) because a placed complication's identity is its kind.
- Both targets got an empty `Localizable.xcstrings`, a `PrivacyInfo.xcprivacy`
  declaring the App Group defaults reason (CA92.1), the scaffold entitlements,
  and the shared `DrinkTrackerWatch` scheme (written from the app's, build
  action on the watch app, no testables). The icon is the iOS PNG in a
  `watchos`-platform icon set; `scripts/make-app-icon.py` writes both now.
- **Verified** by `plutil -lint`; `xcodebuild -list`; the resolved settings of
  both targets; the watch scheme built for the watchOS simulator (the future
  CI job); the iOS scheme built for the iOS simulator with the watch app at
  `Watch/DrinkTrackerWatch.app` and the complication at its `PlugIns/`, their
  built Info.plists read back (`WKApplication`, the companion id, 1.4, 26.0,
  the background mode); the verifier at 0 failing; and the watch app launched
  on a paired Series 11 / iPhone 17 Pro simulator pair created for it, showing
  its placeholder. **One simulator lesson:** `simctl install` of the iOS app
  on the phone does *not* put the embedded watch app on the paired watch (the
  launch then fails with `FBSOpenApplicationServiceErrorDomain` code 4, which
  reads as a broken app rather than a missing one); install
  `DrinkTracker.app/Watch/DrinkTrackerWatch.app` on the watch directly, then
  launch it by bundle id. Xcode's Run does that install for you.

**The reasons below were the argument for the owner doing it by hand; the
one that held was the second, and only for remote sessions.** Kept as written:

1. Remote Claude sessions have no Swift toolchain (CLAUDE.md, "CI /
   distribution"). A hand-written watchOS target in `project.pbxproj` is a
   two-hundred-line diff across eight `isa` sections that nothing can verify
   until CI runs, and a wrong one does not fail loudly, it fails as an
   unopenable project on your Mac.
2. The project uses `PBXFileSystemSynchronizedRootGroup`, so once the targets
   and the folders exist, every subsequent phase adds files by writing them to
   disk. Claude Code never has to touch the project file again. Phase 0 is the
   only project-file work in the whole plan.
3. Xcode's template gets `WKApplication`, `WKCompanionAppBundleIdentifier`, the
   Embed Watch Content phase and the target dependency right, and all four are
   easy to get subtly wrong by hand.

What to create:

**Target A, the watch app.** File → New → Target → watchOS → App. Modern
single-target watch app, not the legacy app-plus-extension pair.

| Setting | Value |
|---|---|
| Folder / target name | `DrinkTrackerWatch` (repo convention is the bundle name, not the brand; only the listing says Tallyist) |
| `PRODUCT_BUNDLE_IDENTIFIER` | `$(BUNDLE_ID_PREFIX).DrinkTracker.watchkitapp` |
| `WATCHOS_DEPLOYMENT_TARGET` | `26.0` |
| `TARGETED_DEVICE_FAMILY` | `4` |
| `INFOPLIST_KEY_CFBundleDisplayName` | `Tallyist` |
| `MARKETING_VERSION` | match the train |
| Package dependencies | `DrinkTrackerCore` only. **Not ComponentsKit** |

**Target B, the watch complication.** File → New → Target → watchOS → Widget
Extension, embedded in target A.

| Setting | Value |
|---|---|
| Folder / target name | `DrinkTrackerWatchWidget` |
| `PRODUCT_BUNDLE_IDENTIFIER` | `$(BUNDLE_ID_PREFIX).DrinkTracker.watchkitapp.Widget` |
| Package dependencies | `DrinkTrackerCore` only |

**Entitlements for both**, mirroring `DrinkTracker/DrinkTracker.entitlements`
minus HealthKit, with the same `$(BUNDLE_ID_PREFIX)` substitution so nothing
becomes a literal (invariant 4):

```xml
<key>com.apple.security.application-groups</key>
<array><string>group.$(BUNDLE_ID_PREFIX).DrinkTracker</string></array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.$(BUNDLE_ID_PREFIX).DrinkTracker</string></array>
<key>com.apple.developer.icloud-services</key>
<array><string>CloudKit</string></array>
<key>aps-environment</key>
<string>development</string>
```

The iCloud container is load-bearing on the watch in a way it is not on the
home-screen widget: CloudKit is the watch's only data path, so a missing
entitlement there is not a degradation, it is an app that never sees a drink.
Add `remote-notification` to the watch app's `UIBackgroundModes` as well, the
same as the phone app has, or mirroring will only pull when the app is open.

Also add, in the same commit: `Shared/`'s six files
(`AppGroup.swift`, `AppSettings.swift`, `DrinkEntry.swift`,
`DrinkRepository.swift`, `LogDrinkIntent.swift`, `SchemaVersions.swift`) to
both new targets' Sources build phases. They are individual `PBXFileReference`s
rather than a synchronized group, which is why this is manual and why it is
easiest to do with the checkboxes in Xcode's file inspector.

**Five smaller things, all easy to miss and all painful later:**

1. **`MARKETING_VERSION` must match across all four targets.** App Store
   validation rejects an embedded extension whose version disagrees with its
   host, and there are now four places to bump instead of three. Build numbers
   are already safe: `ci_scripts/ci_post_clone.sh` stamps
   `CURRENT_PROJECT_VERSION` with a global `sed` across the whole
   `project.pbxproj`, so new targets are covered with no change. Marketing
   version is not stamped and is per-target.
2. **Companion required, not standalone.** Xcode's watch template can go either
   way. Leave the watch app dependent on the iOS app, and make sure
   `WKCompanionAppBundleIdentifier` resolves to
   `$(BUNDLE_ID_PREFIX).DrinkTracker`, not a literal.
3. **Tick "Shared" on the new scheme.** Only `DrinkTracker.xcscheme` is shared
   today, and CI cannot build a scheme it cannot see.
4. **The watch needs its own `AppIcon` set.** `scripts/make-app-icon.py` writes
   a single 1024pt PNG to `DrinkTracker/Assets.xcassets/AppIcon.appiconset`,
   which is the modern single-size form watchOS also accepts, so a second
   appiconset fed from the same PNG is a three-line change to the script.
5. **Confirm the watchOS floor before you create the target.** Decision 7
   above. App Store Connect's Analytics has the version breakdown for your
   actual users. Changing this after the code exists means auditing every API
   the watch has used.

Write `DrinkTrackerWatch/CLAUDE.md` in this same commit, from the draft in
"Where this lives". It is the thing that keeps every later session inside the
watch target, and it costs five minutes now against an afternoon of unpicking
a phase that wandered into the phone app.

**Also in Phase 0, and not about the watch: wire the contract submodule.**
(Done in PR #93 on 2026-09-13, with the read-only token CI fetches it with —
CLAUDE.md's process section.) The
Android plan's Phase 0 calls for `tallyist-product` to be added to
`tallyist-ios` at `contract/`, with a vector test target and
`submodules: recursive` on CI's checkout. When this was written there was no
`.gitmodules` and no `.claude/` directory in this repo, so none of it had happened. It costs
maybe an hour here, against code that already passes, and it is the difference
between the `constraints-reviewer` agent existing for the watch phases and not.
The Android port then starts with that work behind it.

Expect one or two vector mismatches when the iOS suite first runs against
`vectors/session.json`. Those are the cases where the spec and the shipped code
already disagree, and finding them now, before a second and third platform
inherit the disagreement, is the point.

Commit the project file on its own branch with nothing else in it, so the diff
is reviewable and so a later bisect can isolate it.

---

## Phase 1 — make the shared layer build for watchOS

One session. No UI. Ends with a watch app that launches, opens the store, and
prints the count of today's entries in a `Text`.

**1. `DrinkTrackerCore/Package.swift`.** Add `.watchOS("26.0")` to `platforms`
— **not `.v26`**: that constant needs a newer `swift-tools-version` than the
package's 6.0 and fails to compile ("'v26' is unavailable"), while the string
form resolves to `watchos 26.0` under 6.0 unchanged (checked with
`swift package dump-package` on a scratch copy, 2026-09-14). `swift test` on
macOS is unaffected; a platforms entry declares a minimum, it does not narrow
the build.

**2. `Shared/AppGroup.swift`, the derivation.** Today:

```swift
private static let widgetSuffix = ".Widget"
```

and one `hasSuffix` check in two places. Two new bundle ids break it:
`…DrinkTracker.watchkitapp` yields `group.….DrinkTracker.watchkitapp`, and
`…DrinkTracker.watchkitapp.Widget` strips one suffix and yields the same wrong
thing. Replace with an ordered list of suffixes stripped repeatedly until none
matches:

```swift
private static let hostSuffixes = [".Widget", ".watchkitapp"]

private static var hostBundleID: String {
  var id = Bundle.main.bundleIdentifier ?? ""
  var changed = true
  while changed {
    changed = false
    for suffix in hostSuffixes where id.hasSuffix(suffix) {
      id = String(id.dropLast(suffix.count))
      changed = true
    }
  }
  return id
}
```

Both `identifier` and `iCloudContainerIdentifier` then read `hostBundleID`,
which removes the duplicated stripping logic that exists today as well. This
stays a derivation, so invariant 4 holds.

**Test it at tier 1.** The current derivation has no test because it reads
`Bundle.main`. Extract the pure part as
`AppGroup.hostBundleID(from: String) -> String`, move it to `DrinkTrackerCore`,
and pin all four ids in `DrinkTrackerCoreTests`. This is the single cheapest
regression guard in the phase: a wrong group identifier does not fail the build,
it hands the watch app and its complication two separate stores, and the only
symptom is a complication stuck on zero.

**3. `IntensityPalette` moves to `Shared/`.** It currently lives in
`DrinkTracker/DesignSystem/IntensityPalette.swift`, inside the app target's
synchronized folder, and the dot row needs it. Move the file to `Shared/`, add
it to all four targets. It imports only SwiftUI and compiles on watchOS as
written. Invariant 10's claim that it is "the only place in the app that
defines literal colours" names the type, not its folder, so `docs/PRD.md` needs
no change. `docs/design-system.md` does: its header still says the code home is
`DrinkTracker/DesignSystem/`.

Leave `GlassTokens` and `AppTheme` where they are. The watch gets its own small
set of tokens in Phase 3, because watchOS's layout units and its Liquid Glass
surfaces are not the phone's and pretending otherwise produces a shrunken
iPhone app.

**4. The drink glyphs move to a shared catalog.** `DrinkType.symbolName`
returns asset-catalog names (`tally.beer` and so on) that are generated by
`scripts/make-drink-symbols.py` into `DrinkTracker/Assets.xcassets`, and
`ci.yml`'s `drink-symbols` job regenerates and requires that path to be clean.
The watch's type picker needs the same eight symbols.

Create `Shared/Assets.xcassets`, move the `.symbolset` folders into it —
**all thirteen**, not eight: the five `tally.tab.*` from ADR-0040's amendment
share the generator's one `CATALOG` constant and `check_swift_names()` asserts
the catalog holds the full set, so moving eight leaves the generator exiting
non-zero — add the catalog to all four targets, and change two paths: the
output path in `scripts/make-drink-symbols.py` and the two `git diff` paths in
the `drink-symbols` CI job (its comment also says eight). **Move `AccentColor`
and `AccentFill` with them.** The design draws glyphs in the accent and the ＋
disc in the fill, and the two watch targets carry only the template's *empty*
`AccentColor` colorset (which resolves to the system blue); copying the app's
values in would be a second uncontrolled home for validated colours, invariant
10's own failure mode, so the shared catalog is where they go — and delete the
two empty template colorsets when it arrives, or the duplicate asset name is a
build error. Keep the app icon and every other asset where it is.

Verify the generator is clean afterwards, which is the one thing in this phase
you can check without a toolchain:

```bash
python3 scripts/make-drink-symbols.py && git status --porcelain -- Shared/Assets.xcassets
```

**5. Strings and shortcuts, two small traps.**

Every target carries its own `Localizable.xcstrings` (the app, the widget and
the core package each have one today), so the two watch targets get two more.
CLAUDE.md's warning applies with more force at four: local builds modify these
through automatic string extraction, and a conflicted stash-pop corrupted them
once. The repair is still `git reset --hard origin/main`.

And do **not** add an `AppShortcutsProvider` to either watch target.
`DrinkTrackerShortcuts.swift` says why in its own header: a provider declared
in two places registers the same phrases twice. The watch compiles
`Shared/LogDrinkIntent.swift` because the complication's ＋ needs
`LogOneDrinkIntent`, and that is all it needs. Siri on the watch already
relays to the phone's shortcuts. If watch-native phrases turn out to be wanted,
that is its own decision with its own ADR, after v1.

**6. A watch CI job.** Add to `.github/workflows/ci.yml`, modelled on the
existing `build` job:

```yaml
  build-watch:
    name: Build (watchOS Simulator)
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v5
      - name: Select newest installed Xcode
        run: |
          latest=$(ls -d /Applications/Xcode*.app | sort -V | tail -1)
          sudo xcode-select -s "$latest/Contents/Developer"
          xcodebuild -version
      - name: Build
        run: |
          set -o pipefail
          xcodebuild build \
            -project DrinkTracker.xcodeproj \
            -scheme DrinkTrackerWatch \
            -destination 'generic/platform=watchOS Simulator' \
            -skipPackagePluginValidation \
            CODE_SIGNING_ALLOWED=NO
```

The watch scheme has to be shared (`xcshareddata/xcschemes/`) or CI cannot see
it. Only `DrinkTracker.xcscheme` is shared today, so tick "Shared" on the new
scheme in Phase 0 and commit it.

From here on, this job is the compile gate for every watch phase, and it is the
only one a remote session gets. Say so in commit messages rather than claiming
local verification.

**Acceptance:** the five existing CI jobs plus the new one green; the watch app launches
in the simulator and shows a number; `AppGroup.identifier` is identical in all
four processes, which the new tier-1 test pins.

---

## Phase 2 — the settings bridge

One session. The smallest phase with the highest consequence, because both
invariants it protects fail silently.

**The payload.** A `Codable` value type in `DrinkTrackerCore`, so it is tier-1
testable and so both platforms cannot disagree about its shape:

```swift
public struct WatchContext: Codable, Equatable, Sendable {
  public let region: Region
  public let counterSeed: DrinkDraft.CountSeed
  public let sentAt: Date
}
```

Encode and decode through a single pair of functions in the package. The
dictionary form `WCSession` wants is `[String: Any]`, so the codec is
`toDictionary` / `init?(dictionary:)` with an explicit version key, and a
missing or unreadable payload means "keep what you have", never "reset to the
default". A watch that briefly reads an empty context and reverts to US is a
worse failure than one that keeps a stale but correct region.

**Phone side.** A `WatchContextPublisher` in the app target. Sends on
`WCSession` activation, on foreground, and in the `didSet` of
`AppSettings.region` and `AppSettings.counterSeed`, next to the existing
`WidgetCenter.shared.reloadAllTimelines()` calls, which is already the place
this app puts "tell the other surfaces" work.

**Watch side.** A `WatchContextStore` that receives the context and writes
region and counter seed into the watch's `AppGroup.defaults` under the keys
`AppSettings` already uses, after which everything reads back through
`AppSettings.storedRegion()` and `AppSettings.storedCounterSeed()` like every
other non-main-actor caller does. Writing into the same keys means the watch's
complication reads the right region with no code of its own, exactly as the
home-screen widget does.

`AppSettings.Keys` is `private`, so the watch cannot name those keys from
outside. Do not widen the enum: add two `nonisolated static` writers beside the
two `nonisolated static` readers that already exist for this exact situation:

```swift
nonisolated static func store(region: Region, defaults: UserDefaults = AppGroup.defaults)
nonisolated static func store(counterSeed: DrinkDraft.CountSeed, defaults: UserDefaults = AppGroup.defaults)
```

Same file, same pattern, key strings still in one place, and the symmetry with
`storedRegion()` and `storedCounterSeed()` makes the pairing obvious to the
next reader.

`updateApplicationContext` rather than `sendMessage`: latest-value-wins,
delivered when the counterpart next becomes available, no reachability
requirement. Settings are state, not events.

**Acceptance:** changing region on the phone changes every figure on the watch
without opening the watch app first; the counter seed set on the phone is what
the watch's ＋ logs; a watch that has never received a context defaults to US
and says so in Phase 3's empty state rather than showing a figure.

**Tier 1:** round-trip the codec, an unknown version, a missing key, a garbage
value for each field. **Tier 4, yours:** actual delivery on a paired device,
including with the phone asleep.

---

## Phase 3 — the counter

One session, one writer. The core loop, and the phase that most needs to feel
right rather than merely work.

The screen is the phone's Today counter reduced to what a wrist can carry:
today's count as the headline numeral, the ＋ as the primary control, the minus
as the secondary, and one line beneath.

**＋ runs the same rule as everywhere else.** Not a reimplementation:

```swift
let region = AppSettings.storedRegion()
let seed = AppSettings.storedCounterSeed()
let history = ((try? context.fetch(FetchDescriptor<DrinkEntry>())) ?? []).loggedDrinks
let drink = DrinkDraft
  .quickCount(1, from: history, seed: seed, region: region)
  .makeLoggedDrink(region: region)
try repository.saveOrThrow(drink)
```

That is `LogOneDrinkIntent.perform()`'s body verbatim. Call the intent itself
where you can, or lift the shared part into a function in `Shared/` that both
call. What must not happen is a fourth copy of the seed rule: ADR-0023's whole
argument, and the day-sheet caption bug that `countSeedPreview` exists to
prevent, is that a second implementation of this rule drifts.

**Minus** removes today's newest entry, through `DrinkRepository.delete(id:)`,
and is disabled when that entry's `healthKitSampleID` is non-nil (divergence 3).
Put the predicate in `DrinkTrackerCore` as a pure function over
`[LoggedDrink]`, so the rule is tier-1 tested rather than living in a view:

```swift
public static func removableNewest(in drinks: [LoggedDrink], on day: Date,
                                   calendar: Calendar = .current) -> LoggedDrink?
```

Nil means the control is unavailable. Cover: nothing today, newest has a
sample, newest is an import, newest is watch-logged behind an older
phone-logged one.

**Haptics.** `WKInterfaceDevice.current().play(.click)` on a successful log,
`.failure` on a refusal. This is the one place a watch should feel different
from a phone: the confirmation is the point, because the user is not looking.
Nothing celebratory, `.success` included, which reads as praise for the act
(invariant 8).

**Double Tap**, per decision 5. Assign ＋ as the primary action:

```swift
.handGestureShortcut(.primaryAction)
```

on the ＋ button, and nothing else in the app claims it. Two things have to be
true before this ships, because an accidental entry in a log whose whole value
is accuracy is a worse bug than a missed tap:

- The gesture fires only while the counter screen is frontmost, which is how
  the modifier already behaves. Do not put it on the complication or anywhere
  reachable from the face.
- A Double Tap log is distinguishable by feel. Use a different haptic from the
  on-screen tap, so a pinch the user did not mean announces itself immediately
  rather than being discovered three days later in History.

The minus sitting right beside it is the correction path, and entries the watch
logs always satisfy the nil-sample rule for as long as this is likely to
matter, so an accidental drink is removable where it happened. Say so in the
ADR: this is the mitigation, and it is load-bearing.

**The line beneath** is today's total in the region's units, through
`StandardDrink.liveEstimate`, the same string the medium widget carries. When
no context has ever arrived, the line reads that the region has not been set
yet rather than printing a US figure.

**And one failure state.** `Diagnostics.isStoreInMemory` is true when the store
could not be opened at all and nothing is being saved. On the phone this is the
one place house voice permits an exclamation mark, in `SettingsView`. The watch
has no Settings screen worth the name, so it needs the shortest honest version
of that line on the counter itself, because a watch that silently discards every
log is the worst outcome available here and is otherwise invisible.

**Privacy.** The count and the total are `.privacySensitive()`. See "What the
wrist exposes".

**Watch out for:** the phone's counter guards against rapid taps by refetching
at execution time (`TodayView`, lines 59 and 444, and the comment about a minus
racing a plus and deleting a sample the user never asked to remove). The same
race exists here and is likelier, because a watch tap is easier to repeat.
Read `TodayView`'s counter section before writing this one, and carry the same
discipline: act on the store at execution time, never on a captured snapshot.

**Acceptance:** the count matches the phone's after CloudKit settles; ＋ with
the phone powered off still logs; two fast taps log two drinks; minus never
removes an entry Health owns.

---

## Phase 4 — specify a drink

One session. Small, and mostly a picker.

A second screen, reached from the counter, showing the five
`DrinkType.selectableCases` as glyph over name, using
`DrinkType.symbolName` against the shared catalog from Phase 1. Tapping one
logs that type at its defaults, through `DrinkDraft(type:)` →
`makeLoggedDrink(region:)`, and returns to the counter.

Note the two rules the phone's picker follows and match them: it never hides a
segment, and `.unspecified` is never offered as a choice (the case's own
comment, and invariant 2's "the picker stays for the whole presentation").
`selectableCases` already excludes it; iterate that, not `allCases`.

`Image(_:)` or `Label(_:image:)`, never `Image(systemName:)`. These are asset
catalog symbols, not SF Symbols, and `systemName` renders nothing for them.

**Acceptance:** all five types log; the entry is identical to a two-tap phone
log of the same type; the glyphs render at both watch sizes and in the
complication's tint rendering mode.

---

## Phase 5 — the session, as dots

One session. Needs an ADR, and the ADR needs a contrast table.

**What it shows**, on the counter screen, beneath the numeral, only when the
watch's own "Show session pace" toggle is on and only while
`SessionPace.currentSession` returns a value:

```
● ● ● ● ●        5 · 1h 12m
```

A row of dots, one per drink in the session, and a small line carrying the
count and the elapsed time since the session started. No start timestamp, no
"last drink N ago", no rolling-window chip. The phone's card has four values
because the phone has room; the wrist gets the one number the feature exists
for, which is the count, and one supporting figure.

**The cap.** Dots stop being countable past about eight and the watch runs out
of width sooner than that. Put the rule in `DrinkTrackerCore` as a pure
function and test it, rather than deciding it in a `ForEach`:

```swift
public static func dotRow(forCount count: Double, maximum: Int = 8) -> DotRow
```

returning the number of dots to draw and whether the row is truncated. Above
the cap, draw the maximum and let the numeral carry the truth, which it already
does. Fractional counts from Health imports round in one stated direction;
pick it in the ADR and test it.

**The colour, and why the ramp starts at `.medium`.** The dots carry
`IntensityPalette.fill` for the band of the rolling two-hour window's standard
drinks, which is exactly `SessionPaceCard.paceBand`'s rule, so a shade on the
wrist means what a shade means on the calendar (ADR-0034's argument, and
invariant 10's "one hue, one scale").

But the phone's chip and the watch's dots are different objects under WCAG: a
chip is text on a fill and needs 4.5:1 of its ink against that fill, while a
dot is a graphical object and needs 3:1 against its *background*. So the phone's
`.high`-and-above floor cannot simply be copied, it has to be re-derived. The
watch renders only against the dark ground, so only the dark ramp is in
question. Computed from `IntensityPalette`'s own values:

| Band | Dark fill | vs pure black | vs `#1C1C1E` |
|---|---|---|---|
| `.low` | `#184f95` | 2.59 : 1 | 2.10 : 1 |
| `.medium` | `#3987e5` | 5.77 : 1 | 4.67 : 1 |
| `.high` | `#9ec5f4` | 11.76 : 1 | 9.53 : 1 |
| `.veryHigh` | `#cde2fb` | 15.86 : 1 | 12.85 : 1 |

`.low` fails 3:1 against either plausible ground, and fails it worse against a
list row's dark grey than against an OLED black. Everything above it clears the
threshold with room.

So: **`.medium` and above tint the dots; below that they stay on the neutral
fill.** Three states, the same count as the phone's chip, arrived at
independently and for a different reason.

Two of those figures are checkable against numbers this project already
published, which is worth doing before trusting the other two.
`IntensityPalette.ink` returns `.black` for `.medium` and above in the dark
scheme, so the dark ink-on-fill contrasts `SessionPaceCard.paceBand` documents
are the same quantity as fill-against-black: it states 11.75:1 and 15.87:1 for
`.high` and `.veryHigh`, against 11.76 and 15.86 above. `docs/design-system.md`
line 88 independently publishes `#9ec5f4` as 9.52:1 on `#1C1C1E`, against 9.53.
The method agrees with the project's to within rounding, which is the only
reason to believe the two rows nothing else has measured.

Recompute all four anyway when you write the ADR. Invariant 10 exists because a
colour error here is invisible to anyone with normal colour vision reviewing
the diff.

An unfilled outline is the design system's existing second channel for
"off the ramp" (ADR-0007), so a neutral dot should read as an outline rather
than a grey fill, which also keeps the row legible in the complication's
tinted rendering mode where the fill colour is discarded entirely.

**Update discipline**, unchanged from the 1.2 spec: the row sits inside
`TimelineView(.periodic(from: .now, by: 60))`, no `Timer`, no one-second
wakeups. On a watch this matters more than on a phone: a one-second timer in a
frontmost watch app is a battery complaint in a review.

**Accessibility.** The dots are decorative in the accessibility tree; the count
and elapsed time carry the fact, combined into one element with a flat label.
The colour adds no accessibility value, which is the same argument
`SessionPaceCard` already makes for its chip.

**Privacy.** The row and its figures are `.privacySensitive()`, redacting to
outlines. See "What the wrist exposes" for why this row in particular: a count
of filled dots is readable from across a table in a way a numeral is not.

**Acceptance:** the row is absent with the toggle off; absent with no drink
inside four hours; appears within one render of a log; nothing about a gap is
written anywhere; no notification code path exists in the target; the row
redacts in Always-On rather than sitting there lit.

---

## Phase 6 — complications and the Smart Stack

One session. Its own target and its own gotchas, which is why it is not folded
into Phase 5.

**Families.** `.accessoryCircular` (the corner-of-the-face one, and the one
most people will place), `.accessoryRectangular` (the Smart Stack card),
`.accessoryInline` (the text line above the face), `.accessoryCorner`.
Everything is `StaticConfiguration`, like `QuickLogWidget`.

**What each shows**, in one rule: the session count while a session is running,
today's count otherwise. The same thing the home-screen widget shows, no more.
The rectangular family has room for the dot row from Phase 5; circular and
inline carry the numeral and a unit word.

**The ＋ is interactive.** A `Button(intent: LogOneDrinkIntent())` in the
rectangular and circular families gives you a genuine one-tap log from the
watch face, which is the strongest thing on this whole list and is free because
the intent already exists and already reads the seed from the App Group.
Invariant 1 extends to it with no new argument.

**Timeline expiry is the part that is easy to get wrong.** A complication
showing "5 this session" must stop saying that when the session ends, and
nothing wakes it at that moment. Build the timeline with two entries: the
current one, and one dated `session.lastDrinkAt + SessionPace.gapThreshold`
carrying the post-session state, with `.after` that date as the refresh policy.
Without the second entry the face keeps a dead session's count until something
else triggers a reload, which is precisely the accumulating standing number
rule 3 forbids.

`WidgetCenter.shared.reloadAllTimelines()` after every write on the watch, the
same as the phone does.

**No relevance-based surfacing.** watchOS will happily let you push a Smart
Stack card forward by time of day or by location. Do not. "You usually drink
around now" is a behavioural prediction presented as help, it is the clearest
constraint-3 violation available on this platform, and it would be surfaced by
the app rather than requested by the user. The card appears in the stack
because the user put it there.

**Watch out for:** the home-screen widget's dispatch bug is documented at
length in `LogDrinkIntent` and in `docs/device-test-widget-dispatch.md`, and
its cause was a promptable parameter, not registration. `LogOneDrinkIntent` is
parameterless and structurally cannot repeat it, which is why it is the one to
use here. Do not place `LogDrinkIntent` or `LogDrinksIntent` on a complication.
The `Diagnostics` breadcrumbs work on watchOS unchanged and are worth reading
if a tap appears to do nothing.

**Privacy.** Every family is `.privacySensitive()`, redacting to the glyph and
the unit word with the figure suppressed, never to a blank tile. A complication
that looks broken gets removed from the face, which loses the feature entirely.

**Acceptance:** all four families render at every watch size; the ＋ logs
without opening the app; the session count disappears within a render of the
gap threshold passing; the complication follows the system appearance and the
tint rendering mode legibly; the count redacts with the watch off the wrist and
comes back when it is on.

---

## Phase 7 — the live session bridge

One session. Optional in the sense that Phases 1 to 6 ship a complete product
without it, and worth doing because a session count that lags the sitting by
several minutes is the one number in this app where latency is the whole
failure.

Read "The two bridges" above before writing anything. The rule is that this
never writes a row, and everything else is detail.

**Shape.** A second application-context payload from the phone, or a second key
in the Phase 2 one, carrying the last four hours of entries reduced to what the
session math needs:

```swift
public struct SessionSnapshot: Codable, Equatable, Sendable {
  public struct Entry: Codable, Equatable, Sendable {
    public let id: UUID
    public let loggedAt: Date
    public let countedDrinks: Double?
    public let standardDrinks: Double
  }
  public let entries: [Entry]
  public let generatedAt: Date
}
```

**The union, in `DrinkTrackerCore`, pure and tier-1 tested:**

```swift
public static func union(local: [LoggedDrink], snapshot: [SessionSnapshot.Entry])
  -> [LoggedDrink]
```

Keyed by `id`. Local wins on conflict, because local rows are the real ones and
a snapshot entry is a shadow. The result feeds `SessionPace.currentSession` and
`rollingCount` unchanged, which is the point of having kept that math pure.

Cases to test, all cheap: snapshot arrives before CloudKit (the count is right
immediately), CloudKit arrives after (the count does not double), an entry
deleted on the phone and still present in a stale snapshot (it is not
resurrected, so the snapshot must carry the full window each time and replace
rather than merge into the previous one), an empty snapshot, a snapshot older
than the gap threshold (ignored entirely).

Send it on write and on foreground, debounced. Phone to watch only in v1: the
phone's own session card is a sit-down surface and does not need the shim.

**Acceptance:** log on the phone, raise the wrist, the number is right; nothing
new appears in the watch's store as a result; deleting on the phone removes it
from the watch's view within one send.

---

## Phase 8 — release

One session, plus your device pass.

- `docs/app-store-listing.md`: What's New for the train, and reviewer notes
  saying what the watch app is. Draft, for the tone review: *the watch app logs
  drinks and shows the current sitting's count. It has no account, makes no
  network requests beyond the user's own iCloud database, writes no Health
  data, and sends no notifications.*
- The claims table in the 1.2 spec, re-verified against the watch. All four
  claims hold unchanged; say so explicitly rather than assuming.
- **Expect a closer look than a normal update gets.** A new platform in an
  existing record is a new binary a reviewer has not seen, on an app that
  cleared a review by explaining itself. Write the reviewer notes as though the
  1.0 conversation is being reopened, because from the reviewer's side it
  partly is: what the watch app does, what it does not do, and that it adds no
  account, no server, no notification and no Health access. The 1.0 Resolution
  Center response is the model for the register.
- Privacy policy: read it against the watch and decide whether any of the three
  copies need a line. My read is that they do not, because the watch adds no
  data category, no collection and no transmission the policy does not already
  describe. Confirm it rather than take it, and if a line is needed, all three
  copies change in the same commit with the date bumped (ADR-0024, and `ci.yml`
  enforces the date).
- `docs/copy-review-1.4.3.md`: append every new user-visible string. There are
  perhaps a dozen: the empty state, the region-unset line, the minus-unavailable
  line, the session count and elapsed forms, the toggle and its explanation,
  the complication display name and description.
- App Store Connect: a watchOS app needs its own screenshot set. Two sizes
  currently, and they are yours to capture on the simulator.
- `docs/design-system.md`: the watch tokens and the dot row, with the contrast
  table from Phase 5.
- CLAUDE.md's Current state: the handoff entry.

---

## The ADRs

Five, following `docs/decisions/0000-template.md`, numbered from 0041:

- **0041, the watch is a peer store, not a mirror.** CloudKit as the only sync
  path; WatchConnectivity carries settings and a display snapshot and never
  writes a row; why that is the safe form given `DrinkEntry` cannot be unique.
- **0042, the watch logs and specifies; it refines nothing.** Type-only
  specification, defaults per type, the invariant-2 argument, the Digital Crown
  reopen path. Also Double Tap on ＋: why the accidental-entry risk is worth
  taking, and the two mitigations that make it so.
- **0043, the watch removes only what Health does not own.** The asymmetry, why
  unavailable beats skipping, the tombstone reopen path and its real cost.
- **0044, the session reads as dots, and the ramp starts at medium.** The
  contrast table, the non-text 3:1 threshold against the phone's 4.5:1 one, the
  outline as the neutral state, the dot cap.
- **0045, the watch hides its numbers by default.** Always-On, complication
  visibility, `.privacySensitive()` everywhere, redaction to glyph rather than
  blank, and the general rule that private beats glanceable in this product
  because the failure mode is a drink that never gets logged. This is the one
  ADR here that is about what Tallyist is rather than how watchOS works, so it
  is worth writing carefully.

Write each one in the phase it belongs to, not in a batch at the end. A
decision recorded after the code is a summary; one recorded during it is a
record.

---

## Testing

| Tier | Runs where | What this plan puts there |
|---|---|---|
| 1, domain | `swift test`, macOS, CI | the App Group derivation, the `WatchContext` codec, `removableNewest`, `dotRow`, the snapshot `union`, every session case re-run under it |
| 2, repository | `DrinkTrackerTests`, simulator, CI | nothing new required; the watch writes through paths already covered |
| 3, simulator | your Mac | watch app launch, the four complication families at every size, the type picker's glyphs, dark-ground contrast |
| 4, device | your paired watch | CloudKit latency in practice, WatchConnectivity delivery with the phone asleep, the complication's expiry at the gap threshold, haptics, logging with the phone powered off, battery over a real evening |

The ratio matters more here than it did on the phone, and worse than that table
suggests. Two specifics:

- **WatchConnectivity is testable at tier 3.** A watch simulator paired to an
  iPhone simulator delivers application contexts, so Phase 2 and Phase 7 can be
  exercised on your Mac.
- **CloudKit sync between the two is effectively tier 4 only.** It needs a real
  iCloud account on both sides, and the simulator pair is a poor stand-in for
  two devices with independent network conditions. Which means the watch's
  *only* data path is the one you cannot check before putting it on your wrist.

That is the argument for everything else being pure. Tier 3 on watchOS is a
slow loop, tier 4 is slower, and the thing you most want to be sure about is
the thing you can least test, so anything that can be a pure function in
`DrinkTrackerCore` should be, even when it looks like view logic. Every "put
this rule in the package" note above is there for that reason.

---

## Things this plan explicitly does not need

Worth stating, because each one is a step this project's process would normally
demand and each is genuinely absent here. Not needing them is a large part of
why the watch is a smaller job than it looks.

- **No CloudKit schema change, so no console deployment.** The watch adds no
  record type and no attribute. CLAUDE.md's rule about deploying schema changes
  to Production before the next TestFlight build does not apply, and neither
  does `SchemaVersions.swift`'s recipe. `CurrentSchema` stays at V2 and no
  migration fixture is written. If a phase finds itself wanting a new field,
  that is a signal the design has drifted, most likely into the retirement
  tombstone that divergence 3 defers.
- **No build-number work.** `ci_scripts/ci_post_clone.sh` stamps
  `CURRENT_PROJECT_VERSION` with a global substitution across the whole project
  file, so the two new targets are covered the day they exist.
- **No new contract vectors.** `vectors/session.json` already holds the session
  math, and the watch runs the same functions. The dot cap and the redaction
  rules are presentation, which the contract's own dividing line puts on the
  platform side. The contract does gain one thing: a watchOS entry in
  `platform/divergences.md`, so that if Wear OS ever happens the four
  divergences above are already written down rather than rediscovered.
- **No new permissions, entitlements beyond the two, or privacy label
  categories.** No HealthKit, no notifications, no location, no motion.

---

## Working the phases in Claude Code

The repo's method already: one phase per session, `docs/tallyist-1.2-spec.md`'s
"Project constraints" plus this file's "Rules that survive to the wrist" pasted
every time, branch → draft PR → CI green → merge.

What parallelises: nothing much, honestly, until Phase 5. Phases 1 through 4 are
a chain where each needs the previous one to compile, and the fan-out that works
on Android (three read screens that barely touch) has no equivalent on four
watch screens that all read the same store. The two places worth splitting:

- **Phase 5 and 6 in parallel**, after Phase 4 lands, if the dot row's pure
  functions are written first. One agent on the app's row, one on the
  complication target. Separate folders, separate files, no overlap.
- **Test authoring alongside implementation** in Phase 1 and 7, where the pure
  functions have a signature before they have a body.

Everything else is one agent, one phase.

The gate at the end of every phase, in this order:

1. The six CI jobs, including the new watch build.
2. The `constraints-reviewer` agent from `tallyist-product/agents/` over the
   phase diff. The contract repo already holds it and it reads
   `contract/constraints.md` and `copy/tone.md`, both of which are
   platform-neutral and apply here unchanged. If the iOS repo has not taken the
   contract as a submodule yet (it has not, as of this writing), either wire it
   up in Phase 0 or copy the agent definition into `.claude/agents/` for now.

The second gate is the one that matters on this platform. The watch is the most
glanceable surface this product has, which makes it the easiest place for a
number to start reading as a score. A reviewer whose only job is to hold the
diff against seven rules catches that before it ships.

---

## What I could not verify

Stated plainly, because a plan that hides its assumptions is worse than one
that is wrong out loud.

- **No toolchain, when this was written.** Nothing in the plan was compiled;
  every Swift snippet is written from the surrounding code's shape and should
  be treated as intent, not as a patch. Phase 0 itself was then done and
  built in a local session with Xcode 26.6 (see its "Done" note), which is
  also how the `.v26` and `INFOPLIST_KEY_UIBackgroundModes` errors in the
  original text were caught.
- **The contrast table** in Phase 5 is computed by hand from
  `IntensityPalette`'s literal values, and two of its rows reproduce figures
  this project already published, so the arithmetic is probably right. The
  *grounds* are the assumption: I do not know what watchOS 26 actually paints
  behind a row in the container you end up using, and `#1C1C1E` is borrowed
  from the design system's existing reference rather than measured on a watch.
  Check the real ground before fixing the floor at `.medium`.
- **CloudKit latency between a phone and a paired watch** is the number Phase 7
  exists for and I have no measurement of it. It may be fast enough that the
  bridge is unnecessary. Ship Phases 1 to 6, live with it for an evening, and
  decide then.
- **Whether the watch's store mirrors reliably when the watch is on its own
  Wi-Fi or cellular**, away from the phone, is a real question with no
  desk answer. Tier 4.
- **The watchOS 26 device list.** Decision 7 rests on roughly where that floor
  falls and on how many of your users sit below it. I have neither number to
  hand. Confirm both in Phase 0, from Apple's support page and from App Store
  Connect's Analytics, before the target is created.
- **How `.privacySensitive()` actually renders** in Always-On and on a face at
  each complication size. The redaction *policy* is sound; what the redacted
  tile looks like is a tier-3 question and the answer may send you back to the
  design. Check it in Phase 6, not in Phase 8.
- **Whether a Double Tap can fire while the app is open in a pocket.** The
  modifier is scoped to the frontmost app, which ought to make this a non-issue,
  but "ought to" is doing work in that sentence and the cost of being wrong is
  a phantom drink. Tier 4, and worth an evening of deliberately trying to
  provoke it before shipping.
- **A pre-existing thing I noticed and did not touch:**
  `DrinkTrackerWidget.entitlements` declares the App Group but no iCloud
  container, while `SharedModelContainer.make()` asks every process for
  `.automatic` CloudKit. The widget presumably falls to the no-CloudKit rung of
  its own ladder, and its writes reach CloudKit later because the app exports
  them when it next opens the store. That is probably benign and it is
  certainly not this plan's business, but it sits next to invariant 5's claim
  that both targets open the store identically, and the watch's entitlement
  work is when you will be looking at all four of these files anyway.
