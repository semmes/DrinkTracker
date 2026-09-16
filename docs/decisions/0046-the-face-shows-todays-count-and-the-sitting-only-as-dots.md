# 0046 — The face shows today's count, and the sitting only as dots

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** ADR-0017 (the
session's three hard rules); ADR-0034 (the counter carries the day's colour);
ADR-0044 (the session as dots, and its switch); ADR-0045 (the watch hides
its numbers by default); ADR-0019 (`LogOneDrinkIntent`, the widget's
parameterless ＋); ADR-0041 (the watch store fills from CloudKit); PRD
invariants 1 and 10; `docs/tallyist-watch-plan.md` (Phase 6);
`docs/design/watch/README.md` (the complications table and its decisions)

## Context

The plan gives the four complication families one content rule: "the session
count while a session is running, today's count otherwise — the same thing
the home-screen widget shows, no more." The two halves of that sentence do
not agree. The home-screen widget shows today's count and nothing about a
sitting (`QuickLogProvider.currentEntry` reads `drinks(on: now)`), and the
plan and design both use it as the reference the face should match.

Read literally, the rule also produces two things the rest of the product
refuses. A number on the face that means one thing during a sitting and
another after it — with only a small unit word to say which — is a numeral
whose meaning changes under the reader, and at the moment a session ends the
face would *rise*, from "3 this session" to "4 today", which is the standing
number the tone rules exist to prevent, arriving by another door. And a
numeral in a band has to be described by the band (invariant 10, ADR-0034's
"nothing out of sync"): a session count inside the day's colour would put a
3 in the 6–9 fill.

The face also has a hidden state drawn for it, and the owner has answered
that the per-glance hide does not govern complications (the design's fourth
question): the system's redaction is what protects a public surface.

Two things the drawing could not know. The real rectangular family is about
177 × 80pt on a 46mm watch, not the 264 × 118 the design drew; built at the
drawn sizes, the card truncated its words to "drin…" and "≈ 3 st…" on the
simulator's Smart Stack. And the unit noun the drawing sets at 62% of the
band's ink composites to 4.17:1 on the 1–2 fill and 3.51:1 on the 3–5 fill —
under 4.5:1 for text that size, a new unvalidated ink (invariant 10).

