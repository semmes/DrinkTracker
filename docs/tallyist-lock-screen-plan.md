# Tallyist on the Lock Screen — build plan

Companion to `docs/tallyist-1.2-spec.md` (the constraints), `docs/tallyist-watch-plan.md`
(whose Phase 6 built the thing this plan reuses) and `docs/tallyist-health-pairing-plan.md`
(whose working method this plan copies: one phase per session, the rules pasted every
time, a research phase before any code). Read "What the platform allows", "Decisions this
plan needs" and "Rules that survive to the Lock Screen" in every session, then take one
phase.

Written 2026-09-23 against `main` at 3985037 (PR #125), with no toolchain run and no
simulator touched: everything here was read from the repo, from the Xcode 27.0 SDK's
interface files on this Mac, and from Apple's documentation read as its own JSON so that
every quotation is verbatim. Nothing was compiled. Where a number could only be measured,
the plan says so and names the phase that measures it.

**Status:** not started. The owner has answered none of the questions in "Decisions this
plan needs"; Phase 0 cannot end without them, and Phase 1 cannot start.

**What it answers:** the PRD's standing open question, "Is there a second widget family or
a Control Center control worth having?" (`docs/PRD.md` §8), which has waited since
Iteration 1 for the widget's intent dispatch to be resolved. It was (README, "The widget's
one-tap logging — resolved"; ADR-0047).

---

## What this is, in one paragraph

The counter on the iPhone's Lock Screen: today's count, a ＋ that logs one drink the way
every other ＋ does, and a − that removes the newest one the way the watch's does, in the
three shapes the Lock Screen offers — a line above the clock, a circle and a rectangle
below it — so a reader places whichever fits their Lock Screen. It is the watch
complication brought to the phone, not a new design: the accessory families are the same
four the watch already draws (less the corner, which the phone does not have), the same
`WidgetKit` families, the same tile, the same words, the same intents, the same redaction.
Most of the code exists in `DrinkTrackerWatchWidget/CounterComplication.swift` and moves
to `Shared/`. What is new is the −, which no phone widget has had, and the platform's own
rules for the Lock Screen, which are stricter than a watch face's in one way (a locked
phone runs no widget button at all) and looser in another (a Lock Screen *control*, the
iOS 18 kind, runs while locked). A fourth, optional phase adds that control.

---

## What the platform allows

Verified, each with its source, because two of these change what "log from the Lock
Screen" can mean and one of them decides the whole design.

**The three shapes.** `WidgetFamily.accessoryInline`, `.accessoryCircular` and
`.accessoryRectangular` are iOS 16+ and watchOS 9+; `.accessoryCorner` is
`@available(iOS, unavailable)` — watchOS only (the SDK's `WidgetKit.swiftinterface`,
Xcode 27.0). Apple: "Your app can offer widgets on the Lock Screen in three different
shapes: as inline text that appears above the clock, and as circular and rectangular
shapes that appear below the clock." The inline family is "A flat widget that contains a
single row of text and an optional image." All three "can appear as a complication in
watchOS, or on the Lock Screen in iOS and iPadOS", and "Widgets on the iPad Lock Screen
require iPadOS 17 or later" — the app ships `TARGETED_DEVICE_FAMILY = "1,2"`, so the
iPad gets these too, unasked. (HIG "Widgets"; `WidgetFamily` reference pages; read
2026-09-23.)

**The Lock Screen is monochrome.** "The system displays vibrant widgets on the Lock
Screen on iPhone." Vibrant: "The system desaturates the widget, making a monochrome
version that it uses to create an adaptive, vibrant effect." The HIG: "The system uses the
vibrant rendering mode for widgets on the Lock Screen of iPhone and iPad, and on iPhone in
StandBy in low-light conditions. It desaturates text, images, and gauges, and creates a
vibrant effect by coloring your content appropriately for the Lock Screen background or a
macOS desktop." And how to draw for it: "In the vibrant rendering mode, the opacity of
pixels within an image determines the strength of the blurred background material effect."
"Render content like images, numbers, and text at full opacity. Use white or light gray
for the most prominent content and darker grayscale values for secondary elements to
establish hierarchy." Consequence: **the intensity band cannot be shown on the Lock
Screen**, exactly as it cannot on a tinted watch face, and the complication already has
the rule for that — `isTinted` is `widgetRenderingMode != .fullColor`, which is true of
`.vibrant` without a line changing (ADR-0046's 2026-09-18 amendment: grounds go
translucent, figures stay solid). What that treatment measures on a Lock Screen wallpaper
is not what it measured on a tinted Modular face; Phase 0 measures it.

