# 0023 — The counter can log a standard drink with no type

**Status:** accepted · **Date:** 2026-08-29 · **Relates to:** ADR-0009 (revises
its seed rule), ADR-0002, ADR-0005, ADR-0016, ADR-0022 · **Source:** user
report, 2026-08-29

## Context

ADR-0009 made the counter the primary control and settled what a count
*records*: N real, typed entries seeded from the type the user logs most
often, at the size and strength they last logged it. Its own Consequences
section stated the trade in the open — "a counted drink inherits the user's
habits, not a neutral unit" — and argued that this is *more* accurate for
each user, since a habitual spirit drinker's "3" really does weigh more than
a wine drinker's "3".

The second field report says that argument has a blind spot, and names it
precisely:

> Make it one tap and it saves a standard drink without the type because I get
> bogged down switching between the types of alcohol. The drink type and abv
> should be optional details I can choose to add or skip but still track.

The seed rule assumes a *habit* to inherit. Someone who drinks varied things
has no plurality worth inheriting, so the counter hands them a type they did
not choose — and the response is to open the typed path and switch it, which
is the exact friction the counter exists to remove. Worse, the wrong seed is
not visibly wrong: the row says "Wine, 5oz, 12% ABV" in the same voice it uses
for a wine the user actually described.

There is also a plainer point underneath. "One drink" is a complete statement.
The app's own unit — the standard drink — is defined without reference to what
kind of drink it was, and refusing to record the statement the user made,
because a field the user left blank has no default, is the app asking a
question it does not need answered.

The competing option is to leave ADR-0009 alone and treat this as a case for
the existing typed path: the user can log wine explicitly whenever it is wine.
That is a real argument, and it is what the app has been saying. It loses on
the report's own terms — the typed path is where the friction is — and on
honesty: a seeded type is a claim about a drink, made by the app, on evidence
that is nothing more than "you often drink this."

## Decision

**A drink can be logged as one standard drink with no type.**
`DrinkType.unspecified` is that state — not a fifth category, the absence of
the category question. It is excluded from `DrinkType.selectableCases`, so no
picker offers it; it is reached by logging a count, and left by adding details.

**What it stores, and why it is not a beverage.** Volume and ABV are the
ethanol a standard drink is *defined* as: the current region's
`flOzPureAlcoholPerStandardDrink`, at 100%. Materialising 12 oz at 5% instead
was the obvious alternative and is wrong twice — it claims a beer nobody
mentioned, and it freezes the US definition into a UK user's log. The
definition is the one fact actually in evidence, so it is the one stored.

**Never zero-volume, which is the ADR-0022 lesson applied forward.** A
zero-volume row is exactly the shape that produced the field bug. A build
predating this case decodes the type through `DrinkType(rawValue:) ?? .other`,
so on a 1.0 or 1.1 device an untyped drink reads as `.other` — and if it also
had no volume it would be indistinguishable from the empty "Other, 0oz, 0%"
rows, repeatable and absorbing. With real facts, the worst an older build does
is label it "Other" and show 0.6oz at 100%: an odd-looking row whose
arithmetic is exactly right in every region, and which repeats to another
honest standard drink. **Degrading to ugly beats degrading to false**, and a
pinned tier-1 test says so.

**The region stays a lens** (ADR-0002). These are physical facts, so a
US-logged standard drink re-expresses as 1.75 units under the UK setting,
exactly as a 12 oz 5% beer does. Freezing it at 1.0 under every lens would
have made these a second region-immune class alongside imports, and a day
holding one of each would report two arithmetics.

**The seed is now a setting, defaulting to the standard drink.**
`AppSettings.counterSeed` — Settings → "What the counter logs" — is either
`.standardDrink` (one standard drink, no type) or `.usualDrink` (ADR-0009's
rule, unchanged and still tested). Today's ＋, the calendar day sheet's ＋,
bulk fill, and the widget's ＋ all read it, so one rule governs every
count-first surface. The widget needed no new control: its ＋ is
`LogOneDrinkIntent`, which *is* the counter's mirror, so it follows the
preference by construction and no home-screen re-add is required.

