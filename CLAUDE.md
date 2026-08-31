# CLAUDE.md — working on Tallyist

Guidance for Claude sessions (and any agent) working in this repository.
Durable conventions first; the dated **Current state** section at the bottom is
the living handoff — update it at the end of significant sessions.

## What this is

**Tallyist** (repo `semmes/DrinkTracker`, public) — an iOS 26 SwiftUI drink
tracker, live on the App Store. The bundle identifier stays
`com.shawnsemmes.DrinkTracker` deliberately: App Group and iCloud container
identity derive from it, and renaming orphans the user's store (README
"Naming"). Only the App Store listing says Tallyist.

## Read these before changing anything

1. `README.md` — orientation, build/run, current status.
2. `docs/PRD.md` — the ten invariants, change classes, verification tiers 1–4,
   roadmap. **Any change must respect the invariants.**
3. `docs/decisions/` — one ADR per settled decision. A decision that took an
   argument to reach gets a record; reopening one means engaging its
   "How to reopen" section, not re-litigating from scratch.
4. `docs/design-system.md` — the visual language. Colour changes are
   re-validated with contrast math, never eyeballed (invariant 10).

## Process (user-authorized standing policy)

- Branch → **draft PR** → CI green → **merge without asking**. The user has
  granted standing merge-when-green authorization.
