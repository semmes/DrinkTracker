# 0019 — Siri logging splits instant from conversational, and never coaches

**Status:** accepted · **Date:** 2026-08-27 · **Relates to:** PRD invariants 1,
7, 8; ADR-0003, ADR-0011 (the marker rule), the widget-resolution lesson in
`LogDrinkIntent`

## Context

The user asked for Siri support: log a drink by voice — type, size, ABV, how
many — and record a no-alcohol day. In Apple terms this is App Intents, the
same machinery behind Shortcuts, Spotlight, and the Action button, and it is
the hands-free accessibility path for logging.

The design tension is inherited from the widget's hardest-won lesson: **a
parameter the system may need to ask for is a parameter that silently breaks
a widget button** (a widget cannot prompt; the tap is abandoned before
`perform()`). Siri is the opposite: prompting is how voice collects specifics.
One intent cannot serve both masters.

## Decision

**Two intents for typed logging, split by whether prompting is allowed:**

- **`LogDrinkIntent` (instant).** The widget's intent, extended with optional
  size/ABV and a defaulted quantity — *optional and defaulted are load-bearing*:
  nothing on it can ever prompt, so the widget tap stays unbreakable and the
  Siri phrase "Log a beer in Tallyist" logs immediately at the type's
  defaults, the same entry every other fast path produces (invariant 1 by
  voice). Specifics ride along only when a Shortcuts shortcut sets them.
- **`LogDrinksIntent` (conversational).** Type and count have *no defaults*,
  so Siri asks — "Which drink?", "How many?" — which is what makes
  voice-specified logging possible. Size and strength stay optional:
  requiring them would read a form aloud (gate-before, by voice). Never
  placed on a widget, for exactly the reason it works with Siri.

**`RecordNoAlcoholIntent`** marks today through the same repository rule the
app uses: a day with entries refuses the marker, and the refusal is spoken as
a fact — "Today already has drinks logged, so it wasn't recorded as no
alcohol." Nothing failed; the record already says something else. Logging
drinks by voice likewise removes a same-day marker, because every write path
shares `saveOrThrow` (evidence beats assertion, whoever says it).

**Bounds are the app's own bounds** (`DrinkDraft.forIntent`, tier-1 tested):
unspecified values fall to type defaults; ABV clamps to the type's slider
range; quantity clamps to the counter's ceiling of 12 — and N drinks are N
entries, never a count on one (invariant 7 holds against "log five beers").

**Health is untouched from intents**, same asymmetry as the widget: entries
land with no sample id and `backfillHealthKit` sweeps them on next app
foreground. One Health story for every out-of-app write path.

**Every spoken reply is a statement of what was written** — "Logged: Beer,
12oz, 5% ABV.", built on `summaryLine` so all surfaces render a drink
identically. No congratulation, no totals, no "great job" (invariant 8 does
not relax for audio).

## Consequences

- Four App Shortcuts (instant-typed, habit-seeded one-drink, conversational,
  no-alcohol) with phrases like "Log a beer in Tallyist" and "Record no
  alcohol in Tallyist". Phrase parameterization covers the type; numbers
  can't live inside phrases (an App Intents limit), which is why the
  conversational intent asks instead.
- The instant/conversational split doubles the intent count for one concept.
  Deliberate: collapsing them either breaks the widget or makes voice unable
  to ask. The split is documented at both definitions.
- Simulator gotcha, recorded for future sessions: running App Shortcut
  *tiles* from the Shortcuts app fails in the simulator (linkd:
  "Couldn't find AppShortcutsProvider" / invalid-bundle rejection). The
  intents themselves run fine as manually added actions; true phrase
  invocation is a tier-4 device check.

## How to reopen

- If real users ask to specify size/strength by voice mid-conversation, make
  those parameters promptable on `LogDrinksIntent` only — never on
  `LogDrinkIntent`, which must stay prompt-free for the widget.
- Any push toward Siri-initiated suggestions, reminders, or proactive
  phrases ("time to log?") is not a reopen; it is a notification about
  drinking by another door, and the spec's stop conditions already close it.
