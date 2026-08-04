# Device test — does the widget's tap reach the intent?

**Tier 4 (docs/PRD.md §4).** None of this can be established in a simulator. Budget
about ten minutes.

## What we're establishing

The widget builds, installs, appears in the gallery, and **reads** the shared store
correctly — it shows the same live total as the app, in the same units, which already
proves the App Group and the shared SwiftData store work.

What has never been observed working is **tapping its Beer button**. In the simulator
`LogDrinkIntent.perform()` is never entered: `Diagnostics.record("entered")` is the
very first line of the method, and the breadcrumb stays absent after a tap. It is not
a crash — no crash report is generated.

Three possibilities, needing completely different fixes:

| | |
|---|---|
| **A** | The intent itself is broken. |
| **B** | The intent is fine; the widget button's dispatch is broken. |
| **C** | Nothing is broken; synthetic touch injection against an out-of-process widget view hierarchy just doesn't work in the simulator. |

The simulator cannot separate these. A real device can, and the Shortcuts step below
is what does the separating.

## Getting a build onto the device

Direct install from Xcode. For *this* test it beats TestFlight on every axis: a Debug
build, the Xcode console attached, and a thirty-second turnaround if we need to change
something and retry.

1. **Add your Apple ID** to Xcode → Settings → Accounts, if it isn't already.
   `DEVELOPMENT_TEAM` is already set in `Config/Signing.xcconfig`, so there is
   nothing to fill in.

2. **Confirm both targets are signing.** Select the **DrinkTracker** target → Signing &
   Capabilities → your team is picked, "Automatically manage signing" is on. Repeat for
   **DrinkTrackerWidgetExtension**. Automatic signing registers both App IDs, the App
   Group, and the iCloud container on first device build.

3. **Select your device and run.** (⌘R)

If step 3 reports the App Group can't be created, register it once by hand at
[developer.apple.com](https://developer.apple.com/account) → Identifiers → App Groups
as exactly `group.com.shawnsemmes.DrinkTracker`, then rebuild.

**Keep Xcode's console open while you test.** The extension's output is largely
unreadable, but the app's isn't, and anything it prints is free evidence.

TestFlight also works if you'd rather — `.github/workflows/testflight.yml` does the
archive and upload — but it's more setup for a strictly worse debugging experience.

## Before you start

- **Settings → Diagnostics must be visible.** It appears in Debug and TestFlight
  builds. If you can't see it, you're on an App Store build and this test can't be
  run — see `Diagnostics.isVisible`.

## Step 0 — Confirm the shared store is healthy

Open the app → **Settings** → **Diagnostics**.

| Reading | Expected | If not |
|---|---|---|
| App Group | `shared` | `UNAVAILABLE` means the entitlement isn't provisioned. Stop — nothing below will mean anything. |
| Group ID | `group.com.shawnsemmes.DrinkTracker` | A different value means `BUNDLE_ID_PREFIX` doesn't match what was provisioned. |
| Store mode | `shared, CloudKit requested` | `shared, no CloudKit` is survivable for this test. `IN MEMORY` means stop — nothing is being saved at all. |
| iCloud sync | `syncing` | `no iCloud account` is expected in the Simulator and survivable here. This is the real answer; Store mode is only what was asked for. |

**Record what you see even if it all looks right.** "Store mode" and "iCloud sync"
have never been read on a device, so whatever they say is new information.

> **In the Simulator you will always see `no iCloud account`,** and the console will
> carry `CKAccountStatusNoAccount` plus a CoreData+CloudKit recovery failure. That is
> the Simulator having no iCloud account signed in, not a fault in the app — the
> store still works locally. It is also why the widget test below cannot be done
> there.

## Step 1 — Baseline: does logging work at all in-app?

1. Tap **Beer** on the Today screen, then **Log drink**.
2. The total should go up by 1.0.

If this fails, the problem isn't the widget and the rest of this test is moot.

## Step 2 — The bisect: run the same intent from Shortcuts

This is the step that actually separates A from B, and it's the one the simulator
can't do — Shortcuts isn't installed there.

The app registers **"Log a beer in Drink Tracker"** as an App Shortcut. Running it
executes the *same* `perform()` body as the widget button, but in the **app's**
process rather than the extension's.

1. Open the **Shortcuts** app → **App Shortcuts** (or just ask Siri: *"Log a beer in
   Drink Tracker"*).
2. Run it.
3. Go back to Drink Tracker → **Settings → Diagnostics** and read **Last widget tap**.

| Reading | Meaning |
|---|---|
| `saved` | The intent and the SwiftData write are both fine. → **the fault is specifically widget dispatch (B).** |
| `never ran` | Shortcuts didn't dispatch it either. Something is wrong with intent registration generally. |
| `entered` or `container-opened` | It started and died partway. The step name says where. |
| `failed: …` | The intent ran and the write threw. **Copy the error text** — it's the whole answer. |

Also check whether the **Today total went up**. Diagnostics says what the code did;
the total says whether it actually landed.

## Step 3 — The widget tap

1. Add the **Quick Log** widget to the home screen if it isn't there (medium size
   shows all four buttons; small shows Beer only).
2. Note the number it displays.
3. **Tap the Beer button on the widget.**
4. Open the app → **Settings → Diagnostics** → read **Last widget tap** again.

> Do Step 2 first and note the reading, or you won't be able to tell a fresh Step 3
> breadcrumb from a leftover one. If you want to be certain, the values differ by
> outcome — but the safest read is "did it change from what Step 2 left?"

## What the combination means

| Step 2 (Shortcuts) | Step 3 (widget) | Conclusion |
|---|---|---|
| `saved` | `saved` | **It works on device.** The simulator was the problem all along (C). Close the issue and note it in the README. |
| `saved` | unchanged / `never ran` | **Widget dispatch is broken (B).** The intent is fine. Next suspects: the `Button(intent:)` binding, the widget's `Metadata.appintents` registration, or the extension's entitlement. |
| `saved` | `failed: …` | The write fails specifically from the extension's process — a sandbox or container-access difference. The error text names it. |
| `never ran` | anything | **Intent registration is broken generally (A)**, not a widget problem. The widget was a red herring. |
| `failed: …` | anything | **The intent's write is broken (A).** The error text is the fix. |

## What to report back

Copy these four lines out of Diagnostics (the values are selectable), for both Step 2
and Step 3:

```
App Group:            …
Group ID:             …
Store mode:           …
iCloud sync:          …
Intent last built by: …
Last widget tap:      …
```

**"Intent last built by" is the new one and it does the real work.** It records which
*process* constructed a `LogDrinkIntent`, so it separates two failures that used to
look identical:

| Intent last built by | Last widget tap | Meaning |
|---|---|---|
| `never built` | `never ran` | The widget never rendered its buttons. The extension isn't running at all. |
| `beer · …DrinkTracker.Widget` | `never ran` | The extension built the button and the tap never reached `perform()`. **Dispatch or parameter resolution** — this was the state before the `default:` fix. |
| `beer · …DrinkTracker.Widget` | `entered` / `saved` | It ran. Any remaining fault is in what it did. |
| `beer · …DrinkTracker` (no `.Widget`) | anything | The *app* built it, not the extension — the reading is from Shortcuts, not the widget. |

Plus:
- Did the **Today total** change after Step 2? After Step 3?
- iOS version and device model.
- Whether the widget's own displayed number updated after the tap.

That last one matters more than it looks: the widget reloads its timeline at the end
of `perform()`, so a widget number that changes is independent evidence the intent ran
to completion — and one that doesn't, while Diagnostics says `saved`, points at the
timeline reload rather than the write.
