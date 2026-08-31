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
  Four rules worth keeping: `Text(String)` is the *verbatim* initializer, so a
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
- **Repo visibility — private is on the table, deferred to the 1.2 train**
  (raised 2026-08-31, user decision: hold and decide for 1.2). Deliberately
  **not** before 1.2: the URLs below serve the *live* 1.0 listing, and 1.1 is
  in App Review. Three blockers, each of which must land before the flip, not
  after. (1) The ASC **Privacy Policy URL and Support URL are both
  `github.com/semmes/DrinkTracker/blob/main/docs/…`**
  (`docs/app-store-listing.md`) and 404 for signed-out visitors the moment the
  repo goes private — guideline 5.1.1 and 1.5. (2) **Support *is* GitHub
  Issues** (`docs/support.md`, and the policy's Contact section) — private
  makes it invitation-only and there is no non-GitHub fallback contact
  anywhere. (3) Both policy copies claim it "lives in the app's public source
  repository; any change to it is visible in the repository's history"
  (`docs/privacy-policy.md`, `PrivacyPolicyView.swift`) — the house rule is
  that the policy's claims stay checkable, and this one would simply become
  false. The in-app `PrivacyPolicyView.hostedURL` ("Read this policy online")
  would 404 in already-shipped apps, so that fix needs a build. Order if it
  goes ahead: host the policy + support page publicly elsewhere → repoint the
  two ASC URLs (both editable on a live app, no binary) → add a support email
  → rewrite the paragraph in both copies with a date bump, ADR, and 1.4.3
  review → ship the new `hostedURL` → only then change visibility. Cost side,
  which is a separate decision: CI is three `macos-latest` jobs, ~8 billable
  macOS minutes per run, and **130 runs in August 2026** ≈ 1,040 min/month.
  Private repos meter macOS at 10×, so that is roughly **$60–70/month** in
  overage against a 2,000–3,000 minute allowance — and a $0 spending limit
  stops CI outright rather than slowing it, which would end merge-when-green.
  Nothing else depends on public: 0 forks, 1 star, 0 watchers, no Pages, and
  both Xcode Cloud and `gh` work fine against a private repo.
- Watch the 1.1 review outcome; a rejection comes back here with its text.
