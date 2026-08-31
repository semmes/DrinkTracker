# 0024 — The published documents live in their own public repository

**Status:** accepted · **Date:** 2026-08-31 · **Supersedes / superseded by:** —

## Context

The App Store listing registered two URLs that pointed into this repository:
the Privacy Policy URL and the Support URL, both `blob/main/docs/…` paths. That
worked, and App Review accepted it for 1.0. What it also did — invisibly — was
make the correctness of a *live listing* depend on this repository staying
public. Making the source private would have returned 404 for both, breaking
guideline 5.1.1 and 1.5 for an app already shipping, not merely for the next
submission.

The question that surfaced this was whether the source could go private. But the
coupling is worth breaking regardless of that answer, and this record should not
be read as deciding it. A repository rename, a transfer, a default-branch
change, or moving the docs directory would each have broken the same two URLs
just as completely. The listing was one routine refactor away from a dead
privacy policy at any moment.

The competing option is real: keep everything here and simply commit to never
making the repository private or restructuring it. That is genuinely simpler —
one repository, one commit per policy change, no mirror to keep honest, and the
"public source repository" claim in the policy stays true for free. It was
rejected because it makes an ordinary maintenance decision permanently expensive,
and because the constraint it imposes is invisible: nothing in the repository
would have told a future maintainer that renaming it breaks the App Store
listing.

A second option — move the canonical text out of this repository entirely — was
rejected for the opposite reason. The policy's claims are written to be checkable
against `PrivacyInfo.xcprivacy`, the entitlements, and the absence of networking
code, and the support page's answers describe shipping behaviour. Both belong
next to the code that has to keep them true, and both should change in the same
pull request as the feature that changes them.

## Decision

The privacy policy and support page are published from a separate public
repository, `semmes/Tallyist`, served by GitHub Pages at
`https://semmes.github.io/Tallyist/`. App Store Connect points at
`/privacy/` and `/support/` there. Support moves to that repository's issue
tracker.

The canonical text stays here under `docs/`. The published copies are mirrors,
and the two must be byte-identical in body.

## Consequences

The listing no longer depends on this repository's name, structure, or
visibility. The policy's claim that every change to it stays visible in a public
history now rests on a repository whose only purpose is to be public, rather than
on a side effect of how the app happens to be developed — which is a stronger
guarantee than the one it replaces, not merely a relocated one.

What is now harder:

- **The policy has three copies, not two.** `docs/privacy-policy.md`,
  `PrivacyPolicyView.swift`, and `privacy-policy.md` in `semmes/Tallyist`. All
  three carry the same "Last updated" date.
- **A policy change can no longer be atomic.** Two repositories means two
  commits, and nothing currently fails if the mirror is forgotten. The
  house rule is the only guard, and house rules are weaker than CI. Drift here
  is not cosmetic: the published copy is what App Review and users actually
  read.
- **Old installs keep the old link.** `PrivacyPolicyView.hostedURL` is baked
  into every shipped binary. Users on 1.0 and 1.1 will hold the
  `github.com/semmes/DrinkTracker/blob/…` URL forever, so if this repository
  ever does go private, "Read this policy online" 404s for them and cannot be
  fixed retroactively. The full policy text ships natively and reads offline, so
  those users still have the policy itself — they lose the link, not the
  document. That cost is accepted here explicitly rather than discovered later.

This ADR does **not** make the source repository private. It removes the
listing-breakage objection to doing so; the remaining considerations, including
the GitHub Actions cost of macOS runners on a private repository, are a separate
decision.

## How to reopen

If a published copy ever ships out of step with the app's — the failure this
trades for the old coupling — the mirror should stop being a house rule and
become a GitHub Action that pushes `docs/privacy-policy.md` and `docs/support.md`
to `semmes/Tallyist` on merge to `main`. That was deliberately not built now: it
needs a cross-repository token stored as a secret, which is real setup and a real
credential to rotate, and one manual mirror step per policy change is cheaper
until drift actually happens.

If the source repository is never made private and never restructured, this
separation buys less than it costs, and the documents could be folded back — but
the stable, code-independent URL would be given up in doing so, and that is worth
keeping on its own.

## Amendment (2026-08-31): the mirror is enforced, not trusted

The "How to reopen" above said the mirror should become automation *if a
published copy ever shipped out of step*. The owner chose to build it
immediately instead, before that had happened. Recording the reasoning, because
this reverses a judgement made the same day and the original reasoning was not
wrong so much as differently weighted.

What changed is the assessment of the failure's cost, not its likelihood. The
original argument was that one manual step per policy change is cheap and drift
is unlikely. Both remain true. But the failure is silent, it is discovered by
the wrong people — App Review, or a user reading a policy that does not describe
the app they are holding — and the interval between causing it and noticing it
is unbounded. A rule that is cheap to follow and catastrophic to forget is a bad
candidate for human memory, however easy it looks.

Three guards now exist, at different distances from the mistake:

- **`policy-copies`** in `ci.yml` fails a pull request whose two in-repository
  copies disagree on their "Last updated" date. No network, no secrets, runs on
  Linux. This catches the common human error — editing one copy — before it
  merges.
- **`mirror-docs.yml` / `sync`** renders `docs/privacy-policy.md` and
  `docs/support.md` into their published form and pushes them to
  `semmes/Tallyist` on merge to `main`. Nobody has to remember the step.
- **`mirror-docs.yml` / `verify`** compares the published copies against this
  repository on a daily schedule. This is the one that matters most, and the one
  that would have been easiest to leave out: it catches a published copy edited
  directly, *and* it catches the sync having silently stopped — an expired token
  is indistinguishable from a quiet week.

The sync deliberately does not run on the schedule. A scheduled job that both
detects and repairs drift would keep the published copies correct while hiding
that the merge-triggered path had broken, which trades a loud failure for a
quiet one.

The token remains the cost this was avoiding, and it has not gone away:
`TALLYIST_SYNC_TOKEN` is a fine-grained personal access token scoped to
`semmes/Tallyist` with Contents: write, and it expires. When it does, `sync`
starts warning and `verify` starts failing the first time the copies actually
diverge — which is the correct order for those two to fail in. Until the token
is configured, `sync` warns rather than failing, so the absence of automation
never looks like a broken build; only real drift does.

## How to reopen (revised)

If the mirror machinery itself becomes the thing that breaks — a token nobody
rotates, a scheduled workflow GitHub disabled after 60 days of inactivity — the
honest move is not more automation but fewer copies: move the canonical text
into `semmes/Tallyist` and have this repository verify its Swift copy against
the published one instead. That trades the atomic "policy and code change in one
commit" property for having only one place the text can be wrong, and would be
worth it if the mirror needs more attention than the text does.
