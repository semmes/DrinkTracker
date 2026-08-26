# Drink Tracker — how we iterate

**Status:** active · **Supersedes:** the design brief and design plan referenced by
early commits, neither of which is in this repository.

This document is the durable source of truth for what Drink Tracker is, what it
refuses to be, and how a change to it gets proposed, verified, and recorded. The
README tells you how to build and run the app. This tells you how to change it.

It cites code by file and symbol rather than by line number, on purpose: line numbers
in a long-lived document are drift waiting to happen, and drift is one of the problems
this document exists to fix.

---

## 1. What this is

**North star:** an accurate answer to *how much am I actually drinking*.

Everything follows from the word *accurate*. Friction produces under-logging, and
under-logging makes the answer a lie. That is why logging is one tap on Today's
counter and one from the widget, why every control in the drink sheet is optional
refinement rather than a gate, and why corrections are as cheap as the original log.

**What it refuses to be**, and where each refusal is currently upheld:

| Refusal | Upheld in |
|---|---|
| No account, no sign-in | `RootView` routes onboarding straight to Today; identity is the user's existing iCloud account |
| No goals, no targets | `TrendsView` — the chart's rule mark is labelled "Your average", never a limit |
| No streaks, no congratulation, no warning | `TrendsView.summaryCards` counts days without framing them as wins; `SettingsView.aboutSection` says so in as many words |
| No celebratory framing of volume | [ADR-0001](decisions/0001-repeat-logging-is-not-party-mode.md) |
| No blocking on a failed dependency | `HealthKitService` fails silently; the log lives in SwiftData regardless |

These are not stylistic preferences. App Store guideline 1.4.3 rejects apps that
encourage excessive alcohol consumption, and on a drink-tracking app the framing is
what gets reviewed. See [ADR-0001](decisions/0001-repeat-logging-is-not-party-mode.md)
for the full reasoning; it applies to every user-visible string, not just the one that
prompted it.

---

## 2. Invariants

The rules a change must not break. Each one's failure mode is stated because most of
them fail *silently* — that is precisely why they are written down.

**1. The fast path is one tap in the app, one from the widget.**
`TodayView`'s counter acts on the log directly: plus records a seeded drink, minus
removes the most recent (undoable). The typed path (`quickAddRow` →
`DrinkDetailSheet` → Log) sits one persisted disclosure deeper for those who want
size and strength — see [ADR-0009](decisions/0009-count-first-logging.md).
`QuickLogWidget` logs the type's default outright.
*Failure mode:* every added step is paid in entries that never get logged, which
defeats the north star.

**2. Edit-after, not gate-before.**
The type picker and time control appear only when editing an existing entry or adding
one retroactively — `DrinkDetailSheet.showsTimeControl`.
*Failure mode:* a control added "just for completeness" to the quick-add path is a tax
on the most common action in the app.

**3. Region is a display lens, never frozen onto an entry.**
Entries record the region they were logged under as provenance, but totals are always
computed in the *current* region — `LoggedDrink.standardDrinks(in:)`,
`AppSettings.effectiveRegion`.
*Failure mode:* freezing per-entry units makes any total a sum of UK units and US
standard drinks, which is not a number that means anything.
See [ADR-0002](decisions/0002-region-is-a-display-lens.md).

**4. App Group identity is computed, never written as a literal.**
`AppGroup.identifier` derives from the running bundle; the entitlements derive from
`BUNDLE_ID_PREFIX` in `Config/Signing.xcconfig`.
*Failure mode:* a literal that drifts out of step with the entitlement does not fail
the build. It hands the app and the widget two separate stores, and the only symptom
is the widget showing a stale zero.

**5. Both targets open the store with identical configuration.**
`SharedModelContainer.make()` takes no options for exactly this reason.
*Failure mode:* a CloudKit-mirrored store opened without CloudKit still *reads*
correctly and silently fails to *write*. This already cost real debugging time once.

**6. HealthKit is a mirror, never a dependency.**
`HealthKitService` returns `nil` rather than throwing; `DrinkStore.backfillHealthKit`
sweeps up anything the widget logged without a sample.
*Failure mode:* a denied permission that blocks a log turns a Health integration into
a reason the app stopped working.

**7. Quantity saves N separate entries, never one entry carrying a count.**
`DrinkDraft.makeLoggedDrinks(region:)` → `DrinkStore.save(_ drinks:)`.
*Failure mode:* a count-bearing entry cannot be partially removed, gets one HealthKit
sample for several drinks, and makes history dishonest.
See [ADR-0003](decisions/0003-quantity-saves-separate-entries.md).

