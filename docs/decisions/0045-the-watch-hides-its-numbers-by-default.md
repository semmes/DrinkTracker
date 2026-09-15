# 0045 — The watch hides its numbers by default

**Status:** accepted · **Date:** 2026-09-14 · **Relates to:** ADR-0007 (the
outline as the off-ramp channel); ADR-0034 (the counter carries the day's
colour); ADR-0042; `docs/tallyist-watch-plan.md` ("What the wrist exposes",
Phase 3, Phase 6); `docs/design/watch/README.md` (screens 2 and 6, open
questions 3 to 5)

Numbered out of sequence on purpose: the plan reserved 0044 for the session
dot row and its contrast table (Phase 5), and this record was written in the
phase that first built what it governs.

## Context

Every surface Tallyist has shipped goes dark on its own. A phone screen
locks; the home-screen widget's families are Home Screen families, so seeing
them means the phone is unlocked and in the user's hand; the app is behind
whatever the phone is behind.

A watch is not like that, in two specific ways. **Always-On Display** keeps
the frontmost app visible in a dimmed state when the wrist drops, so a screen
reading "5" stays legible on an arm resting on a bar, to anyone across the
table. **Complications are public by construction**: a watch face is visible
to everyone who looks at the wrist, all day, with no unlock step.

For most apps that is a non-issue. For this one it is close to the centre of
the product: a judgment-free tracker whose value depends on the user being
honest with it, on a surface that can show a stranger their count. Someone who
would log a fifth drink on a phone in their pocket may not log it on a wrist
the table can read, and an app that quietly suppresses logging is worse than
no app.

The owner's design added one thing to the plan's posture: **a tap on the
tile puts the digits away while the band stays lit**, so the day's amount is
still fully stated by colour to its owner, and a wrist on a table shows
everyone else a blue square. The design asked whether that hide should be
per-glance or stored, and whether it should govern the complications. The
owner answered (2026-09-14): per-glance, and so it does not.

## Decision

**Every count on the watch is `.privacySensitive()`** — the numeral, the ≈
figure, and in Phase 6 every complication family. Redaction then follows the
system: the app's numbers redact in Always-On, and complications redact when
the watch is off the wrist, which is the behaviour a user would expect if
they thought about it and will never think about.

**Redaction shows a glyph, never a blank.** Under Always-On the tile's fill
goes too — once the digits are gone the colour *is* the figure — falling to
the outline channel (ADR-0007's own signal), the drop glyph returns so the
screen does not read as broken, the unit word stays, and the legend's swatches
empty to outlines. A complication that looks broken gets removed from the
face, which loses the feature entirely.

**A tap on the tile hides the count, per glance.** View-local state, cleared
on launch, never persisted, and it never gates a write. Suppressed: the
numeral (replaced by a struck-out bar in the band's ink, so the screen reads
as withheld and not as loading), the ≈ line, and the four legend labels — a
label reading "3–5" is as readable across a table as a count, and hiding the
numeral while leaving the ranges named would be theatre. Kept: the tile's
fill, the swatches, the unit word, both controls. "Tap again to show the
count" appears in the hint's slot for a moment. The numeral and the bar
crossfade; nothing rolls, because hiding is a change of subject, not of
value.

**Hiding does not change what VoiceOver speaks.** A screen reader is not the
audience the tap protects, and silencing the value would make the feature an
accessibility regression dressed as privacy. Each legend band stays one
element with its range as the label, labels visible or not.

**The general rule:** the watch shows what the user already knows and hides
it from everyone else by default. If a future surface has to choose between
glanceable and private, private wins, because this product's failure mode is
a drink that never gets logged.

## Consequences

- **Residual exposure, stated plainly.** A passer-by can still see that the
  tile matches the third of four swatches. They cannot see what the third one
  means. That is a real reduction, not a total one.
- The hide is discreet *after* the wrist is on the table, not before. A
  stored preference would be discreet before — but it needs a switch, the
  watch has no real Settings screen, and it would then have to govern the
  complications too, since a face needs no unlock. The owner chose per-glance
  with that cost named.
- The complications are protected by the system's redaction alone (Phase 6),
  which is what the owner's fourth answer means in practice.
- A reader who hides the count and raises the wrist again finds it hidden
  until they tap or relaunch. That is the feature.

## How to reopen

- If use shows the per-glance hide is the wrong grain — people want it
  discreet before the table, every time — the reopen is a stored, watch-local
  preference (it changes what is shown, not what is computed, so it does not
  cross the settings bridge), a switch to hold it, and the complications
  following it. That is a new decision with its own record.
- If `.privacySensitive()` renders in Always-On or on a face in a way that
  reads as broken (the design's fifth question, a Phase 6 device check), the
  redacted forms here are what change, not the policy.
- If Apple ships a per-app Always-On opt-out that reads as more honest than a
  redacted tile, the app takes it and this record's redaction section
  retires.
