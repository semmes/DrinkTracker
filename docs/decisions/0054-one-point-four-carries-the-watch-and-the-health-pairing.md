# 0054 — 1.4 carries the watch and the health pairing together

**Status:** accepted · **Date:** 2026-09-23 · **Supersedes:** decision 4 of
`docs/tallyist-health-pairing-plan.md` ("Its own train, after the watch") ·
**Relates to:** `docs/tallyist-1.4-spec.md`; `docs/tallyist-watch-plan.md`
(Phase 8); the health pairing plan's "Release"; ADR-0024 (the policy's three
copies); ADR-0049 (health context is read, never stored)

## Context

The health pairing plan made four decisions with the owner before any of it
was built, and the fourth put the pairing on "its own train, after the
watch", for a stated reason: "This has its own review surface and its own
privacy-policy change, and mixing it into a platform launch would make both
harder to explain."

That was written on 2026-09-13. What happened next made it a decision again
rather than a plan to follow:

- The pairing was built while the watch's release waited. Its Phases 0 to 6
  and the owner's device pass merged on main between 2026-09-21 and
  2026-09-22 (PRs #112 to #122), under `MARKETING_VERSION` 1.4, which had
  been 1.4 since the watch's first PR (0df19d6). No release branch has ever
  existed in this repository, so nothing kept the two apart.
- 1.3 went live on 2026-09-20. Its build predates the 1.4 bump, and so
  predates PR #121, which repairs what the owner's iOS 27 device pass found:
  card titles drawn at 2.48:1 in dark mode, and segmented pickers that miss
  taps on interactive glass. Those are read from the source, not from the
  store build, but the lines behind both defects (the shared card title's
  `.secondary` ink and the Trends range picker's `SUSegmentedControl`, among
  others) are in 1.3's tree; only the pairing's own code, which 1.3 does not
  have, is not.
- Main now reads four Health types that the privacy policy says it does not
  read, so nothing can be cut from main until the pairing's Phase 7 rewrites
  the policy and the purpose string.

CLAUDE.md set out three ways 1.4 could go, and the argument for each is still
real:

1. **Both features in 1.4.** Main ships as it is, after the pairing's Phase 7
   and the watch's Phase 8, which then land as one release: one policy
   change, one What's New, one set of reviewer notes.
2. **The watch alone, cut from an earlier commit.** The last merge before
   the pairing reached a screen is PR #114 (b9c8242). This keeps decision 4
   intact. The cost is a release branch this repository has never had, and
   PR #121's repairs carried across by hand, or left out of 1.4 for iOS 27
   users who already see the defects.
3. **The pairing compiled out of 1.4.** A build-time switch over the
   Settings section, the Trends section, the offer and the read types. This
   also keeps decision 4. The cost is new code whose only job is to hide
   finished code, and a purpose string that would have to differ between two
   builds of one version.

The honest case for 2 and 3 over 1 is decision 4's own: a reviewer seeing an
alcohol app ask for sleep and heart data, in the same submission as a new
platform, has two new things to object to, and a rejection over either holds
both.

## Decision

1.4 carries both. The owner ruled on 2026-09-23, choosing option 1 when the
three were put to them. The pairing's Phase 7 and the watch's Phase 8 are
done together: one privacy-policy change (all three copies, one date), one
purpose string, one What's New, and one set of reviewer notes. The notes give
each feature its own section and state what it does and does not do, so a
reviewer can clear or question one without rereading the other.

## Consequences

- **A rejection over either feature holds both.** This is the price, and it
  is decision 4's argument paid rather than refuted. The reviewer notes are
  where it is managed: the pairing's section says what the plan's "Release"
  asks for (the user's own two averages, side by side, on a screen they
  open, for metrics they turned on; no diagnosis, advice, threshold,
  notification, inference about drinking from physiology, storage, or
  transmission), and the watch's section says what its Phase 8 asks for.
- **iOS 27 users get PR #121's repairs in the next update**, with no release
  branch and no hand-carried commits.
- **No switch code.** Main is what ships, so what was tested on the owner's
  devices is what is submitted.
- **The privacy policy changes once, before 1.4 ships**, which is the
  direction the policy promises ("this policy and the App Store privacy
  labels will change *before* that version ships"). Its privacy claims stay true of
  1.3 while it is the version people install, because 1.3 reads and sends
  less than the policy allows, and the new reads are written conditionally
  ("if you use Tallyist on Apple Watch", "only if you turn it on"). Some
  sentences describe 1.4 outright: the policy covering Apple Watch, the
  in-app copy being the same policy, the switches under Apple Health on
  Trends, and the complications. So until 1.4 is live the published page
  describes things 1.3 lacks and differs from 1.3's in-app copy (dated
  September 3). That is ADR-0024's cost of publishing ahead.
- **What's New carries two features and the rest of the train** (the
  comparisons card and the iOS 27 repairs). It is long; the store truncates
  it behind "more", so the watch and the pairing go first.

## How to reopen

If App Review rejects 1.4 over the pairing and the objection cannot be met
in copy or in the notes, option 3 becomes the way to ship the watch while the
pairing is argued: compile the pairing out of 1.4 and bring it back in 1.5.
By then option 2 is no longer attractive, since main will have moved past
the cut. If the rejection is over the watch, the same switch would work the
other way round, but the watch is the larger surface and would need its own
record.
