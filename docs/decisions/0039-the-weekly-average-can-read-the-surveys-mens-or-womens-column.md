# 0039 — The weekly-average comparison can read the survey's men's or women's column, as a choice of reference

**Status:** accepted · **Date:** 2026-09-08 · **Amends:** ADR-0018 (the
bundled table gains its two other columns), ADR-0030 (the year view follows
the column) · **Relates to:** ADR-0038 (the switch this sits under), ADR-0002
(a lens, not a fact on the record — the same shape), spec constraints 1, 3
and 5, the contract's `platform/sources.json`

## Context

The population comparison has compared every reader against "US adults who
drink" since ADR-0018: the Alcohol Research Group's 2020 norms table, Total
column, renormalised to adults who drink. The owner asked (2026-09-08) for
the comparison to be personalisable "for Men, Women, and Non-Binary … based
on their answer, if they choose".

What the source publishes was checked against the PDF itself the same day:
three columns — **Men, Women and Total** — with the abstainer share stated
per column (25%, 31%, 28%), and nothing else: no age, no region, no other
group. (ARG's news page describes the same table in prose with different
abstainer figures, 28% of men and 38% of women; the page disagrees with its
own PDF, the PDF is the source, and the contract's sources file already
carried the PDF's numbers as "unused columns … the app collects no sex or
gender".) ADR-0030 had already established that no region-matched
distribution exists for the UK or Australia.

So the ask splits into two parts with different answers.

**The men's and women's columns exist and can be offered.** This is the one
personalisation of the *reference* the sources allow, and it is real: at
four US drinks a week the Total column reads "lower than roughly 35%", the
men's "40%", the women's "30%". The mechanism is the one ADR-0018 built —
the same bracket rule, the same grams conversion, only the percentage read
from the row changes — and the renormalisation is per column by its own
abstainer share.

**A non-binary column does not exist.** The survey publishes none, so a
"Non-binary" segment could only ever read the Total under another name. That
is not personalisation; it is a question asked to no effect. And the answer
to that question would be a stored gender identity — the one thing this
control must not become. The app records no fact about the person beyond
what they log (constraint 1; the privacy policy's "What Tallyist stores"),
and a preference that only *means* something as a statement about the reader
is such a fact, whatever it is called.

**The competing option** was the literal picker the ask named — Men, Women,
Non-binary — with the third mapped to the Total and the note saying so. It
is honest about the figure, and it still loses: it turns a choice of column
into a question about the reader, records the answer, and then does nothing
with it for exactly the readers it was added for. The design below gives a
non-binary reader, and anyone who would rather not say, the same honest
reference with no question asked.

## Decision

**All three of the survey's columns are bundled**, each renormalised to its
own drinkers in the file, with its abstainer share stated
(`percent_men`, `percent_men_drinkers`, `percent_women`,
`percent_women_drinkers`, `abstainers_percent_men`,
`abstainers_percent_women`); the tier-1 suite recomputes every row of every
column, so a transcription error fails CI, not a reader.

**`PopulationReference.Column`** — `allAdults` (the Total, the default),
`men`, `women` — is the type, and its name is the decision: a column of a
published table, chosen as a reference, never a fact about the reader.
There is no case the table does not print. `comparison(gramsPerWeek:in:)`
takes it; `comparison(gramsPerWeek:)` reads the Total, so every existing
caller reads what it always did.

**Settings → Comparisons → "Compare with"**: a segmented picker — All adults
· Men · Women — shown while the weekly-average switch is on (ADR-0038),
stored in `AppSettings.comparisonColumn` as the column's raw name, device-
local, "never set" reading as the Total. The footnote says what it is: *"a
choice of reference, not a question about you, and it stays on this
device"*, and that the other two figures are published for all adults only.

**The sentence names the column it read** — "That's lower than roughly 40%
of US men who drink." — one key per column and direction, never a noun
interpolated into a shared sentence. **The note follows the column and the
file**: "among US men, recalculated to cover only the 75% who reported
drinking", the 75 read from the bundled abstainer share, so a data-file
change cannot leave the note stating the wrong number. **The year view
reads the same column** (ADR-0030's comparison shares the copy set and the
setting). The drinking-days mean and the weekend rate are unchanged: their
sources print one figure for all adults.

**Not built: a Non-binary segment.** Recorded above with its cost. If the
owner wants the literal segment after this record, it is one enum case that
reads the Total's figures, one picker key, and a note that says it compares
with all adults — a small change, and a deliberate one, because it would
make the control a question about the reader.

## Consequences

- The bundled file grows by two top-level keys and four per row; its shape
  is additive, and the contract's copy (`platform/population-reference.json`,
  asserted byte-identical to the app's) is updated in the same change on the
  contract side.
- UK and Australian readers who choose a column are compared against US
  men or US women, in their own units, as the sentence says — the same
  named mismatch ADR-0018 accepted for the Total.
- A reader who chooses Men or Women sees a different percentage on the day
  they choose it and on the year view; nothing else moves. Nothing is
  stored on any entry, nothing syncs, nothing leaves the device.
- App Review: still a bundled, published, dated descriptive statistic,
  computed on the device, no threshold, no ranking. The new setting is a
  preference like Region — the privacy policy's "Your settings" line covers
  it; no new data category, no new permission, no new privacy-label entry.
- Copy: six comparison sentences (three columns × two directions), three
  note variants, three segment labels, the picker's title, the footnote —
  through the 1.4.3 review. "Men" and "Women" are the source's own column
  names.
- Tier 1 pins the columns' loading, renormalisation, monotonicity, the four-
  drink readings against each column, the shared edges (more-than at the
  top, nothing at zero) and the Total-as-default equality. Tier 2 pins the
  setting's default, round-trip and fallback.

## How to reopen

A published column for another group — an age band, a region — earns a case
only when the source prints it, on this record's terms: a choice of
reference, its own abstainer share, its own renormalisation, the sentence
naming it. A non-binary figure needs a source that publishes one; none does
today. If the picker reads as a gender question in real use despite the
copy, the segment labels can name the columns as columns ("the survey's
men's column"), or the picker can go and the Total stay — the file keeps
the columns either way.
