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

That sentence turned out to be a *requirement*, not a description, and an
adversarial review of this change found three places the code could break it.
All three are fixed here, and they are the reason the rule is worth stating:

1. **Zero writes nothing.** `forIntent` used to clamp quantity up to 1, so a
   Shortcuts automation whose count evaluated to 0 — or a spoken "none" —
   wrote a real drink, cleared that day's alcohol-free marker, and mirrored
   the fabrication into Health. It now returns nil for a non-positive
   quantity and the intents say "Nothing was logged." Every in-app counter
   already treats 0 as a real answer (the day sheet reaches it; bulk fill
   reads it as *no alcohol*), so the intent path was the only one in the app
   that could invent a drink. **The log may under-record; it must never
   over-record.**
2. **The no-alcohol reply can't outrun its write.** `markAlcoholFree`
   returns "was it refused?", not "did it persist" — it swallows a save
   failure — so the intent could speak "Recorded today as no alcohol." with
   nothing written. In the app that self-corrects, because the marker is
   re-read from a live query; a spoken claim doesn't get that chance. The
   intent now uses `markAlcoholFreeOrThrow`, the exact pattern `saveOrThrow`
   already established for out-of-app writes.
3. **A partial write reports the true count.** Each drink is its own
   transaction (invariant 7), so a failure partway through leaves the earlier
   drinks durable. Throwing there would tell the user everything failed while
   some of it hadn't — and saying the phrase again would write those drinks
   twice. `LogDrinkIntent.write` returns what actually landed and reports
   that; only a total failure throws, because only then is "it failed" true.

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
