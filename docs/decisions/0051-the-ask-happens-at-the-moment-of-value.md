# 0051 — The ask happens at the moment of value

**Status:** accepted · **Date:** 2026-09-21 · **Relates to:** ADR-0050 (the
app pairs, it does not conclude; the card whose shape the offer borrows);
ADR-0049 (health context is read, never stored; the pairing's own
authorization request and the invisible-denial rule this record inherits);
ADR-0048 (the gate the offer waits for); ADR-0014 (the beverage import,
the app's other read of Health, asked for from its own screens); ADR-0038
(a switch is how a reader chooses what Trends shows);
`docs/tallyist-health-pairing-plan.md` ("The ask");
`docs/design/health-pairing/README.md` (surface 3, and the owner's decision
on accepting)

The fourth of the health pairing's records, written in Phase 3 with the
offer. The plan reserved a number for it that the watch took; the next free
one is this.

## Context

A read of Health needs the person's permission, and the app has to ask for
it somewhere. The obvious places are onboarding (where the beverage
permission already has a screen, ADR-0014), a sheet on the first launch
after the update, or a banner on Trends until it is answered. Each asks for
"heart rate" in the abstract, from a screen that has nothing to show for
it, and each is a permission prompt for a figure the app may then never be
able to draw — a log with three drinking nights cannot clear ADR-0048's gate
whatever Health holds.

The plan wanted three properties, in order: it waits, it shows before it
asks, and it asks once. The owner's design added the shape (the table card
itself, with the figure cells blank), the fact that the offer covers every
row the build ships rather than one metric, and the rule for what accepting
turns on. Two things were left to this record: what "the log clears the
gate" means for an offer, and what a per-device flag does on a second
device.

**Which side gates the offer.** The design's text gates it on the drink side
alone. The table's gate is both buckets (the plan's third rule), and the
second bucket holds nights *recorded* as no alcohol (ADR-0048), which is not
plentiful by nature — a reader who never marks a day has none. An offer
gated on one side could be accepted, the read granted, and nothing appear:
a silent broken promise, and the one way this feature could look like it
asked for data and did nothing with it.

**Where the answer lives.** Every flag in `AppSettings` is device-local (the
App Group; nothing syncs), so the offer's answer is too. The design's
acceptance check wants the offer never to return "across iCloud sync".

## Decision

