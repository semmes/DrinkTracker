# 0008 — Two CI systems, one job each

**Status:** accepted · **Date:** 2026-08 · **Supersedes:** the App Store Connect API
key upload path (`.github/workflows/testflight.yml`, `docs/testflight-setup.md`)

## Context

GitHub Actions was set up first, because it was the only thing available from a
machine without Xcode. It grew three jobs — domain tests, an unsigned simulator
build, integration tests — plus a fourth workflow that archived and uploaded to
TestFlight using an App Store Connect API key.

That upload workflow **was never run.** It could not be tested without the secrets,
and its own setup document listed four places it was most likely to break first.

Xcode Cloud was then connected. The connection appeared to stall, but the actual
state was subtler: `semmes/DrinkTracker` had been granted, and the outstanding
prompt was for the `componentskit` organisation — a third party whose GitHub App
installation cannot be authorised by someone who is not an admin there. It also did
not need granting: both packages are public, and the Actions build resolves them on
every run with no credentials at all.

So the choice was not "which CI" but "what does each one do", with a real risk of
two half-working upload paths.

## Decision

**Xcode Cloud distributes. GitHub Actions verifies.**

| | |
|---|---|
| **GitHub Actions** | Domain tests, simulator build, integration tests — on every pull request |
| **Xcode Cloud** | Archive, sign, and upload to TestFlight |

`.github/workflows/testflight.yml` and `docs/testflight-setup.md` are **deleted**,
not disabled.

## Consequences

- **One upload path.** Two would each work often enough to be trusted and rarely
  enough to be dangerous, and the failure mode — a tester on a build nobody meant to
  ship — is not one worth courting to keep an untested workflow around.
- **No signing secrets in the repository.** The deleted workflow needed four,
  including a distribution key. Xcode Cloud is authenticated by the Apple ID already
  signed into Xcode, so there is nothing to store, rotate, or leak. This is the
  larger benefit and it was not the reason for the decision.
- **Verification stays where it is fastest.** The Actions jobs take about two
  minutes and run per PR; routing tests through Xcode Cloud would cost build minutes
  for a slower answer to the same question.
- **Xcode Cloud is configured in App Store Connect, not in this repository.** Its
  workflow definition is not version-controlled here, which is a real loss — a
  change to how builds are produced leaves no diff. Accepted because the alternative
  is the untested path above, but it is the thing to reconsider first if this stops
  working.
- Deleting the setup document loses a written account of the App Store Connect API
  key flow. It is recoverable from git history if a CI-driven upload is ever wanted
  again.

## How to reopen

If Xcode Cloud's build minutes become a constraint, or a build has to be produced
from somewhere without Apple ID authentication — a shared runner, another CI
provider — the API key path comes back. It is in the history at the commit that
removed it, and it was never proven to work, so treat it as a starting point rather
than a working artefact.