**Type and strength become details you add or skip.** An untyped row uses
adoption's vocabulary and destination (ADR-0016): tap it, or swipe "Add
details", and the sheet asks for a type. Size and strength stay hidden until
one is chosen, because rendering the stored 0.6oz / 100% as a pill and a
slider would invite the user to correct a number they never entered. Choosing
a type replaces the definition with that type's own defaults. Skipping costs
nothing — the drink already counted.

**No surface prints the definition back as though it were a serving.** The
row reads "One standard drink · no size or strength recorded" — one key, which
is both the type's display name and the whole summary line, because a
"Standard drink" key case-collides with the region unit name under
`xcstringstool`'s symbol generation and fails the build. The CSV blanks the
size and strength columns while
the standard-drinks column still carries the amount. `recordsSizeAndStrength`
is the single predicate for this, covering imports and untyped drinks
together, since both recorded a count rather than a measurement.

**An untyped drink casts no vote for a type.** `mostLoggedType` skips them, on
the mirror of its existing reason for skipping imports: counting "no answer"
as a vote would let it win the plurality and hand itself back as the seed. A
log of nothing but untyped drinks returns nil, and the typed path falls to
beer as it always has.

## Consequences

- **This changes behaviour for existing installs**, deliberately. A user who
  liked the habit seed keeps it, but has to go and set it. The alternative —
  defaulting to the old rule — leaves the next person with this complaint
  hitting it first and hunting through Settings to fix it, which makes the
  default a bet on which user is more common. Face value is also the reading
  that cannot be wrong about a drink nobody described.
- **Trend lines can step at the switchover.** A habitual 8 oz / 12% wine
  drinker's nightly count was 1.6 standard drinks and becomes 1.0. Nothing
  already recorded changes, but a chart spanning the update shows the change
  in *what the ＋ means*, not in what they drank. Anyone who wants the old
  weight has the setting.
- **A fifth enum case touches every exhaustive switch.**
  `QuickLogDrinkType` is the one that matters, and it fails to compile rather
  than falling through — which is what it was written for. It gained a
  `standardDrink` case, so "Log a standard drink in Tallyist" works through
  the existing typed phrase (ADR-0019) instead of needing a fifth shortcut.
- **`DrinkType.unspecified`'s own `defaultVolumeOunces` is a US fallback**
  and must never be the construction path. `LoggedDrink.standardDrink(in:)`
  and `DrinkDraft.standardDrink(region:)` are region-aware, and
  `DrinkDraft.forIntent` routes to them; a future call site that builds
  `DrinkDraft(type: .unspecified)` directly would silently log US amounts to a
  UK user.
- **An intent that supplies a size for an untyped drink has its size
  ignored.** A caller who knows the ounces and the ABV is describing a drink
  they can name, and naming it is what the other four cases are for. Honouring
  both would write a row saying "no type stated" over facts that state one.
- **ADR-0005's invariant now has a case that satisfies it exactly rather than
  approximately.** Beer, wine, and spirit land on *almost* 1.0; the untyped
  drink is 1.0 by construction, in every region.
- Nothing here adds a permission, a network call, a notification, or a
  judgment. The setting is a recording preference, and both answers record.

## Revision (2026-08-31): the default seed remembers the day

The owner's tier-3 review of the first build accepted the standard-drink
start and rejected the "never learns" half: after describing a beer, the next
＋ re-logging a standard drink made the counter ignore the most concrete thing
it had just been told. The stated spec, adopted here verbatim as the
default's behaviour:

- A day starts at one standard drink, no type.
- The moment the user *describes* a drink — the sheet, Siri, adding details —
  the count means another of that drink, **for the rest of that day**.