- **Merge commits only.** Never rebase or squash — a rebase-merge once
  rewrote committer identities (see PR #1 history).
- Commits from Claude sessions end with a `Co-Authored-By: Claude …` trailer
  and a `Claude-Session:` link. **Never put internal model identifiers in any
  pushed artifact** — commit messages, code comments, PR bodies included.
- Every product decision gets an ADR (`docs/decisions/0000-template.md`).
- The privacy policy has two copies that change together in the same commit:
  `docs/privacy-policy.md` (the hosted URL in the App Store listing) and
  `PrivacyPolicyView.swift`. Bump the "Last updated" date in both.
- New user-visible copy goes through the App Store guideline **1.4.3** tone
  review — append to `docs/copy-review-1.4.3.md`. House voice: factual,
  no celebration, no judgment, no exclamation marks (one exception: the
  storage-failure warning).
- Fixes land with a test at the lowest tier that can catch the regression
  (tier 1 domain / tier 2 repository). Tier 3–4 (simulator/device) items are
  stated in the commit message as what remains to verify, honestly.

## Architecture in one paragraph

`DrinkTrackerCore` (SPM, pure domain, no UI/persistence — runs on macOS in
CI) → `Shared/` (compiled into app, widget, and test bundle: repository,
SwiftData model, App Group, intents) → app target + widget extension.
`DrinkTrackerTests` uses an in-memory ModelContainer, no TEST_HOST. SwiftData
mirrors to the user's private CloudKit DB; HealthKit flows both directions
(writes per entry; import of other apps' samples is count-based and read-only
mirrors — ADR-0014). StoreKit 2 tip jar (`TipJar.swift`; product IDs in
ADR-0012; `DrinkTracker.storekit` is wired into the shared scheme so
purchases work in the simulator with no App Store Connect setup).

## CI / distribution

- **GitHub Actions** verifies every PR: domain tests (macOS-native), simulator
  build, integration tests (ADR-0008). GitHub sometimes **drops the PR webhook
  event** and no run appears — the reliable remedy is a manual
  `workflow_dispatch` of `ci.yml` on the branch (it associates with the PR).
  Never push empty commits to kick CI.
- **Xcode Cloud** archives and uploads to TestFlight;
  `ci_scripts/ci_post_clone.sh` stamps unique build numbers. Manual archives
  from Xcode work too (build numbers restart per version train).
- Remote Claude sessions have **no Swift toolchain** — CI is the only
  compile/test check; say so rather than claiming local verification.

## The user's Mac (sync gotchas)

- Pull via Xcode's **Integrate → Pull**, or in terminal with Xcode fully quit
  — never mixed in one sitting; Xcode caches the project file and schemes.
- Local builds modify `Localizable.xcstrings` (automatic string extraction).
  A conflicted stash-pop once corrupted them; the reliable repair is
  `git reset --hard origin/main` (their strings are already in history).
- Widget changes need the widget removed and re-added on device; the new
  onboarding shows only on fresh installs.
- TestFlight builds show the Diagnostics section in Settings (by design).

## App Store material

`docs/app-store-listing.md` is the paste-ready ASC metadata (description with
the guideline-3.1.2(a) subscription block — keep prices in sync with ASC),
plus support URL (`docs/support.md`) and privacy URL. Age rating 17+ (alcohol
references); App Privacy is **Data Not Collected** — the privacy policy's
claims are written to be checkable against the manifests and entitlements,
so keep them true.

---

## Current state (update me at end of session)

**As of 2026-08-26:** v1.0 live; **v1.1 submitted, in App Review**. What is
actually *in* 1.1 is PRs #21–#27: the Health import (ADR-0014), the
authorization-refresh fix, the day-sheet live counter, and the Health read
purpose string. The tip jar, the drag-fill action bar, the onboarding refresh
and the bigger calendar shipped in **1.0** — they merged before the
store-readiness PR that created the listing metadata, and 1.0's own What's New
names drag-to-fill. An earlier version of this note filed them under 1.1;
they were already in users' hands. **Export shipped to main** (ADR-0015): Settings →
Export log shares the whole record as one CSV — `LogExport` in the core
package (tier-1 tested), `LogExportFile` + Settings section in the app.
**Design system synced** (2026-08-26): the claude.ai/design project
*Tallyist Design System* now exists and holds the 12-card bundle (Brand /
Colors / Type / Layout / Components over one `styles.css`), generated from
`docs/design-system.md` + the shipping Swift. Sync from a **local** session
via the DesignSync tool (remote sessions still cannot authorize); source of
truth stays the repo — edit here first, re-sync incrementally.

**The 1.2 feature spec is in the repo:** `docs/tallyist-1.2-spec.md` — read
its "Project constraints" and "App Review consistency" sections before any
1.2 feature work; they restate the App Review claims as hard rules. Build
order A→B→C→D. **Feature A (appearance setting) is done** — the color audit
found nothing to move: `IntensityPalette` and `AppTheme` are the documented
dual-mode exceptions (invariant 10 / ADR-0007), and both `.white` uses are
R2-measured labels on AccentFill. **Feature B (session pace) is done**
(ADR-0017) — gap threshold fixed at 4h (the 3/4/6 setting deliberately not
built; reopen path in the ADR). Gotcha discovered: a Toggle on
non-interactive `glassSurface` loses taps (drags still land) — every
tappable control goes on `interactive: true` glass (same lesson again on
Feature C: `onTapGesture` on an SUCard never fires — use a real Button).
**Feature C (population reference) is done** (ADR-0018) — sourced to the
ARG 2020 National Alcohol Survey norms table, renormalized to
adults-who-drink with the derivation disclosed (user-approved route);
bundled in the core package, compared in grams, gated on 4 weeks of
history. **Feature D (share card) is done** — the build didn't run long, so
the optional feature shipped: a ShareLink in the calendar toolbar renders
the visible month via ImageRenderer at share time (DataRepresentation, no
temp file, PNG metadata verified identifier-free). **All four 1.2 spec
features are implemented, and release prep is done** (2026-08-27):
MARKETING_VERSION is 1.2, the privacy policy gained an "Export and
sharing" bullet (both copies, dated), and `docs/app-store-listing.md`
carries the paste-ready What's New (1.2) and App Review notes. **The 1.2
train stays open**: nothing freezes until the build is submitted, and 1.2
can't be submitted while 1.1 sits in App Review anyway — new features can
keep merging; each one just re-touches What's New / reviewer notes / the
claims table. **Siri/App Intents landed on the open train** (ADR-0019):
four App Shortcuts (instant typed, habit-seeded, conversational, no
alcohol). The rule that governs any future intent work: `LogDrinkIntent`
is the *widget's* and must never gain a promptable parameter (optional or
defaulted only) — `LogDrinksIntent` is the Siri one where prompting is the
point. Simulator gotcha: App Shortcut **tiles** can't run in the simulator
(linkd "Couldn't find AppShortcutsProvider"); add the action to a manual
shortcut to test, and treat real phrase invocation as tier 4.