**8. Copy stays factual and countable.**
"Another beer", "drinks today", "Record no alcohol today". No encouragement to
reach a number, nothing that reads as a reward for volume. The strings that carry this
live in `TodayView`'s counter area, `TodayView.repeatControl`, and `DayLogSheet`.
*Failure mode:* guideline 1.4.3, applied by a reviewer rather than by us.

**9. The domain layer stays free of UI and persistence.**
`DrinkTrackerCore` is pure value types. SwiftData's `@Model` macro only expands inside
Xcode, so keeping the math out of it is what makes the math testable without a
simulator.
*Failure mode:* untestable arithmetic in an app whose entire value proposition is that
the arithmetic is right.

**10. The intensity ramp is one hue, and changes to it are validated, not eyeballed.**
`IntensityPalette` is the only place in the app that defines literal colours — a
deliberate, narrow exception to `GlassTokens` defining none, because in a heatmap the
colour *is* the data. It carries magnitude in **lightness**, which is the one channel
that survives every form of colour vision deficiency and greyscale. Alcohol-free sits
off the ramp entirely, with an outline as a second encoding channel.
*Failure mode:* a hue-based ramp (green→yellow→orange→red is the tempting one) is
unreadable for ~8% of men and delivers a verdict besides — see invariant 8. Both
failures are invisible to anyone with normal colour vision reviewing the diff, which
is exactly why the check has to be mechanical. See [ADR-0007](decisions/0007-one-hue-intensity-ramp.md).

---

## 3. Change classes

Not every change deserves the same ceremony. Four classes, with what each requires:

| Class | Example | Requires |
|---|---|---|
| **Fix** | The widget's intent never dispatches | Reproduction stated; the tier of verification that actually proves it (§4); test if the fault is testable |
| **Enhancement** | Longer trend ranges | Tier 1 test if it touches domain math; Tier 3 verification with concrete numbers; README updated if it changes how the app is used |
| **New surface** | A new screen or widget family | All of the above, plus an explicit check against every invariant in §2, plus a Dynamic Type and VoiceOver pass |
| **Product decision** | Whether Spirit's default should hit 1.0 | An ADR in `docs/decisions/`, whether or not any code changes. If code changes, the test that pinned the old behaviour is updated in the same commit, never deleted quietly |

A change that is a fix *and* a product decision is both — resolving the Spirit default
means an ADR and a test change.

---

## 4. Definition of done

Four tiers, ordered by what each can actually prove. The point of naming them is that
**simulator-green is routinely mistaken for verified**, and several of this app's most
important behaviours cannot be observed in a simulator at all.

**Tier 1 — Domain.** `cd DrinkTrackerCore && swift test` (50 tests today.)
Pure value-type math: standard-drink formulas, regional definitions, draft behaviour,
trend grouping. Runs anywhere, no simulator, no signing. **Every change to a formula,
a default, or a grouping rule lands with a test here.**

**Tier 2 — Integration.** The `DrinkTrackerTests` target, against an in-memory
`ModelContainer`. SwiftData's `@Model` macro only expands inside Xcode, so anything
about *rows* has to live here rather than in the package. Covered:
- `DrinkRepository.saveOrThrow` overwriting by id rather than inserting a duplicate —
  the single line that makes editing replace an entry's contribution to the daily
  total instead of doubling it.
- Deletion, and undo restoring the entry at its *original* id and timestamp.
- Day scoping and totals, including that a total is expressed in the caller's region
  rather than the one stored on the entry (invariant 3).
- The HealthKit backfill queue: only unsynced entries, oldest first.
- `AppSettings` round-tripping through defaults, including `storedRegion()`'s
  nil-to-US fallback and the skipped-vs-chose-US distinction.

It is a standalone bundle with no `TEST_HOST`, so it reaches `Shared/` but not the
app target. `DrinkStore.backfillHealthKit` itself is therefore **still uncovered** —
testing it needs a host app, which drags signing and app launch into CI. Its
repository half is covered here; the HealthKit half is not.

**Tier 3 — Simulator.** Build the app scheme, then exercise the specific interaction and
**state the observed numbers in the commit message.** The existing commits already do
this well — "logging 3 wines took the total from 5.9 to 8.9, and removing one took it
to 7.9" is a claim someone can check. This tier codifies that as required rather than
habitual.

**Tier 4 — Device only.** Cannot be established any other way:
- Widget intent dispatch (a tap actually reaching `LogDrinkIntent.perform()`)
- Shortcuts and Siri (Shortcuts is not installed in the Simulator)
- Real HealthKit writes and sample retraction
- CloudKit sync between two devices signed into the same account
- Signing, provisioning, and the App Group entitlement under real provisioning

**A claim about Tier 4 behaviour that was only checked in a simulator is not a
verified claim, and must be written down as unverified.** The README's widget section
is the model here: it says exactly what was established and exactly what was not.

