# TestFlight setup

One-time setup so `.github/workflows/testflight.yml` can archive and upload without a
Mac. Roughly half an hour, almost all of it in App Store Connect rather than here.

**You probably don't need this to test the widget.** A direct Xcode install to your own
device is faster and gives you a Debug build with the console attached — see
[device-test-widget-dispatch.md](device-test-widget-dispatch.md). This is for getting
builds to *other* people, or to yourself without a Mac in reach.

## What the workflow needs

Four repository secrets, at **Settings → Secrets and variables → Actions → New
repository secret**.

| Secret | What it is |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | The key's 10-character ID |
| `APP_STORE_CONNECT_ISSUER_ID` | A UUID, shown once at the top of the Keys page |
| `APP_STORE_CONNECT_PRIVATE_KEY` | The full contents of the `.p8` file |
| `DEVELOPMENT_TEAM` | Your 10-character Team ID |

No certificate or provisioning profile is stored. The workflow passes the API key to
`xcodebuild -allowProvisioningUpdates`, which lets Xcode create and download the
profiles for both the app and the widget extension — including the App Group — on the
runner. The key is the only credential.

## Steps

### 1. Create the App Store Connect API key

App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**
→ **+**.

- Name it something recognisable (`GitHub Actions`).
- Access: **App Manager**. Developer is not enough to upload builds.
- Download the `.p8`. **You get exactly one chance** — it cannot be downloaded again.

From that page, copy the **Issuer ID** (top of the page) and the **Key ID** (the row).

### 2. Store the private key

Paste the `.p8` file's entire contents into `APP_STORE_CONNECT_PRIVATE_KEY`, including
the header and footer lines:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEA...
-----END PRIVATE KEY-----
```

Line breaks matter. Paste it, don't retype it.

### 3. Find your Team ID

[developer.apple.com/account](https://developer.apple.com/account) → Membership
details, or Xcode → Settings → Accounts → the Team column. Ten characters, e.g.
`A1B2C3D4E5`. It isn't secret — it's a repository secret only so it doesn't have to be
committed.

### 4. Create the app record

App Store Connect → **Apps** → **+** → **New App**.

- Platform: iOS
- Bundle ID: **`com.shawnsemmes.DrinkTracker`** — must match exactly what
  `BUNDLE_ID_PREFIX` in `Config/Signing.xcconfig` produces.
- SKU: anything unique.

The upload fails with a bundle-ID error if this record doesn't exist first. Registering
the widget's bundle ID separately isn't necessary; automatic signing handles the
extension.

### 5. Run it

**Actions** → **TestFlight** → **Run workflow**. Optionally set the tester notes.

The build number comes from the workflow run number, so it always increases and
TestFlight never rejects a duplicate. `MARKETING_VERSION` is untouched — that stays a
deliberate choice in the project.

Processing takes a few minutes after upload before the build appears in TestFlight.

## Known unknowns

**This workflow has never run.** It can't be tested without the secrets, and it is the
kind of pipeline that usually needs a round or two of fixes on first contact. The
likely failure points, in order:

1. **Export method string.** Written as `app-store-connect`; older Xcode expects
   `app-store`. If export fails complaining about the method, that's the line.
2. **`altool` deprecation.** Still the working CLI for App Store uploads, but Apple
   has been moving toward Transporter. If it's gone, the replacement is
   `xcrun notarytool`-adjacent tooling or the Transporter app.
3. **First-run signing.** `-allowProvisioningUpdates` sometimes needs a second run
   after it has registered identifiers the first time.
4. **Certificate limits.** If your team is at its distribution certificate cap, Xcode
   can't create another and the archive fails. Revoke an unused one.

On failure the archive and logs are uploaded as an artifact, which is usually enough
to tell which of the above it was.
