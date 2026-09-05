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

## Feature B: The comparison window, and a complete year — done (ADR-0030)

The population card's window follows the record: the trailing four weeks as
shipped, then the trailing twelve months once the first recorded fact is 52
weeks old, because the survey's column is a twelve-month average. The note
names the span. A year that has ended, with a record, gets the same
comparison on the year view under its summary card, from the same summary.
Never on a share card. Region-matched references for the UK and Australia
were sought and not found (every published band is a guideline edge) and are
recorded as candidates in the contract.

**Must not become:** two averages on one card, a delta between windows, a
comparison against any guideline band.

## Feature C: A drinking-days reference — done (ADR-0031)

Two sentences under the volume comparison: the user's days with drinks over
the same window, and NESARC-III's published mean scaled to the same number of
days, whole days. A mean, so never a percentile, never a rank.

## Feature D: By weekday — done (ADR-0032)

A card on Trends: seven rows of the user's own log by weekday, the user's
Friday-to-Sunday and Monday-to-Thursday split, and the published rate of days
with a drink from Liang and Chikritzhs (NHANES 2005–10), whose definition of
the weekend the bundled file carries. No busiest day, no rank, no threshold;
the paper's heavy-episode rate is not bundled.

**Discarded, per the owner (2026-09-05):** everything in the sources review
that a record cannot be placed against without a threshold — guidelines,
clinical definitions, risk estimates, threshold-defined categories, attitude
polling, third-hand concentration figures. The contract's verifier now
rejects them by construction.

## App Review consistency

| Claim made in the 1.0 response, kept through 1.2 | 1.3 |
|---|---|
| "No user-generated content is shared between users" | Preserved. The year-in-review image is a user-initiated one-way export through the system share sheet, carrying only the user's own figures and monthly totals. |
| "No goals, no scores, no comparison" | Preserved. The card's average is the Trends chart's own line, described as "your average" and never as a target; no bar is compared to another, ranked, or related to any guideline. |
| "Nothing leaves the device unless the user sends it" | Preserved. Built at share time, no temp file, no log of the share. |
| "No accounts, no servers, no networking code" | Preserved. No new code path reaches the network. |
| "The population reference is a bundled, published, dated statistic; no thresholds, no guidelines" | Preserved and extended on the same terms: two more bundled, published, dated descriptive statistics (a mean of drinking days, a weekend rate), each named with its source and year; the app still classifies no one and compares to no threshold. The comparison's window follows the record, matching the survey's twelve-month measure. |

Reviewer notes and What's New for 1.3 are in `docs/app-store-listing.md`.

## Stop conditions

Inherited from the 1.2 spec. In addition, for share cards: any figure that
is not already on an in-app surface for that period, from the same
function, stops and goes to an ADR first (ADR-0027 / ADR-0029).