---

## 5. Workflow

1. Branch from `main`.
2. Open a **draft PR** early. `semmes/drinktracker` has had zero PRs and zero issues to
   date — every commit landed directly on `main`. The PR is where a change gets
   examined before it becomes history.
3. CI must be green — `.github/workflows/ci.yml` runs `swift test` on
   `DrinkTrackerCore` and an `xcodebuild` build of the `DrinkTracker` scheme.
   That one scheme covers both targets: the widget extension is a target
   dependency of the app and is embedded by the same build.
4. Self-review against §2. A new surface reviews every invariant; a fix reviews the
   ones it touches.
5. Merge to `main`.

`.github/pull_request_template.md` carries the short version of this checklist.

**Distribution is not part of this loop.** Xcode Cloud archives and uploads to
TestFlight; Actions never produces a shippable build. One upload path on purpose —
see [ADR-0008](decisions/0008-two-ci-systems-with-one-job-each.md).

**Commit messages** follow the convention the existing history already sets: what
changed, *why the alternative was rejected*, and what was actually observed. That
history is the reason this repository is legible eight commits in; it is worth keeping.

---

## 6. Where knowledge lives

The README currently does five jobs — orientation, design doc, decision log, status
report, and bug tracker — and grows with every feature commit. It has already drifted:
it claimed 19 tests when there were 24, and cited two design documents that are not in
the repository. Splitting the jobs is what stops that recurring.

| File | Job |
|---|---|
| `README.md` | How to build, run, and sign it. Current status and known issues. Orientation only. |
| `docs/PRD.md` | This document: invariants, process, roadmap. |
| `docs/decisions/NNNN-*.md` | One record per settled decision. |

**The rule:** a decision that took an argument to reach gets a record. The README links
to it rather than re-explaining it, so the reasoning has exactly one home and cannot
half-change in one of two places.

An ADR is not immutable — it is *durable*. Superseding one is a normal act, done by
writing a new record that says what changed and why. Silently contradicting one is not.

---

## 7. Roadmap

Three iterations. New user-facing features are deliberately last: the app already does
what it set out to do, and the open risks are all about whether it does it *correctly*.

### Iteration 1 — Confidence

**Goal:** nothing important is both load-bearing and unverified.