1. **It waits for the log, on both sides.** The offer exists only when the
   drink log alone — no Health read — clears the gate in both buckets for
   the current range: fourteen nights with drinks logged *and* fourteen
   recorded as no alcohol, whole nights ended by the day the render is made.
   Before that there is nothing to show and therefore nothing to ask for.
   The same condition is what lets the card be drawn at all, so an accepted
   offer with a granted read shows a row unless Health has fewer nights with
   a value than the log has nights — the one gap that cannot be closed
   before the read, and one the source note names ("A night without a
   reading is not counted").

2. **It shows before it asks.** The offer is the card's own shape
   (ADR-0050): the heading "From Apple Health", the title, the two heads,
   the metric's name, and "– –" in tertiary ink where the figures would be.
   The only real numbers on it are the reader's own — "36 nights with drinks
   logged and 48 recorded as no alcohol, last 13 weeks" — from the log, so
   they are the same for every row and stated once. Then three sentences
   saying what it is ("Apple Watch records this every day. Tallyist can show
   it here, beside your log. It is read from Apple Health on this device and
   never stored."), one primary action ("Show this on Trends") and one text
   button ("Not now"). The placeholders say nothing to VoiceOver; the spoken
   card is the body, the title, the row's name, the counts and the two
   buttons, in that order.

3. **It asks once, and both answers are final and silent.** One boolean,
   `hasAnsweredHealthPairingOffer`, set by either button — and by the
   Settings switch being turned on, because a reader who has met the
   system's sheet from there has answered the question the offer asks, and
   showing them the card later, should they turn the switch off again, would
   be the plan's "nagging someone who already said yes" — and read by
   nothing but the section's `resolve`. Which way it was answered is not stored: a
   later metric arrives switched on for anyone with a pairing switch on and
   off for everyone else (the design's decision 1), and the switches already
   say which. Declined means gone — no second card, no banner, no mention
   anywhere; the Settings switch is the way back, and the app does not
   point at it. Accepted means the offer is answered, the system's sheet
   asks for the read (`requestPairingAuthorization`, ADR-0049 — the
   pairing's types and nothing else), and then the switch turns on, in that
   order, so the read the switch triggers happens after the sheet has been
   answered rather than under it. What follows the sheet is whatever the
   read produces: a row, or nothing (ADR-0049's one no-data state, on the
   surface). The app is not told which, and does not pretend to be.

4. **Once per device.** The answer is device-local like every flag in
   `AppSettings`, and the permission it leads to is device-local too:
   HealthKit's answer belongs to the phone it was given on, and a second
   phone or an iPad with Health syncing has to be asked by the system
   anyway. So a reader who answered on one device meets the offer once more
   on another, and that is the one exception to "never again" — recorded
   here rather than hidden, and not what the design's check assumed.

5. **Not in onboarding, not as a sheet, not as a notification.** The offer
   is a card in the table's place on Trends, under the heading the table
   will have, and nowhere else. Onboarding is refused because the gate
   cannot have cleared; a sheet because it would interrupt a screen the
   reader opened for something else; a notification because ADR-0017's
   third hard rule forbids one and the plan's stop conditions extend it to
   the body.

## Consequences

- **A reader who never marks a day is never asked.** The second bucket's
  fourteen come only from `AlcoholFreeDay` markers, so a log of drinking
  nights alone, however long, does not clear the gate and the offer does
  not appear. The switch in Settings is still theirs, and turning it on
  reads nothing until the log clears — which is the row's own rule, not a
  second gate. This is the cost of gating on both sides, and it is smaller
  than the alternative's: an ask that leads nowhere.
- **The offer's card leaves before the sheet arrives, not after.**
  Accepting sets the answer first, so the section stops drawing the offer
  in the same frame the system sheet begins to present; when the sheet is
  answered and the switch turns on, the row fades in if the read produced
  one. The design described the card *becoming* the table. Keeping the offer
  on screen until the read returns would need the section to know that a
  load is in flight for an offer just accepted — transient state for a
  transition that happens once, under a sheet that covers it — and it is not
  built. The reopen below says what it would take.
- **The one-time behaviour holds across range changes and relaunches**, and
  was watched on the simulator: "Not now" removed the card and the heading,
  a relaunch at Quarter showed neither, and the App Group held the answer
  and the switch off — nothing else. Across devices it holds once per device
  (decision 4).
- **The counts on the offer are the log's, not Health's**, so the offer can
  never leak the answer before the question. The card's own caption after
  acceptance counts nights with a *reading*, so it can show fewer than the
  offer did — the same numbers only when every night in the log had one, as
  the seeded simulator's did — and the source note says why ("A night
  without a reading is not counted").
- **The purpose string under the system sheet is the beverage one.**
  `NSHealthShareUsageDescription` is about alcohol samples, and the sheet
  Phase 3's simulator run showed it above a request for resting heart rate.
  Phase 7 rewrites it (the plan's release section); this record notes the
  mismatch and does not fix it early, as ADR-0049 asked.

## How to reopen

- **If the offer should stay on screen until the read returns**, the
  section needs one more input: whether a load is in flight for a request
  whose offer was just accepted. The cleanest form is a flag on
  `HealthPairingModel` that `load` clears and the accept sets, read only by
  `resolve`; the offer would then be drawn while the flag is set and the
  figures are nil, and drop the moment the load completes either way. It is
  one flag and one condition, and it is not built until someone sees the
  transition and minds it.
- **If the answer should follow the person rather than the device**, the
  flag would have to sync, which no flag in the app does; the reopen is a
  synced settings store, not a special case for this one, and it would have
  to answer what a synced "declined" means on a device whose system sheet
  has never been shown.
- **If a later phase ships a second metric**, the offer covers both rows,
  its copy returns to the design's plurals ("Show these on Trends", "Your
  watch already records these"), and a reader who has already answered is
  not asked again — the design's decision 1 says the new metric's sheet
  appears on the next visit to Trends for anyone who accepted, and the
  ADR-0049 reopen names the one authorization question HealthKit permits
  for knowing whether that sheet is still needed.