- There is always a way back: "Record a standard drink instead" appears while
  ＋ is following a described drink, and logs one — which, as the day's newest
  entry, is also what ＋ repeats next. On Today it lives inside the "Log by
  type" disclosure with the other type-level controls (the owner's call: the
  counter area stays clear of a tap target beside the last-logged line's
  Edit); the day sheet keeps it visible under its caption, which has no such
  neighbour. The trade is accepted knowingly: with the disclosure closed the
  way back is a tap further away, and the follow state stays readable from
  the last-logged line, which shows the drink ＋ will repeat.
- Midnight resets. The next day starts at a standard drink again.

**The mechanism is the log itself — no stored mode.** The template is simply
the day's most recent repeatable entry (`DrinkDraft.dayTemplate`): typed →
repeat it; untyped → a fresh standard drink; imports never qualify
(ADR-0022's `isRepeatable`); other days never qualify, which is the whole of
the reset. Ordering is by the entry's own timestamp, because acts are not
recorded and evidence is — adding details tonight to this morning's entry
moves this morning, not now, and a later entry still outranks it.

This is day-scoped in both directions on purpose. Backfilling a past day in
the day sheet follows *that day's* described drinks; bulk fill only touches
blank days (ADR-0011), so its caption truthfully stays "one standard drink".
`.usualDrink` is untouched — it remains ADR-0009's whole-log plurality rule
for anyone who wants their habit inferred, and it has no day memory.

What this supersedes in the decision above: the claim that the default
"ignores the history entirely." It ignores *other days* entirely. The
mostLoggedType exclusion, the stored facts, the region lens, and every
no-definition-printed rule stand unchanged.

## Amendment (2026-09-02): what the release review added

- **An older build can make the degradation permanent.** The cross-version
  paragraph above covers the read side: a 1.0 or 1.1 binary decodes
  `unspecified` to `.other` and shows "Other, 0.6oz, 100% ABV", arithmetic
  intact. Its write side goes further. Saving that row from the 1.1 sheet, or
  repeating it with 1.1's ＋, rewrites `typeRawValue` as `other` — a genuine
  typed row — which 1.2 then prints as a serving (`recordsSizeAndStrength` is
  true), counts as an *Other* vote in `mostLoggedType`, and follows as a day
  template. Still exactly 1.0 per row. Not repairable by shipping; a field
  report reading "Other · 0.6oz · 100% ABV" is this, and the row goes by hand
  from History. A future revision could treat (`.other`, volume equal to a
  region's definition, 100%) as untyped, the way ADR-0022 treats zero volume.
- **The row's title is region-blind while its figure is lensed.** "One
  standard drink" is a fixed key that doubles as summary line, CSV entry, and
  spoken reply. Under the UK lens every total says "unit" while the row says
  "standard drink", and after a region switch the row reads "One standard
  drink" beside "1.8". The arithmetic is the lens working as ADR-0002 intends;
  the wording is a recorded tension, not yet a decision. Rendering the title
  through `StandardDrink.amountPhrase(drink.standardDrinks(in:), region:)` is
  the obvious route if it is ever taken.
- **The repeat control was the one construction site that copied a stored
  definition.** `DrinkDraft.repeating` now takes the region and rebuilds an
  untyped drink from it (PR #56), so "Another standard drink" and ＋ write the
  same amount after a same-day region change.

## How to reopen

If the standard-drink default turns out to *under*-record at scale — heavy
pours logged as single units, with the population reference or a Health export
reading low as a result — the honest fix is not to restore habit-seeding by
default but to make the size question cheaper at the moment of logging (a size
step on the untyped row, still skippable). Restore `.usualDrink` as the
default only on evidence that most users do have a stable habit and are being
mis-served by face value, which is the claim ADR-0009 made and this report
contradicted.

If a second `DrinkType` case is ever proposed for a *real* category, note that
this one is deliberately not a category, and the exclusion from
`selectableCases` is what keeps "unspecified" from appearing in a list of
beverages.
