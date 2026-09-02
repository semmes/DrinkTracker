# Tallyist Privacy Policy

**Last updated: September 2, 2026**

Tallyist does not collect your data. Nothing you log leaves your control.

This page is the authoritative version of the policy for the Tallyist iOS app.
The same policy ships inside the app, under Settings → About → Privacy Policy. It
stays in English even where the app's interface is translated, so that what it
claims can be checked against the app's privacy manifest and entitlements.

## What Tallyist stores

- The drinks you log: type, size, strength, and when.
- Days recorded as alcohol-free — by you, or by another app that recorded zero
  drinks in Apple Health.
- Your settings, such as which region's standard-drink definition your totals use.

All of it is stored on your device, in the app's own database. There are no
accounts and no sign-up.

## Where your data can go — always under your control

- **iCloud.** If your device is signed into iCloud, your log syncs through your
  own *private* iCloud database so it follows you across your devices. That
  database belongs to your Apple Account; the developer cannot read it, and no
  server other than Apple's is involved. Sync stops if you sign out, and the
  app keeps working locally.
- **Apple Health.** With your permission, drinks you log are saved to Health as
  "alcoholic beverages", and Tallyist reads that same category back — including
  drinks that other apps recorded there, which then appear in your Tallyist log,
  clearly labeled, and days they recorded as zero drinks, which appear as
  no-alcohol days. You can grant, refuse, or revoke this at any time in the
  Health app under Sharing. Tallyist reads no other Health data.
- **The widget.** The home-screen widget shares the app's on-device storage.
  Nothing about that leaves the device.
- **Export and sharing.** Settings → Export log turns your whole record into a
  CSV file, and the calendar can render a month as an image. Both are created
  on your device, only when you ask, and go only where you send them through
  the system share sheet. The app keeps no copy, adds no identifier, and does
  not record whether or where you shared anything.

## What Tallyist does not do

- No analytics, and no crash-reporting SDKs.
- No advertising, and no tracking of any kind.
- No third-party services. The app contains no networking code of its own; the
  only network traffic related to Tallyist is Apple's iCloud sync described
  above and, if you choose to leave a tip, Apple's own App Store purchase
  processing.
- No selling, sharing, or transfer of your data to anyone, because the
  developer never has it in the first place.

In App Store terms: **Data Not Collected**.

## Tips

Tallyist has an optional tip jar (Settings → Buy me a drink). Payments are
processed entirely by Apple through your App Store account, exactly like any
App Store purchase: Tallyist never sees your payment details, and Apple tells
the app only that a purchase completed. Tips unlock nothing, and nothing about
tipping — or not — appears in or affects your drink log. Recurring tips can be
cancelled any time in your App Store subscription settings, and the app offers
a local reminder a week before each renewal so you can cancel before being
charged.

## Deleting your data

- Any entry can be deleted in the app, individually.
- Deleting the app removes everything stored on the device.
- iCloud copies can be removed in the iOS Settings app under your Apple
  Account → iCloud → Manage Account Storage.
- Data saved to Health is yours in Health: delete it there under Browse →
  Other Data → Alcohol Consumption.

## Changes to this policy

This policy is published in a public repository at
<https://github.com/semmes/Tallyist>; every change to it, and its date, is
visible in that repository's history. If a future version of the app ever
collects data — for example, if a server component is added — this policy and
the App Store privacy labels will change *before* that version ships.

## Contact

Questions about this policy can be raised as an issue on the app's public
issue tracker: <https://github.com/semmes/Tallyist/issues>.
