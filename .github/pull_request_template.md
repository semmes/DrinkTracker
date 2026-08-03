## What and why

<!-- What changed, and why the alternative was rejected. -->

## Change class

<!-- See docs/PRD.md §3. Delete the ones that don't apply. -->

- [ ] Fix
- [ ] Enhancement
- [ ] New surface
- [ ] Product decision (needs an ADR in `docs/decisions/`, whether or not code changes)

## Invariants

<!-- docs/PRD.md §2. A new surface reviews all nine; a fix reviews the ones it touches. -->

- [ ] Checked this change against the invariants it touches, and none are weakened

## Verification

<!--
docs/PRD.md §4. State what you actually observed, with numbers where there are
numbers. If a claim is Tier 4 (widget dispatch, Shortcuts, real HealthKit,
CloudKit sync, signing) and was only checked in a simulator, say so — that is
not a verified claim.
-->

- [ ] Tier 1 — `cd DrinkTrackerCore && swift test`
- [ ] Tier 2 — integration tests (once the target exists)
- [ ] Tier 3 — built and exercised in the Simulator; observed behaviour described above
- [ ] Tier 4 — device-only behaviour, or N/A

## Docs

- [ ] README updated, or no user-facing change
- [ ] ADR added or updated, or no decision was made here