**A locked phone runs no widget button.** Apple's own words, from "Adding interactivity to
widgets and Live Activities": "Widgets of the following sizes can include buttons and
toggles: systemSmall, systemMedium, systemLarge, systemExtraLarge, systemExtraLargePortrait,
accessoryCircular on iPhone and iPad, accessoryRectangular on iPhone and iPad" — the
inline family is not in the list, and the HIG says the same from the other side: "Note that
inline accessory widgets offer only one tap target." Then: **"On a locked device, buttons
and toggles are inactive and the system doesn't perform actions unless a person
authenticates and unlocks their device."** With Face ID, authentication happens on a
glance and the Lock Screen stays where it is — the padlock opens, the widgets do not go
anywhere (from use; Phase 0's item 3 confirms it on a passcode simulator) — so a ＋ on the
Lock Screen is one tap for the phone's owner and nothing at all for anyone else. That is a
feature, and the plan states it as one rather than working around it. It also means "log from the Lock Screen" and "log from a *locked* phone" are
different claims; the widget makes the first, and only a control (below) can make the
second. Also from that page: "By default, the system runs the app intent in the same
process as the widget extension" — the process ADR-0047 already reasons about — and
"Interactions with a toggle or button always guarantee a timeline reload."

**Controls, the iOS 18 kind, do run while locked.** "Perform your app's actions from
Control Center, the Lock Screen, and the Action button." A control is "a button or toggle
that provides quick access to your app's features from other areas of the system"; "On the
Lock Screen, a control displays its symbol." Whether it needs the phone unlocked is the
intent's own declaration, `AppIntent.authenticationPolicy`: `.alwaysAllowed` is "A policy
that allows the app intent to run at any time, including when the device is locked", and
`.requiresLocalDeviceAuthentication` "requires the person to unlock the device running the
intent". Apple's guidance is to require authentication "for actions that affect security"
and to "Hide sensitive information when the device is locked" (HIG "Controls"; the
WidgetKit "Creating controls" article: "For added privacy, require device authentication
before a control performs its action, as well as redact the text in a control when the
device is locked"). The SDK: `ControlWidgetButton(action: some AppIntent, label:)`, iOS
18+; a `ControlWidgetTemplate` takes `.tint`, `.privacySensitive` and `.disabled`; a
`ControlWidgetConfiguration` takes `.displayName`, `.description`,
`.promptsForUserConfiguration` and `.pushHandler`; `controlWidgetActionHint` is the Action
button's hint. The interface does not show what an intent's *default* policy is, so a
control's intent declares its policy explicitly. **From use, not from a source, and for
Phase 0 to confirm:** the Lock Screen's two bottom controls have always taken a
press-and-hold, which is what stops a pocket from logging a drink.

**Always-On and StandBy.** "Devices with the Always-On display render widgets on the Lock
Screen with reduced luminance. Use levels of gray that provide enough contrast in the
Always-On display" — the owner's iPhone 15 Pro has one, and no simulator does. StandBy
shows two `systemSmall` widgets, which is the existing home-screen widget, not this plan's.

**Sizes, as the HIG tables print them,** for the phones this app is likely to meet
(portrait screen → circular · rectangular · inline, points): 430×932 → 76×76 · 172×76 ·
257×26; 393×852 (the owner's 15 Pro) → 72×72 · 160×72 · 234×26; 375×812 → 72×72 ·
157×72 · 225×26; 375×667 → 68×68 · 153×68 · 225×26. The 402×874 and 440×956 screens of the
17 Pro and Pro Max are not in the table. These are the widget's frames, not its content;
the content box after the system's insets is what the row is drawn in, and — the watch's
lesson, fourteen widths where one was assumed — **it is read from the view's own
`GeometryReader` and pinned at tier 1, never taken from a table.**

**What cannot be verified from here** is in the last section. The largest item is the
"Lock Screen Widgets" switch under Settings → Face ID & Passcode → Allow Access When
Locked: what it does to a privacy-sensitive count on a locked phone is a Phase 0
observation on a passcode-locked simulator, not a sentence in any page read today.

---

## Decisions this plan needs

Each is the owner's, each has a recommendation, and Phase 1 does not start until all
seven are answered — in the design bundle's README (the watch's route), or as a dated
block under this heading.

1. **Which shapes.** All three: the inline line, the circle, the rectangle. *Recommended.*
   The user picks the one that fits their Lock Screen; that is what "customize the sizes"
   means on this platform, because the sizes themselves are the system's. (A widget whose
   *content* is configurable — which drink ＋ logs, what the circle shows — is a different
   thing, refused twice already: PRD §8's "Should the widget's defaults ever be
   configurable?" and README "Not built". Its reopen path is unchanged: an ADR that says
   why the fast-path argument no longer holds.)

2. **What the circle holds.** The face's own tile — the count in a rounded mark, no ＋ —
   or the whole circle as a ＋ with the count inside it. *Recommended: the tile.* A 72pt
   circle cannot hold a figure and a 44pt target beside it (the watch design's second
   question, which the owner answered the same way), and a circle that *is* the button
   makes the figure the reader is looking at the thing their thumb lands on. The ＋ and
   the − live on the rectangle. ADR-0046's reopen path stands: "the whole circle becomes
   the button and the count goes."

3. **The − on the rectangle, under ADR-0043's rule, and whether the home-screen widget
   takes the same −.** The rule, unchanged from the watch: − removes today's newest entry
   when it carries no Health sample and is not a mirror, never skips to an older one, and is
   drawn dimmed otherwise. *Recommended: yes, and yes.* The home-screen widget's own comment
   says there is "deliberately no − here" because removing an entry must retire its Health
   sample and "only the app process does that reliably" — the objection ADR-0043 answered
   for the watch, whose extension-like limits are the widget's. Two phone widgets that
   disagree about − would be one more thing to explain. **The cost, stated:** on a phone
   with Health on, an entry logged in the app gets its sample at save, so the − is dimmed
   for it; an entry logged from the widget keeps no sample until the app next comes to the
   foreground, so a mis-tap on the Lock Screen has its − until then. The watch has lived
   with exactly this since 2026-09-14, and the tombstone reopen path is still ADR-0043's.

4. **A control.** Build "Log a drink" as a Lock Screen, Control Center and Action button
   control, its intent declared `.alwaysAllowed` so it logs from a locked phone. *Recommended:
   yes, as Phase 3, its own ADR, its own decision.* It is the only route that logs without
   unlocking, it costs no widget slot, and the Lock Screen's press-and-hold is the accident
   guard the widget's tap does not have. **No "Remove a drink" control.** A removal from a
   locked phone with no count in sight is a removal the reader cannot see, which is the
   thing ADR-0043 refuses by another door; the − sits beside the count or nowhere. If the
   owner wants the control to require unlocking instead, it is one enum case and the ADR
   records the cost (a control that unlocks first is the widget's tap with a longer press).

5. **No session dots on the Lock Screen.** *Recommended.* The dots exist to carry the
   band's colour (ADR-0044), and vibrant rendering keeps no colour; grey dots would be a
   count of the sitting on the most public surface the phone has, which ADR-0046 refuses on
   the face for the same reason. The phone's session surface is Today's chip. `SessionDots`
   is already in `Shared/`, so the reopen is one flag, not a move.

6. **Which train.** *Recommended: the first feature of the train after 1.4* — a 1.5 spec
   opened by its first PR, the way the 1.3 and 1.4 specs were. 1.4 carries two release
   phases that have not run (the watch's Phase 8, the pairing's Phase 7) and one decision
   about what it contains; a third feature on it is a third What's New paragraph and a third
   set of reviewer notes on a version that already needs a ruling. If the owner wants it in
   1.4 anyway, Phase 4 of this plan folds into those two release phases and nothing else
   changes.

7. **The design.** Either the face's design transfers as it stands — the tile from
   `docs/design/watch/circular-complication-handoff.md`, the card row from
   `docs/design/watch/README.md`'s `accessoryRectangular` row, both as amended by ADR-0046
   — and only what is new gets drawn (the −'s disc beside the ＋, the row's second line,
   the vibrant grounds, the control's symbol); or the owner drops a fresh bundle into
   `docs/design/lock-screen/` on the established route (a `.dc.html` canvas and a README
   with its open questions answered at the end). *Recommended: transfer, and draw the
   three new things.* What the drawing must settle is in Phase 0.

---

## Rules that survive to the Lock Screen

The seven constraints in `docs/tallyist-1.2-spec.md` ("Project constraints": no accounts,
no servers, no goals or streaks or scores or advice, no data between users, no
consumption guidelines; report never instruct; every new behavioural surface optional and
off or neutral) hold unchanged. Paste them into every session. The ones that bite
differently here:

- **Rule 3, no goals or streaks.** A Lock Screen widget sits above a person's
  notifications every time they lift the phone, all day: the most persistent surface the
  phone has, more than the Home Screen, which is one swipe further away. The temptation is
  the same as the face's — a standing number that reads as a score — and the answer is
  the face's (ADR-0046): **today's count and nothing else**, resetting at midnight, no
  session count, no total, no streak, no ≈ figure.
- **Rule 7, optional and off.** There is no switch to add: a widget nobody places shows
  nothing, and placing it is the choice. **No new setting.**
- **ADR-0017's three hard rules** are unchanged: no running time-without-a-drink outside a
  session, no longest-gap record persisted, no notifications. A Live Activity for a sitting
  — a session count standing on the Lock Screen all evening — is the second rule's failure
  mode on a new surface. Do not build it, not behind a toggle.

And the invariants in `docs/PRD.md` §2 this work touches:

- **Invariant 1, one tap.** The ＋ is `LogOneDrinkIntent`, the counter's mirror, reading
  the seed and the region from the App Group; a fourth surface making the same claim, with
  no new argument. The − is `LoggedDrink.removableNewest` through **one implementation**
  shared with the watch (ADR-0042's pattern for the seed), never a copy in a view or an
  intent. **Neither intent may ever take a promptable parameter** — the widget's dispatch
  bug (README) is why `LogOneDrinkIntent` has none, and a Lock Screen tap can answer a
  question even less than a Home Screen tap can.
- **Invariant 3, region is a lens.** `AppSettings.storedRegion()`, as the widgets already
  read it. The Lock Screen prints a count of drinks and no unit figure, so there is nothing
  here for a region to get wrong; the day's *band* would be region-lensed, and vibrant
  rendering does not draw it.
- **Invariants 4 and 5, one App Group, one configuration.** No new process, no new
  identifier, no new container: the Lock Screen widget is a second `Widget` in the existing
  iOS widget extension, which opens the store through `SharedModelContainer.make()` like
  every other caller and holds no iCloud container (ADR-0047's refusal stands: one process
  manages sync on the phone, and since ADR-0055, proposed, on the watch too). A drink
  logged on the Lock Screen reaches CloudKit only through the app's own mirroring, exactly
  as a drink logged on the Home Screen widget does today; when is not documented (the
  2026-09-24 note under "Reloads, and what reaches the watch").
- **Invariant 6, Health follows the log.** The extension has no HealthKit and gets none;
  the − removes only what Health does not own (ADR-0043). Nothing in this plan writes,
  reads or retires a sample.
- **Invariant 8, copy.** The reviewed strings are reused where they fit ("drinks today",
  "drink today", "Recorded as no alcohol today", "Log one drink", "Tallyist", "See today's
  count and log a drink in one tap."). The new ones — the −'s spoken label, the Lock Screen
  widget's gallery description, the control's name, description and hint — go through
  `docs/copy-review-1.4.3.md` before the PR. House voice: factual, no celebration, no
  exclamation marks, no em dashes in microcopy (the owner's 2026-09-23 rule).
- **Invariant 9, the domain stays pure.** The card's geometry is a table in
  `DrinkTrackerCore` (`LockScreenCard`, on `ComplicationCard`'s pattern), pinned at tier 1
  against every content width Phase 0 reads.
- **Invariant 10, validated, never eyeballed.** Vibrant rendering keeps no hue, so the
  ramp is not at issue; **contrast is.** The tile's ground, the numeral, the −'s and ＋'s
  discs are measured from screenshots over a light and a dark wallpaper, the way the
  tinted face was (ADR-0046's amendment has the method), and the numbers go in the ADR.
- **ADR-0045's general rule, private wins.** Every count is `.privacySensitive()`;
  redacted, each family shows the drop glyph and the plural words with the figure gone,
  never a blank, and the spoken label follows the pixels (ADR-0046's second review round).
  The Lock Screen adds nothing to that posture and takes nothing from it: the phone's lock
  is the hide, and the buttons are inert on a locked phone by the platform's rule.
- **ADR-0047, never a figure it did not read.** A missing App Group, a store that does not
  open or a read that fails draw the unavailable state — the glyph, the words, no figure,
  no ＋, no − — with a retry in fifteen minutes. The complication's provider already does
  this; moving it brings it along.
- **No `Timer`, no minute-level `TimelineView`.** Without a session on this surface the
  timeline is one entry and a refresh at midnight; the app's `WidgetReloads` and the
  intents' own `reloadAllTimelines()` do the rest.

---

## Architecture

### The Lock Screen widget is the complication, moved

`DrinkTrackerWatchWidget/CounterComplication.swift` holds three things: the `Widget`
(`CounterComplication`, kind `"CounterComplication"`, four families), the timeline
(`CounterEntry`, `CounterProvider` with its `Snapshot` and `load(at:)`), and the view
(`CounterComplicationView` with `tile(side:)`, `disc`, `figure`, the four family bodies, the
redaction and tint rules and the spoken label). The second and third move to `Shared/` —
two files, `Shared/AccessoryCounterProvider.swift` and `Shared/AccessoryCounterView.swift`
(names are the phase's to settle) — compiled into the **iOS widget extension and the watch
complication only**, a membership pair the verifier's `SHARED_EXTRAS` table names, the way
`SessionDots.swift` is compiled into the two watch targets and nothing else. The `Widget`
structs stay where they are: `CounterComplication` on the watch, unchanged in behaviour and
pixel-identical on the 46mm (Phase 1 proves it the way the card's wrap did); and a new
`LockScreenCounter: Widget` in `DrinkTrackerWidget/`, kind `"LockScreenCounter"` — the
identity of every placed widget across updates, never renamed once shipped — with
`.supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])`, added
to `DrinkTrackerWidgetBundle` beside `QuickLogWidget()`.

Two things need a platform fence in the moved code: the corner family (`case
.accessoryCorner` does not compile on iOS) and the session — `Snapshot.showsSession` is
the watch's switch on the watch and `false` on iOS by decision 5, so the phone's own
`showsSessionPace` key, which shares a name with the watch's, is never read here.

**Why a second `Widget` and not three more families on `QuickLogWidget`.** The shipped
widget stays byte-for-byte what it is, placements and code; a Lock Screen gallery shows
only widgets with accessory families and a Home Screen gallery only those with system
families, so each kind appears in exactly one gallery either way; and the Lock Screen
widget is the *face's* twin — same tile, same provider, same redaction — not the Home
Screen widget's, whose entry has no marker, no unavailable-with-＋ rule and a different
numeral.

### The −

`RemoveOneDrinkIntent`, in `Shared/LogDrinkIntent.swift` beside `LogOneDrinkIntent`,
parameterless, `openAppWhenRun` false, and `isDiscoverable` **false**: it is the widget's,
as `LogDrinkIntent` is, and a Shortcuts action that removes a drink was not asked for (the
reopen is one line). It calls a new repository function, lifted from the watch's
`CounterView.removeNewest()` so there is one implementation:

    DrinkRepository.removeRemovableNewest(on day: Date) throws -> RemovalOutcome
    // .removed(LoggedDrink) · .nothingToday · .keptByHealth(LoggedDrink)

— `drinksOrThrow(on:)`, then `LoggedDrink.removableNewest(in:on:)`, then
`deleteOrThrow(id:)`, decided from the store at execution time and never from the entry
the button was drawn with (ADR-0043: "never from a captured snapshot"). The watch's −
becomes a call to it; its haptics and toasts stay in the view. Tier 2 pins the outcomes.
The intent's breadcrumbs follow the ＋'s shape — `entered (remove-one)`, `removed
(remove-one)`, `kept (remove-one) · health`, `nothing to remove (remove-one)`, `failed
(remove-one): …` — and it does **not** write `lastIntentBuild`, which is the ＋'s bisect
key (ADR-0047's table reads it for the ＋; a second writer would erase the evidence).

On the card, the − is a 44pt `Button(intent: RemoveOneDrinkIntent())` drawing `minus`,
`.disabled` and dimmed when the entry's `canRemove` is false — the entry reads
`removableNewest` at build time for the drawing, the intent re-reads it at the tap. No
toast, because a widget has none: the count is the receipt, and the dimmed disc is the
refusal, which is the cost ADR-0043 already accepted for a reader who never touches it.

### Reloads, and what reaches the watch

The −'s `perform()` ends with `WidgetCenter.shared.reloadAllTimelines()` like the ＋'s; the
system reloads after any button regardless; the app's `WidgetReloads` — on its own saves,
on a CloudKit import landing, on leaving the foreground — reloads *all* timelines, so the
new kind is covered without a line. What does not change: a drink logged in the extension
reaches CloudKit, and so the watch, only through the app's own mirroring (ADR-0047's
residual; the app-process intent is the owner's undecided route and is not this plan's).

**Note, 2026-09-24 (ADR-0055, proposed until the owner accepts its cost and its PR
merges).** Both hosts of the shared provider are now extensions that do not mirror: the
iOS widget extension by ADR-0047, and the watch complication by ADR-0055, which took the
iCloud container, CloudKit and `aps-environment` off it so that on each device the app
is the one process that mirrors the store. The moved code therefore opens the store the
same way in both hosts, and `scripts/verify-watch-setup.py` fails CI if either extension
regains the container. This plan first said a Lock Screen drink "exports when the app
next runs", which is more than is documented. TN3163 names a context save, or a
remote-change notification the running app observes, as what schedules an export;
nothing documented makes the app export on launch, and no device has yet shown how soon
an extension's write is exported. ADR-0055's device check, on a TestFlight build, is the
first reading of that case, on the watch; a Lock Screen drink is the phone's instance of
it, as a Home Screen widget drink already is.

### Vibrant, redaction, unavailable

`isTinted` is true under `.vibrant`, so the grounds are the translucent `.quaternary` and
the figures `.primary` — but the HIG's rule that pixel *opacity* drives the material means
a `.quaternary` tile on the Lock Screen is a faint pane over the wallpaper, not the
`#252526` it measures on a black face. Phase 0 measures the tile, the numeral and both discs
over a light and a dark wallpaper and, if the ground vanishes, tries
`AccessoryWidgetBackground()` (the corner family's ground) or an opaque grey, as the HIG
directs — a ground change the ADR records with its numbers. Redaction and the unavailable
state come with the moved view; what the "Lock Screen Widgets" access switch does to
`.privacySensitive()` content is observed in Phase 0 and written down.

### Copy and catalogs

Reused keys are listed under invariant 8. The moved view brings "Recorded as no alcohol
today" into the iOS widget's catalog (it is in the complication's, not the widget's — 35
keys each, 2026-09-23). New keys: the −'s label, the Lock Screen widget's description if it
differs from the shared one, and the control's three strings. Sync with `xcstringstool`
from a fresh full build into a scratch copy and diff before copying in — the route every
recent phase used — and count the keys rather than trusting this paragraph.

### Diagnostics

The widget timeline already records each build and what it read (`widget: read N · mode`).
The Lock Screen widget's builds should say which kind (`lock: read …`), so a stale count on
one surface can be told from the other. A control's tap writes the ＋'s own line, `intent:
entered (one-drink) · <process>`, and the process label is how Phase 0 learns whether a
control's intent runs in the extension as a widget's does.

---

## Phases

One session each. Paste "What the platform allows", "Decisions this plan needs" (with the
owner's answers), "Rules that survive to the Lock Screen" and the 1.2 constraints every
time. Every phase ends with CI green, the phase's own tier-3 list rendered
and stated with numbers, a done-note at the head of its section here, and a bullet in
CLAUDE.md's Current state.

### Phase 0 — the platform, measured, and the design

Research and a scratch build; **no product code**, no file in `DrinkTracker/`, `Shared/`
or `DrinkTrackerCore/`, no `project.pbxproj` edit. A local session with the toolchain — a
remote one cannot do this phase.

Build a scratch copy of the tree (an `rsync` copy under `$TMPDIR`, never the worktree —
the watch's rule, so scratch code cannot reach a commit) with the complication's view
compiled into the iOS widget under a throwaway `Widget` with the three families, install
the **signed** build on a throwaway iPhone 17 Pro simulator on iOS 27 (never the working
pair, never the Phase 7 scratch simulator; `simctl clone` is not isolation — CLAUDE.md,
2026-09-23), and answer, each with its evidence:

1. **The content boxes.** The width and height each family gives the view, from a
   `GeometryReader` line written to the Diagnostics timeline, on the 17 Pro (402pt) and
   on the widest and narrowest phones the simulators offer (the 17 Pro Max; the 17e or
   whichever is narrowest — there is no 375pt simulator on this Mac, so that class is
   computed from the HIG's frame and the measured inset, and said so). The row this plan
   proposes needs 140pt at the watch counter's 4pt gaps (three 44s) or 148 at 8; the
   HIG's frames are 153 to 172 wide and 68 to 76 tall.
2. **Vibrant contrast.** The tile's ground, the numeral, the ＋'s disc and the −'s disc
   over a light and a dark wallpaper, read from screenshots by script (the method in
   ADR-0046's 2026-09-18 amendment), at 0, 1, 16 and 100, on a marked day, and redacted.
   The numeral wants 4.5:1; if the `.quaternary` ground is invisible, try the two grounds
   the architecture names and record all three.
3. **Locked, and unlocked on the Lock Screen.** Set a passcode on the simulator (Settings
   → Face ID & Passcode), lock it with the tool's `LOCK` button, tap the ＋: the store must
   not change (Apple's rule). Then authenticate — the Simulator's Face ID enrolment and
   match are menu items the tool cannot reach; the `notifyutil` route (`xcrun simctl spawn
   <udid> notifyutil -p com.apple.BiometricKit_Sim.pearl.match` after enrolling) is
   reported to work and is unverified here — and tap again: one new row, read back with
   `sqlite3 'file:…?mode=ro'`. State which route worked.
4. **The access switch.** Face ID & Passcode → Allow Access When Locked → Lock Screen
   Widgets, off then on: what a `.privacySensitive()` count shows on the locked Lock
   Screen in each state, and whether the whole widget disappears. Frames of both.
5. **The inline family**, which no session has rendered anywhere: the drop glyph as a
   template image, "3 drinks today", the marker sentence, the redacted form.
6. **A control**, if decision 4 is yes: a `ControlWidgetButton` performing
   `LogOneDrinkIntent` with `.alwaysAllowed`, placed in Control Center and in a Lock Screen
   slot (Customize → the bottom controls). Locked: does a press-and-hold log? Does a tap?
   What does the Lock Screen draw (the symbol alone, per the HIG)? What does
   `.requiresLocalDeviceAuthentication` do instead? The breadcrumb's process label.
7. **The iPad Lock Screen** on an iOS 27 iPad simulator: the three families' boxes, and
   whether the row fits them.
8. **Bold Text and Larger Text** on the Lock Screen: whether accessory widgets follow
   Dynamic Type at all (the watch's did not need to know), read from the boxes.

Write the answers to `docs/lock-screen-phase-0-findings.md` in the register of
`docs/health-pairing-phase-0-findings.md`: what is true, how it was checked, what it
forces. Commit any design bundle the owner dropped (`docs/design/lock-screen/`). Branch
`claude/lock-screen-phase-0`, draft PR, CI, merge.

**What the design must settle**, whichever route decision 7 takes: the rectangle with a
drink logged today (this plan proposes − · tile · ＋ at the watch counter's 4pt gaps over
one line of the day's words, 44pt tall over an 11pt line, which fits every frame in the
HIG's table with room to spare — measured, not assumed, in item 1); the rectangle on an
empty day and on a marked day (proposed: the face's own card, tile · words · ＋, no −,
since there is nothing to remove — which means the row changes shape between 0 and 1, a
cost like the watch card's singular/plural one); the dimmed −; the circle (the face's
tile); the inline line; the redacted state of each; the control's symbol (`tally.standard`
is the app's own drop, and custom symbols are allowed).

### Phase 1 — the shared accessory layer, and the three families

The move, the second `Widget`, the memberships. ADR-0054 (or the next free number), "the
Lock Screen shows what the face shows".

- Move `CounterEntry`, `CounterProvider` and `CounterComplicationView` into `Shared/` with
  `#if os(watchOS)` around the corner family and the session read; `LockScreenCounter` in
  the iOS extension; the bundle. `Widget` names, kinds and the watch's four families
  unchanged.
- **Project-file work, and the standing rule for it** (CLAUDE.md): a local session, the
  `Edit` tool one exact anchor at a time, never a script over the file; two `Shared/`
  memberships per new file; verified by `plutil -lint`, `xcodebuild -list`, both schemes
  built for their simulators, and `scripts/verify-watch-setup.py` green — after adding the
  two files to its `SHARED_EXTRAS` table with the two targets, which is what makes a file
  forgotten on one surface fail rather than compile.
- Grounds and sizes from Phase 0's numbers; `LockScreenCard` in the core package with the
  measured widths as its table, tier-1 tested (the row's fit, the fold to the face's card,
  the gap).
- The iOS widget catalog synced (the marker sentence arrives; the description if new).
- **Tier 3:** the three families placed on the throwaway simulator's Lock Screen over a
  seeded store, in the states Phase 0 listed, light and dark wallpaper, redacted, and the
  unavailable state from a damaged scratch store; the ＋ from the rectangle after
  authenticating, read back from the store; the home-screen widget untouched. **And the
  watch, pixel-identical:** the 46mm face and the emulated Smart Stack boxes, `main`
  against the branch, in the ten states the card's wrap used — a move that changes one
  pixel on the watch is a defect.
- The iPad simulator, once, for fit.

### Phase 2 — the −

`RemoveOneDrinkIntent`, `DrinkRepository.removeRemovableNewest(on:)`, the watch's −
re-routed through it, the − on the rectangle, and — by decision 3 — the same − on
`QuickLogWidget`'s small and medium families. ADR-0055 (or next), "the phone's widgets
remove what Health does not own", which supersedes the widget's "deliberately no −"
comment and cites ADR-0043 rather than re-arguing it.

- **Tier 2** (`DrinkRepositoryTests`): nothing today → `.nothingToday`, store unchanged;
  newest carries a sample → `.keptByHealth`, both rows stay; newest is an import →
  `.keptByHealth`; a removable newest behind an older sampled one → `.removed`, the older
  one stays; a failed read throws and nothing changes (`FailedReadTests`' damage-and-restore
  shape). The watch's − has no test today; it gains these by sharing the function.
- **Tier 3:** ＋ then − on the Lock Screen, the count 0 → 1 → 0 and the store agreeing;
  a newest row given a `ZHEALTHKITSAMPLEID` with `sqlite3` dims the −, and a tap on it
  changes nothing (`kept … · health` in the timeline); a marked day shows the face's
  card; the same on the home-screen widget; the watch's − still dims, refuses with its
  toast and removes, on the simulator pair. Both appearances, redacted.
- Copy review for the −'s spoken label ("Remove one drink" is the proposal, the mirror of
  "Log one drink"; the app's counter is one VoiceOver-adjustable element rather than two
  labelled buttons, so there is no phone string to match — the review settles the wording).

### Phase 3 — the control (optional, decision 4)

`LogDrinkControl: ControlWidget` in the iOS bundle: `StaticControlConfiguration(kind:
"LogDrinkControl")` around a `ControlWidgetButton(action: LogOneDrinkIntent())` labelled
with the drop and "Log a drink", `.controlWidgetActionHint` for the Action button, and
`LogOneDrinkIntent` declaring `authenticationPolicy` as the owner ruled — which also
applies where that intent already runs (the widgets, where the platform's lock rule wins
anyway, and Shortcuts). ADR-0056 (or next), "a control logs one drink from a locked phone".

- **Tier 3:** the gallery entry; Control Center; a Lock Screen slot; locked, the
  press-and-hold logging one row and the breadcrumb naming the extension; the Action
  button's hint (the simulator has no Action button — tier 4).
- No value provider and no reload: a button control has no state to show. If the owner
  later wants the count *in* the control, that is a `ControlValueProvider` reading the
  store and a reload after every write — a second surface printing the count, and its own
  decision.
- Copy review for the name, description and hint; the control's `privacySensitive` for
  its title is moot (the title is a verb phrase), stated in the ADR.

### Phase 4 — release

The lightest release phase of the three plans, because nothing new is read about a
person; it is still a new surface App Review will see.

- **The privacy policy**, three copies, one commit, the date bumped (ADR-0024; the
  `policy-copies` job enforces the two in-repo copies): its widget bullet reads "**The
  widget.** The home-screen widget shares the app's on-device storage." and becomes the
  widgets and the control, still on-device storage, still nothing else. `docs/support.md`'s
  "The home-screen widget logs one drink without opening the app, the same way." follows.
- `docs/app-store-listing.md`: the description's "from the app or the home-screen
  widget"; What's New for the train it ships on (the owner's own shorter register, per the
  2026-09-23 note on 1.3's); reviewer notes saying what the Lock Screen widget does, that
  its buttons follow the platform's lock rule, what the − will and will not remove, and
  what the control does while locked; the spec's claims table gains the rows.
- App Privacy stays **Data Not Collected**: confirm against the manifests, and say so in
  the reviewer notes.
- `docs/design-system.md`: a "Lock Screen widget" row beside the two complication rows;
  the Widget row gains the −. README's widget sections and "Not built"; `docs/PRD.md`
  invariant 1's wording ("one from the widget" is now two widgets and a control); CLAUDE.md.
- The owner's screenshots, if the listing shows the Lock Screen; every in-app screenshot
  is already stale since the tab bar.

---

## ADRs

Three, numbered when written (0054 is the next free number on 2026-09-23; the watch took
the health plan's reserved numbers once, so take the next free one, not these):

- **The Lock Screen shows what the face shows** — Phase 1. The three families as the
  complication's; today's count and nothing else; no band under vibrant rendering, with
  the measured contrast; no session dots; the tile in the circle; the row with the −; the
  platform's lock rule stated as the design's privacy argument; the iPad; the reopen paths
  (the whole-circle ＋, dots, a ground change).
- **The phone's widgets remove what Health does not own** — Phase 2. Extends ADR-0043 to
  the iOS extension, supersedes the "no −" comment in `QuickLogWidget` and
  `LogOneDrinkIntent`, records the cost (dimmed after the app foregrounds with Health on)
  and keeps the tombstone as the reopen.
- **A control logs one drink from a locked phone** — Phase 3, if built. The
  authentication policy and why `.alwaysAllowed` is not "an action that affects security";
  no remove control, and why; the press-and-hold as the accident guard; the reopen to
  `.requiresLocalDeviceAuthentication`.

---

## Testing

| Tier | What lands there |
|---|---|
| 1, domain | `LockScreenCard`: the row's fit at every measured width, the fold to the face's card, the gaps. `ComplicationTile` and `ComplicationCard` unchanged and still green. |
| 2, repository | `removeRemovableNewest(on:)`: the three outcomes, order independence, the failed read. |
| 3, simulator | Everything in the phases' lists: the three families in every state over two wallpapers, the lock rule, the access switch, the −, the control, the unavailable state, the iPad, and the 46mm watch pixel-identical to `main`. |
| 4, device | The real Lock Screen with Face ID's timing; Always-On's reduced luminance on the 15 Pro; the − dimmed after the app foregrounds with Health on and live after a Lock Screen ＋; the control from a locked phone and from the Action button; an evening's worth of pocket time for accidental taps; the widget on a second, Focus-linked Lock Screen. |

The lock rule is the check that matters most and is easiest to fake: a simulator with no
passcode is never locked, so item 3 of Phase 0 is meaningless without one.

---

## Working the phases in Claude Code

The repo's method: one phase per session in a worktree, branch → draft PR → CI green →
merge, merge commits only. The owner's script takes any branch:

    WT_PATH=~/DrinkTracker-lock ./scripts/watch-worktree.sh claude/lock-screen-phase-0

and re-points it between phases. Phases 0 to 2 are a chain; Phase 3 can run beside Phase 2
once Phase 1 has landed, but both edit `Shared/LogDrinkIntent.swift` (the − adds an intent,
the control adds one declaration to `LogOneDrinkIntent`), so whichever lands second
re-merges main first — a textual conflict, not a design one; Phase 4 is last. Every phase is a local session: Phase 0 needs a simulator, Phase 1 needs the project
file, and the rest need a render.

The gate at the end of every phase, in order: the CI jobs (domain, the iOS build — which
compiles the widget extension and the watch targets — the watchOS build, integration, the
policy dates, the glyphs); the phase's tier-3 list rendered, with the numbers in the
commit message; the adversarial review the watch's Phase 5 and the health pairing used
before every PR (each finding put to two skeptics, and the records read against the code
— it found real defects every time it ran); the done-note here; the CLAUDE.md bullet.

The block to paste for a session, on the health pairing's pattern (its prompts document is
the model for the full form):

    You are running Phase N of the Lock Screen widget for Tallyist. I am the lead; you
    are executing a defined scope.
    READ FIRST: CLAUDE.md; docs/PRD.md's ten invariants; docs/tallyist-lock-screen-plan.md
    — "What the platform allows", "Decisions this plan needs" with my answers, "Rules that
    survive to the Lock Screen", and Phase N; docs/tallyist-1.2-spec.md "Project
    constraints"; docs/lock-screen-phase-0-findings.md (from Phase 1 on — where it and
    the plan disagree, the findings win).
    BUILD: what Phase N's section says, and nothing it does not.
    HARD STOPS: no promptable parameter on any widget or control intent; no HealthKit in
    the extension; no new setting; no session number or Live Activity on the Lock Screen;
    no `Timer`; project.pbxproj only as CLAUDE.md allows and only in a local session;
    scratch builds from a copy of the tree, never the worktree; never the working
    simulator pair or the Phase 7 scratch simulator. Never a model identifier in anything
    pushed: the trailer is Co-Authored-By: Claude <noreply@anthropic.com> plus the session
    link. Merge commits only.
    REPORT BACK: the tier-3 list with the observed numbers, what was not verified and why,
    the PR URL and CI status, and anything that contradicts the plan.
    If something is ambiguous, say so and stop.

**Simulator notes for these phases,** gathered from the earlier passes (CLAUDE.md has the
long forms): the simulator tool's per-device permission can go unanswered for a whole
session — retry, and plan the render so that screenshots by `simctl io screenshot` and
store reads by `sqlite3 'file:…?mode=ro'` carry it; a scratch store takes rows from
`sqlite3` directly; a `CODE_SIGNING_ALLOWED=NO` build has no entitlements and traps on the
CloudKit probe, so build signed; an `xcodebuild` aimed at a booted simulator can restart
its daemons, so relaunch rather than debug; the tool's `LOCK` button locks the phone;
placing a Lock Screen widget is a long-press on the Lock Screen → Customize → Lock Screen
→ the widget area → the app → the family → Done, all taps; the Lock Screen's wallpaper
and colour are set in the same editor, which is how the two contrast grounds are made.

---

## Things this plan explicitly does not need

- **A configurable widget** (`AppIntentConfiguration`, a drink or a size chosen per
  placement). Refused in PRD §8 and README "Not built"; the seed setting (ADR-0023) is the
  configuration, on every surface at once.
- **A Live Activity for a sitting.** ADR-0017's second hard rule on a new surface.
- **The session count anywhere on the Lock Screen**, or dots. ADR-0046, decision 5.
- **A tap-to-hide.** The lock is the hide; the watch's per-glance hide was the owner's
  answer to a surface that never locks (ADR-0045).
- **The watch card's −.** Not asked; the watch has its counter. The rectangle's − is the
  phone's.
- **Notifications, of any kind.** ADR-0017's third rule.
- **A redesign of `QuickLogWidget`** beyond the − of decision 3. Found in passing and left
  alone: that widget reads no `widgetRenderingMode`, so what iOS 18's tinted Home Screen
  (`.accented`) and StandBy's low-light `.vibrant` make of its `.quaternary` disc and
  accent tint has never been rendered. Its own pass, if the owner wants one.

---

## What I could not verify

Stated plainly, as the two earlier plans do.

- **Nothing was compiled or rendered.** The moved code's `#if os(watchOS)` fences, the
  second `Widget` in the bundle, the `Button` in an accessory family under vibrant
  rendering — all written from the shipped code's shape and Apple's pages. Phase 0's
  scratch build is where they meet a compiler.
- **The content boxes.** The HIG's frames are quoted; the boxes the view is given are not
  known, and the 402pt and 440pt phones are not in the HIG's table at all. The row's
  arithmetic (140pt at 4pt gaps) is against frames, not boxes.
- **Vibrant contrast of the shipped treatment on a wallpaper.** The 9.18:1 and 11.55:1
  of the tinted face were measured on a flat black face; a translucent ground over a
  photograph is a different measurement, and the HIG's guidance is written for opaque
  greys.
- **What "Lock Screen Widgets" under Allow Access When Locked does** to a
  `.privacySensitive()` count. No page read today says; the passcode simulator does.
- **Face ID on the simulator from the tool.** The enrolment and match are Simulator menu
  items; the `notifyutil` route is from community reports.
- **That the Lock Screen's bottom controls take a press-and-hold**, and what a control's
  intent with `.alwaysAllowed` does on the Lock Screen while locked. Apple's page says a
  control can be made to require authentication; it does not say what one that does not
  require it does there. From use, they run.
- **An intent's default `authenticationPolicy`.** The interface hides the getter's body.
  The plan declares the policy rather than relying on the default.
- **Whether a control's intent runs in the extension** as a widget's does. Apple says so of
  widgets; the process label in the breadcrumb answers it for controls in Phase 0.
- **The store before first unlock after a restart.** A widget built between a reboot and
  the first unlock reads a store whose file protection this repo has never set explicitly;
  it either reads or draws the unavailable state, and only hardware can show which. The
  owner's device pass, once, after a restart.
- **The iPad Lock Screen** — rendered in Phase 0 on a simulator, never on hardware; the
  owner has none in this project's record.
