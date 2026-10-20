# 0012 — The tip jar: IAP, capped quantity, and a reminder to cancel

**Status:** accepted · **Date:** 2026-08 · amended 2026-09-26 (the recurring
tips go on sale, and the reminder keeps its promise) and again the same day
(the yearly tip is $99.99), and on 2026-10-04 (the tips are not promoted on
the App Store) · **Relates to:** ADR-0001, PRD §1 (non-goals),
guideline 3.1.1 and 1.4.3

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
| `com.shawnsemmes.DrinkTracker.support.yearly` | Auto-renewing, group "Support" | $99.99 / year |

Prices are read from StoreKit at runtime — changing them in App Store Connect
requires no code change. *(The yearly tip was $4.99 / year until the second
amendment of 2026-09-26.)*

**Tips unlock nothing.** Everything ships to everyone. This is the ethical line
that keeps the jar a gift rather than a paywall and keeps the App Privacy answer
at "Data Not Collected". *(This sentence also said it "keeps the product outside
subscription-value review scrutiny (there is no gated value to assess)". That
was backwards, and the amendment below corrects it.)*

**The reminder to cancel is a feature, not a courtesy.** A local notification
fires a week before each renewal, scheduled from the entitlement's own
expiration date and re-derived on every refresh — no server, works after
reinstalls. This is the app's voice applied to money: states of the system,
stated in advance, on the user's side. Notification permission is requested
only at subscribe time, when there is something real to remind about; denial
doesn't block subscribing, and the screen says the promise then can't be kept.
*(Since the amendment of 2026-09-26 it is also asked for once when a
subscriber opens the tip jar on a device that has never been asked, such as a
second device or after a reinstall. It is never asked at launch.)*

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
  the tip screen. *(And the renewal reminder itself, and, since the amendment
  of 2026-09-26, test builds' Settings → Diagnostics.)*

## Amendment (2026-09-26): the recurring tips go on sale, and the reminder keeps its promise

**Context.** The owner decided on 2026-09-26 that the monthly and yearly tips go
on sale with 1.4. Only the one-time tip has ever been on sale: the live product
page lists "Buy the creator a drink" at $4.99 and nothing else, and on the same
day the App Store's sandbox returned only that product to a simulator build.
So 1.4 is the first time App Review sees the subscriptions, and the first time
anyone can buy one. An audit before the archive (a workflow, each finding put
to a skeptic that tried to refute it) found that the reminder, which this ADR
calls "a feature, not a courtesy", did not hold, and that one claim above was
wrong:

1. The tip jar lived on its screen (`@State` in `SupportView`), and the code that
   listens for renewals and schedules the reminder ran only from that screen's
   `.task`. After a renewal the next reminder waited for someone to open the
   screen, so "a week before each renewal" held for the first renewal only.
2. The refresh read the entitlement's expiration and never its renewal info. A
   recurring tip cancelled in Settings stays entitled to the end of its period,
   so the screen still read "Renews <date>" and the reminder still said it
   renews in a week.
3. With notifications denied the screen still promised the reminder, where the
   Decision says "the screen says the promise then can't be kept".
4. With the subscriptions not on sale, the Recurring section was drawn as a
   heading with no rows over the caption promising a reminder a week before any
   renewal, which is what a 1.4 approved without them would show.
5. A recurring purchase that was pending or failed said nothing.
6. "Tips unlock nothing … keeps the product outside subscription-value review
   scrutiny" is backwards. Guideline 3.1.2(a): "If you offer an auto-renewable
   subscription, you must provide ongoing value to the customer". A
   subscription that gates nothing is what that sentence is about. 3.1.1 allows
   tipping the developer, and says nothing about a tip sold as an
   auto-renewable subscription.

A first fix, reviewed the same way before merging, still left the reminder
depending on the app being opened between renewals, missed a cancellation made
in the screen's own "Manage or cancel" sheet, and had smaller defects; the
Decision below is the fix after that review.

**Decision.**

- **One tip jar for the process.** `DrinkTrackerApp` creates it at launch and
  puts it in the environment. It starts `observeTransactions()`, which creates
  the `Transaction.updates` listener first, as Apple asks, and runs the first
  refresh beside it. Each transaction that arrives outside a purchase (a
  renewal, an Ask to Buy approval) is finished and the reminders re-derived.
  The tip jar is refreshed again on every foreground, and when the "Manage or
  cancel" sheet closes, since cancelling there makes no transaction and need
  not leave the foreground. At launch this reads StoreKit's entitlements, and
  the renewal info only while a recurring tip is active; the products are still
  fetched only on the tip jar screen. On a simulator with no Apple Account the
  launch work made no App Store request (storekitd's `TransactionQuery` at
  launch, no request lines over about 20 seconds, measured by the review); a
  signed-in device on production is not measured. On that basis the privacy
  policy's "if you open the tip jar or leave a tip" still holds.
- **`SupportRenewal`** (core package, tier 1) turns the latest recurring
  entitlement's expiration and its `willAutoRenew` into what the jar says and
  when the reminders fire. A tip that will not renew *ends*: the caption says
  "Ends <date> and won't renew.", and every pending reminder is removed.
  Unknown renewal info (offline, unverified) is read as renewing, because a
  reminder that proves unneeded costs less than a charge nobody was warned of.
- **A year of reminders.** A local notification exists only once the app has
  run to schedule it, so one reminder at a time left a subscriber who stops
  opening the app with no reminder for the renewal after next, the person the
  reminder is most for. The app now schedules one a week before each of the
  next twelve monthly renewals, or the next two yearly ones, counted from the
  entitlement's own expiration in the Gregorian calendar (the App Store's,
  whatever calendar the device shows; counted in a Hebrew or Islamic calendar
  they drifted by up to weeks, which the second review found), and every
  refresh replaces them. The period is the one of the product that renews next,
  from the renewal info's `autoRenewPreference`, so after a switch between
  monthly and yearly the later reminders follow the new tip.
  Their text holds whatever happened meanwhile: "Recurring tip reminder" over
  "Unless it's been cancelled, your recurring tip renews in about a week. You
  can cancel any time in the App Store, and the app stays the same either way."
  (both now in the catalog; 1.0 to 1.3's reminder said "Tallyist support renews
  in a week" in plain strings). The one for the renewal whose week has begun is
  left alone, because removing it in its last minute would lose it. They are
  added only while notifications are allowed; the system keeps nothing
  otherwise, and the next refresh after permission is granted adds them.
- **Refreshes run one after another.** Launch, a foreground, a purchase, the
  sheet and the tip jar screen can each ask for one, and each caller returns
  with the state its own refresh wrote. A first version let only the latest
  refresh write; the simulator render caught it, because the screen then read
  the state before it was written and never asked for permission.
- **Notification permission** is still asked for after a subscription, and now
  also once when a subscriber opens the tip jar on a device that has never been
  asked (a second device, or after a reinstall) or when a tip starts renewing
  while it is open (including a cancelled tip turned back on), never at launch. Where notifications are off, the captions
  say so, for an active tip ("Renews <date>. Notifications are off for
  Tallyist, so it can't remind you a week before. You can turn them on in the
  Settings app.") and before subscribing. Inside the last week the caption is
  "Renews <date>." whatever the setting.
- **The Recurring section** is drawn only when there is something to offer or
  report, and a subscriber whose products could not be loaded keeps the status
  and "Manage or cancel". The one tip jar keeps its products across visits, so
  a visit after a failed one shows the spinner, and a failed fetch after a good
  one keeps what it had.
- **A recurring purchase** reports received, pending and failed with the
  one-time tip's reviewed words; a pending note is cleared once the tip becomes
  active. Moving between the monthly and yearly tip, which share a level, says
  "Switches to <name> on <date>. Nothing is charged until then." A purchase the
  device cannot verify, for either kind of tip, now says "The App Store
  couldn't confirm that purchase. If you were charged, it shows in your App
  Store purchase history." instead of "Nothing was charged", which may not have
  been true.
- **The privacy policy** said "Apple tells the app only that a purchase
  completed". It now says "only that a purchase completed and, for a recurring
  tip, when it renews or ends, which stays on your device" (both in-repo
  copies, dated September 26, 2026; the mirror publishes the third).
- **Settings → Diagnostics** (test builds) gains a "Recurring tip" line: the
  product, renews or ends (and the other tip, after a switch), how many
  reminders the system holds and when the first of them fires, and whether
  notifications are on.
- **The citations.** The sign-up screen's and the metadata's disclosure rules
  (title, period, price, the Terms of Use and privacy links) are guideline
  3.1.2(c) and Apple's subscriptions page, not 3.1.2(a); the code comments, the
  README and the listing now say so.
- **Review.** The tips go to App Review with 1.4 anyway, at the owner's
  decision, with each subscription's own Review Notes saying what they are.
  If App Review rejects them, they come out of the submission and 1.4 ships
  without them. The build already handles that case (no Recurring section), and
  the listing says what else to change (`docs/app-store-listing.md`, the
  recurring tips reminder).

**Costs.**
- Every launch and foreground now reads StoreKit's entitlements and the
  notification settings, for everyone.
- Unknown renewal info can remind someone who cancelled while offline.
- A cancellation made in the Settings app is seen at Tallyist's next launch or
  foreground. Until then the reminders already scheduled stay; their text says
  "Unless it's been cancelled", so they stay true.
- Someone who cancels outside the app more than a week before the renewal and
  never opens it again can receive all twelve of those reminders a month apart
  (both, a year apart, for a yearly tip), the first a week before the tip ends.
  Deleting the app removes them, and opening it once clears them.
- The reminders reach a year of renewals past the app's last launch or
  foreground, and only where notifications are allowed; a device that has
  never been asked schedules none until the tip jar is opened there. The
  published promise was unconditional; on 2026-09-26 the owner chose to
  qualify it, so the descriptions, the support page and the README now say
  "If you allow notifications, Tallyist reminds you a week before each
  renewal". It still says nothing about the year's horizon.
- The later renewals' dates are a Gregorian count from the expiration, not the
  App Store's own dates, which are not known in advance; that is why the text
  says "in about a week".
- In the sandbox and on TestFlight, which renew on an accelerated schedule, the
  later reminders fall on dates matching no renewal. They fire only if the
  build is not opened after the sandbox subscription lapses, and opening it once
  clears them.
- Each device schedules its own reminders, as before.
- An entitlement whose date has passed but is still active (a billing grace
  period) reads as no recurring tip in the caption while its row stays checked.
- A cancellation made in the Settings app while Tallyist is on screen is not
  seen until the next foreground. `Product.SubscriptionInfo.Status.updates`
  would see it, but starting it queries subscription status for everyone, which
  the privacy claim above would then need measuring for.

**Verified.**
- 401 domain tests under both SwiftPM build systems, sixteen of them new
  (`SupportRenewalTests.swift`).
- The integration tests, and the iOS and watch builds.
- The app catalog synced from a fresh full build: 386 keys, ten in and two
  out, with the two new policy keys marked not to translate like the old ones.

On a throwaway iPhone 18 Pro Max on iOS 27, from a Debug copy of the tree that
injected the renewal state at launch (a plain `simctl` launch does not load the
scheme's StoreKit configuration; only an Xcode Run does):
- every caption for an active tip ("Ends <date> and won't renew.", "Renews
  <date>." inside the last week, the reminder promise, and the
  notifications-off form), in light, dark and at accessibility-extra-large,
  including "Renews <date>." inside the last week with notifications off;
- the sandbox's real reply, the one-time tip alone, with no Recurring section;
- the real permission request for a never-asked subscriber;
- after "Don't Allow", the notifications-off caption read from the real
  setting;
- after "Allow", twelve reminders pending with the system (Diagnostics);
- a tip that ends: none pending.

After an erase and "Allow", the simulator refused the reminders with "Source is
not authorized" while the app read notifications as allowed. After a reboot the
same requests were accepted, and so were plain probe notifications, so it is
recorded as the simulator's, not the app's.

**Not verified.**
- The real StoreKit paths: the listener at launch, `subscriptionStatus`,
  `willAutoRenew` and `autoRenewPreference`, a switch between tips and the
  message it shows, and a real renewal and cancellation.
  The owner can check these in Xcode with the StoreKit configuration (Debug →
  StoreKit → Manage Transactions) and on TestFlight. On 2026-09-26 the owner
  reported: "Checked xcode and the storekit configuration. It's configured
  correctly." Which flows that check ran is not recorded.
- A reminder firing on a device a week before a real renewal. TestFlight renews
  on an accelerated schedule, so only production shows it.
- Both pre-subscription captions (notifications on and off), which are drawn
  only when the subscription products load; the sandbox served neither
  subscription.
- VoiceOver.
- App Review's reading of 3.1.2(a).

## Amendment (2026-09-26, later): the yearly tip is $99.99

**Context.** On the evening of 2026-09-26, with 1.4 and the subscription group
in a draft submission, the owner changed the yearly tip's price in App Store
Connect from $4.99 to $99.99. No subscription had been approved or sold, so no
subscriber's price changes. The monthly tip stays $4.99 a month, and the
one-time tip $4.99.

**Decision.**
- **The price is App Store Connect's, so the build does not change.** The
  Decision above already says prices are read from StoreKit at runtime. The tip
  jar shows each product's `displayName` and `displayPrice` ("$99.99 per year ·
  cancel any time"), no Swift code names a price, and `DrinkTracker.storekit`
  is not in the app bundle (the 1.4 (1) archive holds no `.storekit` file). The
  build in the draft submission, 1.4 (1), stands.
- **The local StoreKit configuration matches.** Its yearly `displayPrice` is
  99.99, so an Xcode Run shows what App Store Connect sells. That Run is also
  where the App Review Screenshot now comes from (`docs/app-store-listing.md`,
  the recurring tips reminder), because the sandbox may not serve a
  subscription while its metadata, that screenshot included, is incomplete.
- **The descriptions say it.** The base description and 1.4's (A) and (B) read
  "A Drink Every Year ($99.99/year, auto-renews yearly)", since guideline
  3.1.2(c) and Apple's subscriptions page ask for each recurring tip's price.

**Costs.**
- The yearly tip costs more than twelve monthly ones ($59.88), where a yearly
  subscription usually costs less. The two share a level, so a move from
  monthly to yearly is a larger tip from the next renewal, and the tip jar's
  "Switches to <name> on <date>. Nothing is charged until then." still holds.
- The name was written for $4.99. In this app "a drink" is the $4.99 tip, so
  "A drink every year" (the StoreKit file; "A Drink Every Year" in the
  descriptions) no longer says what the yearly tip costs. Whether it is renamed
  is the owner's call, open when this was written; a new name goes into App
  Store Connect, the StoreKit file and the three descriptions together, through
  the 1.4.3 review.
- App Review. The guidelines' Business section says Apple rejects items sold at
  "irrationally high prices". A $99.99 tip that unlocks nothing adds to the
  3.1.2(a) risk the amendment above records, and the listing's contingency for a
  rejection is unchanged.

**Verified.** The StoreKit file parses, and only the yearly price changed. The
owner ran the DrinkTracker scheme on a simulator after the change and reported
"Great it worked" for the yearly row. The tallyist.co pages name no price.

**Not verified.** The price as the sandbox serves it on TestFlight, which
served neither subscription on 2026-09-26, and App Review's reading of it.

## Amendment (2026-10-04): the tips are not promoted on the App Store

**Context.** App Review rejected 1.4 (1) under guideline 2.3.2: "Your
promotional image includes text that is small or otherwise hard to read." The
image was `image.png` in the App Store image slot of the monthly tip (*A drink
every month*), which was set to be promoted to all App Store users. No record
says who uploaded it, and the owner did not remember doing so. App Store
Connect's promotion page itself warned: "These in-app purchases or
subscriptions can't be promoted on the App Store because your latest approved
binary doesn't include the required StoreKit APIs." Apple's help says an image
is needed only "if you want to promote your In-App Purchase on your App Store
product page or set up win-back offers", and "Your app must support the
PurchaseIntent API in order for the App Store to display your promoted product
pages." This app has no `PurchaseIntent` handling.

**Decision.** No tip is promoted on the App Store, and no tip carries an App
Store image. The owner deleted the image and turned the promotion off, in
their words: "I think not having it there since it's optional is best." The
checklist in `docs/app-store-listing.md` says to leave the Image empty. How the
image came off is in that file's "The rejection of 1.4 (1), 2026-10-04".

**Costs.** None a reader sees, since the promotion could not have shown
without `PurchaseIntent`. Tips are bought only in the app, where the jar says
first that they unlock nothing.

**Not verified.** Whether the promotion entry itself is gone. App Store Connect
refused to remove it while the image existed, and it may still be listed with
no image.

**How to reopen this amendment.** Promoting a tip needs `PurchaseIntent`
handling in a build first. Then each promoted item needs its own 1024 × 1024
image with no text, not a screenshot and not the app icon, legible at small
sizes, with nothing important in the lower-left corner, where the App Store
adds the app icon (Apple: "We also recommend that you don't overlay text on
the image").

## How to reopen

If Apple ever opens tips to alternative rails (or an external-purchase
entitlement becomes worth its terms), the rail is one service class. The
ethical lines — unlock nothing, remind before charging — are not rail-dependent
and survive any such change.