- **a. Resolve the widget's one-tap logging.** ✅ Done — verified working on a
  device (2026-08). The fault was parameter resolution, not dispatch: a non-optional
  `@Parameter` with no default is one the system may need to *prompt* for, which a
  widget cannot do, so the tap was abandoned before `perform()`. Fixed with
  `default: .beer`. The diagnostics that isolated it (including "Intent last built
  by") remain in Settings for Debug and TestFlight builds.
- **b. Integration tests.** ✅ Done — the `DrinkTrackerTests` target and the Tier-2
  tests listed in §4, run in CI on a simulator. Remaining: `DrinkStore` and
  `HealthKitService` need a host-based target, which is deliberately deferred.
- **c. CI.** ✅ Done — `.github/workflows/ci.yml` runs the domain tests and an
  unsigned simulator build on every PR, plus `.github/pull_request_template.md`
  carrying the §2/§4 checklist. This one comes first on purpose: nothing else in
  this iteration can be verified from a machine without a Swift toolchain, and CI
  is what turns "I believe this builds" into evidence.
- **d. Decide the three spec discrepancies** the README documents as implemented
  literally and pinned by test. Each becomes an ADR; where the answer changes
  behaviour, a default change and an updated test in the same commit.
  - The consequential one is **settled**: the one-drink invariant is real, Spirit
    defaults to the 1.5 oz shot, and Other is a documented exception. See
    [ADR-0005](decisions/0005-spirit-defaults-to-the-1_5-oz-shot.md). This adds a
    standing constraint — a new drink type either lands on 1.0 at its default or
    documents why it doesn't.
  - Still open: the UK "0.28 fl oz / 8 g" mismatch (currently derived from grams,
    which is the published definition) and whether that needs saying anywhere
    user-facing.
- **e. Verify CloudKit sync** across two devices on one account, or downgrade the
  claim to unverified. The fallback gap found alongside it is fixed — the CloudKit
  fallback now lives in `SharedModelContainer.make()` so both targets take the same
  ladder, keeps the App Group, and records which rung it landed on. See
  [ADR-0004](decisions/0004-a-failed-store-degrades-to-memory.md). The device
  verification it depends on is still outstanding.

**Exit criteria:** CI green on every PR; Tier-2 tests cover the four behaviours in §4;
the widget is either working or documented with device evidence; three ADRs written;
the CloudKit claim is either verified or marked unverified.

### Iteration 2 — Ship-readiness

**Goal:** the app could be submitted without discovering compliance work late.

- **`PrivacyInfo.xcprivacy`.** Required, and this app writes alcohol consumption to
  HealthKit — about as sensitive as health data gets.
- **String Catalog migration.** Every user-visible string is hardcoded English while
  the app supports US, UK, and Australian unit definitions. That mismatch is not
  subtle.
- **Dynamic Type and VoiceOver audit** across all five surfaces. Some of this is
  already handled deliberately (`FlowLayout` exists so size pills survive large type);
  the audit confirms it holds everywhere.
- **A 1.4.3 copy review** of every user-visible string against §1, as a single pass
  with a written result.
- **App Store metadata**: description, screenshots, privacy nutrition labels, age
  rating.

**Exit criteria:** a submittable build, with the copy review recorded.

### From the first real run (2026-08)

Found by actually launching it, which is the point of Tiers 3 and 4.

- **`remote-notification` background mode was missing.** CloudKit logged
  `BUG IN CLIENT OF CLOUDKIT` on launch. Without it, mirroring only reconciles on
  foreground rather than on push, so a second device's changes arrive late or not at
  all. Fixed via `INFOPLIST_KEY_UIBackgroundModes`; `aps-environment` was already in
  the entitlements. **Still unverified** — proving push-driven sync needs two signed-in
  devices, which is 1(e).
- **`make()` does not throw when iCloud is unavailable.** It succeeds and mirroring
  fails asynchronously, so the fallback ladder never runs for the common case and
  `storeMode` was reporting a wish. Fixed by asking `CKAccountStatus` directly. See
  the amendment on [ADR-0004](decisions/0004-a-failed-store-degrades-to-memory.md).
- **Sync-state UI for release builds.** ✅ Done — `SettingsView.iCloudSection`,
  always visible, mapped from a machine-readable status code the probe records.
- **Open — no schema migration plan.** `AlcoholFreeDay` was added to the schema after
  the store already existed. Additive changes are handled by SwiftData's lightweight
  migration, but nothing pins that, and the next change may not be additive. A
  `VersionedSchema` and a migration test belong in Iteration 3 at the latest.

### Iteration 3 — Depth

**Goal:** the deferred features, re-examined against §2 rather than assumed.

Currently in the README's "Not built" list, plus what has come up since:
- **Calendar and year view.** ✅ Done, pulled forward ahead of the rest of this
  iteration on request. Brought `AlcoholFreeDay`, the intensity ramp
  ([ADR-0007](decisions/0007-one-hue-intensity-ramp.md)), and the 30-day summary
  that stands in for a score ([ADR-0006](decisions/0006-a-summary-not-a-score.md)).
- **Export.** ✅ Done (2026-08) — one CSV of the whole log from Settings, via the
  share sheet; rendered in `DrinkTrackerCore` and pinned by tier-1 tests. See
  [ADR-0015](decisions/0015-export-is-a-csv-of-the-log.md) for why CSV and not a
  summarising PDF (ADR-0006's boundary).
- **Longer trend ranges** (90-day, year). Watch invariant 3 — a year of history spans
  region changes.
- **Widget size/ABV choice.** Explicitly rejected once, as the widget mirrors the
  sheet's fast path. Reopening it needs an ADR, not just an implementation.
- **Bulk edit.** Adjacent ground is now covered: bulk *fill* (drag-select blank
  days, one answer for all) shipped with the calendar, and deliberately never
  touches a recorded day
  ([ADR-0011](decisions/0011-bulk-fill-never-touches-a-recorded-day.md)). Bulk
  *edit* of recorded days remains unbuilt and needs its own confirmation design.

**Not scheduled until Iterations 1 and 2 close.**

---

## 8. Open questions

| Question | Trigger for deciding |
|---|---|
| Are `drink-tracker-design-brief.md` and `drink-tracker-claude-design-plan.md` recoverable? If not, this document is the source of truth and should absorb anything still only in them. | Before Iteration 1(d) — the spec discrepancies are decided against the brief's own text. |
| Does iPad get a distinct layout, or does it stay a scaled iPhone app? | Before Iteration 2's App Store metadata; iPad screenshots force the answer. |
| Should the widget's defaults ever be configurable? | Iteration 3, and only via an ADR that addresses why the fast-path argument no longer holds. |
| Is there a second widget family or a Control Center control worth having? | After 1(a) — a widget whose intent dispatch is unresolved is not a foundation to build on. |
| ~~Should a degraded store mode be visible in a release build?~~ **Resolved (2026-08):** Settings now carries an always-visible iCloud row on the Health-row model — syncing / not syncing and why / not saving at all — with factual copy per §1. See `SettingsView.iCloudSection`. |
