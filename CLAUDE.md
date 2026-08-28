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

**As of 2026-08-26:** v1.0 live; **v1.1 submitted, in App Review** (Health
import, authorization-refresh fix, drag-fill action bar, tip jar, onboarding
refresh, bigger calendar). **Export shipped to main** (ADR-0015): Settings →
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
shortcut to test, and treat real phrase invocation as tier 4. User-side when 1.1 clears: create the 1.2 version in ASC,
paste the listing material, pick a green main build from Xcode Cloud,
submit. Still pending separately: one Xcode GUI build that actually
populates `Localizable.xcstrings` (the user's 2026-08-27 build didn't),
then localization prep steps 2–4.

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
  translation still deferred. Step 1 done (catalogs extracted, 2026-08-28) and
  **step 4 done** (ADR-0020: the core package owns its display names via
  `Bundle.module`; the CSV localizes values but never headers). **Steps 2–3
  remain** — ~30 String-returning helpers across the app assemble sentences by
  interpolation, so they are invisible to the extractor and freeze English word
  order; each becomes a whole-phrase key, count-bearing ones with plural
  variations.
- **Two checkouts exist on this Mac** and they drift: this one, and
  `/Users/shawnsemmes/DrinkTracker`, which is where the user's Xcode builds
  from (that is where a build's `Localizable.xcstrings` changes land). Check
  both before concluding a build "did nothing".
- Watch the 1.1 review outcome; a rejection comes back here with its text.
