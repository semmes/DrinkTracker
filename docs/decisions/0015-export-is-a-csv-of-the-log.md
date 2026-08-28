# 0015 — Export is a CSV of the log, shared from Settings

**Status:** accepted · **Date:** 2026-08-26 · **Amended by:** ADR-0020
(localization: headers stay English, row values localize) · **Relates to:**
ADR-0002, ADR-0006, ADR-0014, PRD invariants 3, 8, 9

## Context

Export has sat in the roadmap since Iteration 3 was drafted, flagged as the
highest-value deferred feature: it is the natural answer to "show this to my
doctor", and it is a plain data question with no tone risk. What had to be
decided was the form.

Three candidates:

- **A PDF summary** — a formatted report with totals and ranges. Rejected:
  a rendered summary is an editorial act. Choosing which aggregates to
  headline is one step from a verdict, which is the line ADR-0006 exists to
  hold; and a PDF invites styling the numbers, which invites tone.
- **JSON** — complete and lossless, but not something a doctor, or most
  users, can open. An export whose only reader is a programmer answers a
  different question than the one being asked.
- **CSV** — opens in Numbers, Excel, and Google Sheets by name; prints as a
  table; attaches to an email; and stays a plain statement of the record.

There was also a question of *what* goes in the file: entries only, or the
alcohol-free markers too — and which unit the totals use, given entries store
their logging-time region as provenance.

## Decision

**Export is one CSV of the whole log, chronological, generated on demand and
handed to the system share sheet from Settings.** Nothing leaves the device
unless the user picks a destination; the app has no server to send it to
anyway.

The file has three row shapes in one timeline: drinks logged in the app (with
volume and ABV — the physical facts), drinks imported from Apple Health
(count only, volume and ABV left empty rather than invented — ADR-0014), and
days recorded as alcohol-free (a recorded fact, kept distinct from days with
no data, exactly as the calendar tells them apart).

`standard_drinks` is expressed in the **current** region, like every total in
the app (invariant 3, ADR-0002), and a per-row `unit` column names that unit
so the file is unambiguous away from the app. Because volume and ABV ride
along, anyone can recheck the math or recompute under another definition.

The rendering lives in `DrinkTrackerCore` (`LogExport`), so the file's exact
shape is pinned by tier-1 tests that run in CI (invariant 9). The app side
(`LogExportFile`) only fetches rows and writes the file — at share time, off
the main actor.

## Consequences

- "Show this to my doctor" now has a real answer, and it is the record
  itself, not a summary of it. No aggregate leaves the app that a reader
  didn't compute themselves — ADR-0006's boundary holds by construction.
- The CSV column layout is now a public contract. Renaming or reordering
  columns breaks whatever spreadsheets or scripts users have pointed at old
  exports; additions go at the end, and the tier-1 tests exist to make a
  breaking change deliberate rather than accidental.
- An export is a snapshot in the region current at the moment of export. Two
  exports made under different settings disagree in the totals column while
  agreeing in volume and ABV — which is the invariant working as intended,
  but worth a support answer some day.
- Timestamps render in the device's current time zone (the same lens the
  app's own day-grouping uses). A travel-heavy log re-expresses, as
  everything else does.
- No bulk *import* of the CSV. The export is one-way; the file format is not
  an ingestion contract.

## How to reopen

- If real users ask for a summarising report (ranges, weekly totals) to hand
  over, that is a new decision that must be argued against ADR-0006 — the
  summary/score boundary — not slipped into this one.
- If a machine-readable consumer appears (a research export, another app),
  add a second format alongside the CSV rather than bending this one; the
  CSV's audience is people.
