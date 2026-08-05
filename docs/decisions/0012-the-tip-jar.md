# 0012 — The tip jar: IAP, capped quantity, and a reminder to cancel

**Status:** accepted · **Date:** 2026-08 · **Relates to:** ADR-0001, PRD §1
(non-goals), guideline 3.1.1 and 1.4.3

## Context

The app should let people who love it support it — "buy me a drink", $5 each,
any quantity, Apple Pay, with monthly/yearly recurring options and a reminder
to cancel a week before each charge. Three of those specifics collide with App
Store rules, and one collides with the app's own ethics. All four collisions
were resolved rather than ignored.

## Decision

**In-App Purchase, not Apple Pay.** Guideline 3.1.1 requires IAP for digital
goods sold in-app, and tips to the developer are digital goods; Apple Pay is
restricted to physical goods and real-world services. A tip jar on Apple Pay is
a rejection. The customer experience is unchanged — StoreKit's confirm sheet is
the same one-authorization flow. Apple's commission is the cost of the rail.

**$4.99, quantity 1–10 per transaction.** US price points end in .99, so "$5"
is the $4.99 tier. IAP has no free-form amounts and caps quantity at 10 per
transaction, so "no limit" becomes the signature `CountStepper` at 1–10 with
the cap stated in the UI, and repeat purchases always possible. Products:

| Product ID | Type | Price |
|---|---|---|
| `com.shawnsemmes.DrinkTracker.tip.onedrink` | Consumable | $4.99 |
| `com.shawnsemmes.DrinkTracker.support.monthly` | Auto-renewing, group "Support" | $4.99 / month |
| `com.shawnsemmes.DrinkTracker.support.yearly` | Auto-renewing, group "Support" | $4.99 / year |

Prices are read from StoreKit at runtime — changing them in App Store Connect
requires no code change.

**Tips unlock nothing.** Everything ships to everyone. This is the ethical line
that keeps the jar a gift rather than a paywall, keeps the App Privacy answer
at "Data Not Collected", and keeps the product outside subscription-value
review scrutiny (there is no gated value to assess).

**The reminder to cancel is a feature, not a courtesy.** A local notification
fires a week before each renewal, scheduled from the entitlement's own
expiration date and re-derived on every refresh — no server, works after
reinstalls. This is the app's voice applied to money: states of the system,
stated in advance, on the user's side. Notification permission is requested
only at subscribe time, when there is something real to remind about; denial
doesn't block subscribing, and the screen says the promise then can't be kept.

**The metaphor was reviewed under 1.4.3.** "Buy me a drink" in an alcohol app
could read as trivializing. It survives because it is unambiguously about
money — the copy prices it, the counter counts purchases, and the policy and
footer state that tips never touch the drink log. The copy-review addendum
records each string.

## Consequences

- **App Store Connect setup is required before any of this works outside the
  simulator**: the Paid Applications agreement (banking + tax), then the three
  products above with those exact IDs. The local `DrinkTracker.storekit`
  configuration (wired into the shared scheme) makes the whole flow testable in
  the simulator with none of that done.
- The privacy policy gained a Tips section *in the same change* — its own rule:
  the policy changes before the version that needs it ships.
- Subscriptions oblige a "Restore purchases" affordance; it's in the footer.
- The widget and the log are untouched; a tip is invisible everywhere except
  the tip screen.

## How to reopen

If Apple ever opens tips to alternative rails (or an external-purchase
entitlement becomes worth its terms), the rail is one service class. The
ethical lines — unlock nothing, remind before charging — are not rail-dependent
and survive any such change.