**First field bug, fixed on the open train** (ADR-0022): a 1.0 user reported
the counter's + auto-logging "Other, 0oz, 0% ABV" instead of their usual
drink. That shape has exactly one producer — `LoggedDrink.importedFromHealth`
— and the seed helpers have filtered it since the import shipped, so the
mechanism is *cross-version*: `countedDrinks` is an additive attribute, so a
1.0 binary sharing the account's CloudKit store materialises 1.1's imported
rows as ordinary `.other` drinks, `.other` takes the plurality, and every
count-first surface repeats it — absorbing, never self-correcting. **The
lesson, and the rule now:** a provenance marker cannot be the only guard on
anything a *shipped* build also reads; test the physical facts. So
`LoggedDrink.isRepeatable` is `volumeOunces > 0` (never strength — a real
size at 0% is a drink someone chose to record), `quickCount` requires it and
otherwise falls to *that type's* defaults, and two ADR-0014 leaks on Today
closed with it (the repeat control read the newest row unfiltered; Today's
rows offered edit/remove on imports, and Remove reached
`health.deleteSample` on another app's UUID). Not repairable by shipping:
rows already written on a 1.0 device are ordinary entries and keep their
votes in `mostLoggedType` — they go by hand from History, and the CSV export
finds them (empty size and strength, source Tallyist).

**Second field report, also fixed on the open train** (ADR-0023): a user asked
for one tap to record *a standard drink with no type*, because switching
between types was the friction — "the drink type and abv should be optional
details I can choose to add or skip but still track". This reopens ADR-0009's
seed rule, which assumed a habit to inherit; someone who drinks varied things
gets handed a type they did not pick, and the row states it in the same voice
it uses for a drink they described. So `DrinkType.unspecified` now exists (not
a fifth category — the absence of the question, and excluded from
`selectableCases` so no picker offers it), and `AppSettings.counterSeed`
—Settings → "What the counter logs" — chooses between it and ADR-0009's rule,
**defaulting to the standard drink**. Every count-first surface reads it:
Today's ＋, the day sheet, bulk fill, and the widget's ＋ (which needed no new
control — `LogOneDrinkIntent` *is* the counter's mirror, so no home-screen
re-add). Adding details later reuses adoption's vocabulary and destination
(ADR-0016). **The owner's tier-3 review then revised the default into
day-scoped memory** (ADR-0023 revision): a day starts at a standard drink,
describing a drink makes ＋ repeat *it* for the rest of that day
(`DrinkDraft.dayTemplate` — the day's most recent repeatable entry, no
stored mode), "Record a standard drink instead" is the way back on Today and
the day sheet, and midnight resets. `.usualDrink` stays ADR-0009's
plurality rule, day-blind.

**The rules that came out of it, worth keeping:** an untyped drink stores the
*region's standard-drink definition* (0.6 fl oz at 100% for the US) — never
zero volume, because ADR-0022's lesson is that an older build decodes the
unknown type to `.other`, and a zero-volume `.other` row is exactly the field
bug again; with real facts the worst an old build does is mislabel a row whose
arithmetic is right. Region stays a lens (ADR-0002), so these re-express like
any physical fact. No surface prints the stored definition back as a serving —
`recordsSizeAndStrength` is the single predicate covering imports and untyped
drinks together. And `DrinkType.unspecified.defaultVolumeOunces` is a *US
fallback*: build these through `LoggedDrink.standardDrink(in:)` or
`DrinkDraft.standardDrink(region:)`, never `DrinkDraft(type: .unspecified)`,
or a UK user silently gets US amounts.

User-side when 1.1 clears: create the 1.2 version in ASC,
paste the listing material, pick a green main build from Xcode Cloud,
submit. The long-pending catalog population is **done** — and did not need
a GUI build after all (see the localization bullet). A real GUI build over
the pulled tree afterwards produced **no catalog change at all**, which
confirms the sync route writes what Xcode would. It also does not add
auto-generated translator comments to keys sync already created: Xcode
writes those only when it is the thing adding the key.

Open items for v1.2:

- PRD Iteration-3 backlog: **all engineering items done** — export
  (ADR-0015), `VersionedSchema` + migration test (recipe in
  `Shared/SchemaVersions.swift`), longer trend ranges (Quarter/Year,
  calendar-bucketed). **User declined (2026-08-26)** reopening widget
  size/ABV choice and bulk edit — both stay as designed; their reopen paths
  remain in ADR-0011/0014 if real use argues otherwise.
- Health-import adoption flow: **done** (ADR-0016) — tap/swipe "Add details"
  on a single-count import, typed facts rewrite it in place, Health untouched.
  Known wrinkle recorded in the ADR: adopting then *editing* can leave the
  foreign sample plus ours in Health; fix waits for a real report.
- Localization: **prep only (user decision 2026-08-26)**; language choice and
  translation still deferred, but **prep is finished and the catalogs are
  populated** (2026-08-28): **284 keys** across four catalogs — 221 app, 33
  widget, 26 core, 4 in a new `AppShortcuts.xcstrings`. Extraction and the
  committed catalogs agree exactly. See `docs/localization-status.md`.
  **How to populate them, because this repeatedly looked like "my build did
  nothing":** a command-line build does *not* write back into `.xcstrings` —
  it emits `.stringsdata` and stops; write-back is Xcode-GUI behaviour. Use
  `xcrun xcstringstool sync <Catalog>.xcstrings --stringsdata …` instead. Two
  traps: the **filename picks the string table** (syncing `app.xcstrings` looks
  for an `app` table, finds none, and empties the file), and an incremental
  build re-extracts only what recompiled, so force a full rebuild first or sync
  prunes everything that did not.
  Five rules worth keeping: **two keys that differ only in case are a build
  error in the core package** — `xcstringstool generate-symbols` folds case, so
  ADR-0023's "Standard drink" collided with the unit name "standard drink" and
  failed CI (the same family as the "≈" collision; a tier-1 test now pins the
  whole axis, and note the *app* catalog does not generate symbols, so it
  tolerates pairs like "Last 12 months"/"last 12 months");
  `Text(String)` is the *verbatim* initializer, so a
  String-returning helper is invisible to the extractor; don't create a key made
  only of `%@` and punctuation; **positional specifiers belong in a
  localization's value, never in a key** (a positional key is never looked up —
  it fails silently because the fallback is the English key itself); and pick
  singular/plural from the **displayed** digits, not the raw value
  (`StandardDrink.readsAsOne`) — several labels read "1 standard drinks".
  Remaining before a second language: plural variations per language (Xcode
  catalog editor, at translation time); counts that are fractional reach the
  catalog as `%@` and cannot take variations at all; `RecentSummaryCard` splits
  counts from nouns; a few strings blocked by ComponentsKit properties that
  demand `String` (`ButtonVM.title`); and **a decision on the privacy policy**,
  which is now extractable and whose claims must stay checkable.
- **Two checkouts exist on this Mac** and they drift: this one, and
  `/Users/shawnsemmes/DrinkTracker`, which is where the user's Xcode builds
  from (that is where a build's `Localizable.xcstrings` changes land). Check
  both before concluding a build "did nothing".
- Watch the 1.1 review outcome; a rejection comes back here with its text.