One thing the plan could not know either: on the wrist the phone is the
dominant writer. A drink logged on the phone reaches the watch's store by
CloudKit in seconds (ADR-0041's measured latency) and updates the counter's
query — and nothing in that path would reload a complication. "Reload after
every write on the watch" covers the watch's own writes only; without more,
an evening logged on the phone never reaches the face until midnight, when it
resets to zero.

## Decision

**Every family shows today's count in the day's band** — the tile shrunk to
a disc, keeping its job, the same `DayIntensity.bucket` over the same total
as the counter and the calendar cell. The circular family carries the numeral
and the unit noun in the band's ink at full strength; the corner the numeral
in the disc and the day's words along its curve — the words, never the
count; the inline family the glyph and "N drinks today"; the rectangular card
the tile at 44, the unit word and a 44pt ＋, the ≈ line not shown (the
home-screen widget's small family makes the same trade). The home-screen
widget's two reviewed strings name the complication. A day recorded as no
alcohol shows the alcohol-free glyph in place of the numeral, with Today's
own sentence beside it — on the inline line, the corner's curve and the
card, and spoken by every family; the circular disc shows the glyph alone,
having no room for words.

**Amended 2026-09-15, on the owner's device pass: the circular family shows
the numeral and nothing else.** It had carried the design's unit noun
beneath the count, and on a real face a 50pt disc reading "1 drink" is a
sentence where a glance wants a number. The noun is not lost — the face
draws its own label under a complication, the corner's curve and the card
still carry "drinks today", and every family speaks the full "N drinks
today" to VoiceOver. The numeral takes the room the noun had (30 → 34).
Both bare nouns retire from the complication's catalog.

**The sitting appears only as dots**, on the rectangular card, on a row of
its own beneath, while `SessionPace.currentSession` returns a value **and the
watch's own "Show session pace" is on** — the sitting is a surface the wrist
opts into (ADR-0044, ADR-0017), and the card follows the counter's switch.
Through the same `SessionDots` view and the same band rule as the counter.
Never as a number on the face.

**The timeline carries an entry at each moment the face would change on its
own.** While a sitting runs: one at each drink's exit from the two-hour
window, where the dots' band drains (the counter recomputes it every minute;
the face must not lag it by up to two hours), and one at `lastDrinkAt +
gapThreshold` carrying the post-session state — nothing else wakes a
complication when a session ends, and without it a dead sitting's dots would
sit on the face. The refresh is the earlier of the session's end and the
next midnight. All entries derive from one read of the store: the session
and its band are functions of the drinks and the clock.

**The face follows the store, not only the wrist's writes.** Every write on
the watch reloads all timelines — the counter's ＋, −, the picker's log and
the no-alcohol record, which the phone's store skips because its widget
draws nothing for a marker and the face does. And the watch app observes
`NSPersistentStoreRemoteChange` and reloads once a CloudKit import settles
(coalesced over two seconds), plus on every raise of the app. The residual,
stated: an evening logged entirely on the phone with the watch app never
launched reaches the face when the system next runs the app for a CloudKit
push, or at the next raise — not within seconds.

**The ＋ is the rectangular card's, through `LogOneDrinkIntent`** — the
owner's answer to the design's second question, and the one intent that is
parameterless and so cannot repeat the dispatch bug a promptable parameter
once caused. Invariant 1 extends to the face with no new argument: the intent
reads the seed and the region from the App Group, the same rule as every ＋.

**Redacted, each family shows the drop glyph and the plural words with the
figure gone**, never a blank; the band's fill goes with the figure, since
once the digits are gone the colour is the figure (ADR-0045), and the words
are the plural because a singular noun under a glyph is a count of one. The
same form when the store cannot be opened, with no ＋: the face prints no
figure it cannot back.

**Redaction wins over the marker, and over the spoken label.** A day
recorded as no alcohol redacts to the same drop glyph and the same words as
every other day: if the drinking days went behind the glyph while the dry
ones kept their check, the glyph itself would state what the reader did, and
a locked watch on a table would sort their days into two kinds. For the same
reason the accessibility label follows the pixels — the system redacts a
numeral it draws, not a label written by hand, and a locked face that speaks
"5 drinks today" is the disclosure the glyph exists to close. ADR-0045's
"hiding does not change what VoiceOver speaks" governs the user's own tap on
the counter, where the audience is the user; this is the system's lock,
where it is not. The hidden state the design drew for the circular
family is not built.

**No relevance-based surfacing.** The card appears in the Smart Stack because
the user put it there; nothing pushes it forward by time or place.

## Consequences

- A VoiceOver user with the watch off the wrist hears "drinks today" and not
  the count, which is a real loss of information to the one reader who most
  needs it spoken. It is the same loss the screen takes, and it lasts until
  the watch is back on the wrist.
- The face never contradicts the counter, given a reload: the number on the
  wrist's face is the number on the wrist's screen, and the dots' band on the
  card is the row's band at that minute.
- A reader who wants the sitting's count reads it on the counter; the face
  shows the sitting's shape, not its number — and only if they turned the
  row on.
- A phone-logged drink reaches the face seconds after the counter while the
  watch app is running or is run for the push, and at the next raise
  otherwise. That is the platform's shape, not the product's choice.
- The plan's Phase 6 sentence is superseded by this record; its second half
  was the intent.
- The design's "… hidden" circular is unbuilt by the owner's own decision;
  the record for that is ADR-0045. The design's 62% noun and its 70pt tile
  are not built, for the measured reasons above.

## How to reopen

- If the owner wants the session count on the face after all, it is one
  rule in `CounterProvider.Snapshot.entry`: the numeral and the band would
  both switch to the sitting's drinks together, never the numeral alone.
- If the ＋ is wanted in the circular family, the whole circle becomes the
  button and the count goes — the trade the design named.
- If the face lags the phone on hardware more than a raise away, the reopen
  is Phase 7's channel used for a reload signal rather than a row — a
  `WCSession` message that asks the watch to reload, carrying no data.
