# Tallyist 1.3 — feature spec

Opened 2026-09-05 with the first 1.3 PR. Same shape as the 1.2 spec: the
project constraints and the App Review claims are hard rules, each feature
states what it adds and what it must not become, and the claims table is the
record of what was said to Apple and why it stays true.

## Project constraints

Unchanged from `docs/tallyist-1.2-spec.md` ("Project constraints" and
"Stop conditions"), and restated platform-neutrally in the product contract
(`semmes/tallyist-product`, `contract/constraints.md`): no account, no
servers, no goals, streaks, scores, or advice, no user data shared between
users, no consumption guidelines, report never instruct, every new
behavioural surface optional and off or neutral. **The 1.2 train is frozen
and awaiting App Review**; a fix that must ship in 1.2 is a new build and a
re-submission, and says so.

## Feature A: Year in review share card — done (ADR-0029)

The owner's design (the claude.ai/design project *Share Card*, bundled at
`docs/design/Share_cards/`) confirmed the month and year cards as shipped
and added one card: a complete calendar year as an image — the year card's
four figures with unlogged days named, then the year's twelve monthly totals
as bars with the Trends chart's monthly average dashed across them.

**What it is.** Offered from the year view's share button for a year that
has ended and has something recorded in it; the button becomes a two-item
menu naming the calendar image and the review. Every bar is the month card's
own total (`monthSummary`); the line is `bucketAverage` over twelve complete
months (total ÷ 12); the figures are `yearSummary`'s. Filename
`tallyist-<year>-review.png`.

**What it must not become.** No delta between years, no rank, no tallest
month named, no arrow, no grade, no per-week or per-day rate, no comparison
to anyone, no prompt or badge inviting the share. The rule that governs
future cards is ADR-0027's, as amended by ADR-0029: a figure the in-app
calendar surface for that period or a period nested in it already shows,
from the same function, or a line the Trends chart already draws under the
same rule.

**Acceptance.** Renders in both appearances; the four figures equal the
year view's card; each bar equals that month's card; the caption states the
line's value; the PNG carries no identifier; nothing persisted; the year in
progress is never offered a review. Tier-1 tests in
`YearInReviewTests.swift`; tier 3 on the simulator (menu, sheet, Preview of
the rendered PNG); the remaining tier-3/4 items are listed in ADR-0029.

## App Review consistency

| Claim made in the 1.0 response, kept through 1.2 | 1.3 |
|---|---|
| "No user-generated content is shared between users" | Preserved. The year-in-review image is a user-initiated one-way export through the system share sheet, carrying only the user's own figures and monthly totals. |
| "No goals, no scores, no comparison" | Preserved. The card's average is the Trends chart's own line, described as "your average" and never as a target; no bar is compared to another, ranked, or related to any guideline. |
| "Nothing leaves the device unless the user sends it" | Preserved. Built at share time, no temp file, no log of the share. |
| "No accounts, no servers, no networking code" | Preserved. No new code path reaches the network. |

Reviewer notes and What's New for 1.3 are in `docs/app-store-listing.md`.

## Stop conditions

Inherited from the 1.2 spec. In addition, for share cards: any figure that
is not already on an in-app surface for that period, from the same
function, stops and goes to an ADR first (ADR-0027 / ADR-0029).
