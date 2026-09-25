# 0056 — The website shows the app in Apple's own devices, on Apple's terms

**Status:** accepted · **Date:** 2026-09-24 · **Supersedes / superseded by:** —

## Context

The owner's design for `tallyist.co` (a Claude Design handoff, untracked in the
owner's checkout at `docs/design/marketing-design-handoff/`) drew iPhone and Apple
Watch frames in CSS with drop shadows. Its link preview image drew a phone cut off
at the card's edge. It put an App Store badge in the home page's hero and again in
its closing section, and it named no iPad anywhere.

Apple's App Store Marketing Guidelines
(`https://developer.apple.com/app-store/marketing/guidelines/`, read 2026-09-24)
say otherwise on each point:

- "Use Apple-provided product bezels in all your marketing materials to display your
  app on the Apple devices it supports."
- Product images are used "as is" and without modification. Cropping, tilting,
  obstructing, and adding shadows or reflections all count as modification.
- One App Store badge per layout.
- Credit lines for Apple's trademarks appear once per website, wherever legal
  notices go.

Two agreements make these terms, not advice. The badge is licensed under the
Marketing Agreement on the same page, which requires "strict compliance" with the
guidelines wherever the artwork is used. The bezels open only after agreeing to
Apple's License Agreement for Apple Design Resources. That license allows the bezels
in images of mock-ups of an app shown in the device. It forbids modifying or
redistributing the device art on its own, and it ends automatically if a term is
broken.

The owner first ruled that a cropped device and two badges were fine, "since this
is a marketing page and not within apple ecosystem" and "since it's our own and not
apples". The competing view is real: nothing reviews a developer's website the way
App Review reviews an app, and Apple rarely acts against small sites. Told that the
guidelines are the terms attached to the artwork wherever it appears, and shown the
bezel license, the owner chose Apple's terms.

## Decision

The website follows Apple's terms for the badge and the device images.

- **Devices.** Apple's own product bezels: iPhone 17 in black, and Apple Watch
  Series 11, 46mm, Jet Black aluminum with a black Sport Band. The owner agreed to
  Apple's License Agreement for Apple Design Resources on 2026-09-24.
  `scripts/make-images.py` in `semmes/Tallyist` flattens each screenshot into its
  device, and the bezel files are never committed. Every device is shown whole,
  with no shadow and nothing drawn over it. The two close-ups are crops of a
  screenshot, with no device in them. The press page shows plain screenshots with
  square corners.
- **Link preview.** The whole phone, not a cropped one.
- **Badges.** One App Store badge per page. The home page's closing section says
  "Available on the App Store" as a link. The white badge is used only while it is
  the page's only store badge.
- **iPad.** Named once, in the footer: "Tallyist is available for iPhone and iPad"
  (and Apple Watch from platform state 2). There is still no iPad section.
- **Credit line.** In the footer: "Apple, the Apple logo, Apple Watch, iCloud, iPad,
  iPhone, Safari, Siri, and watchOS are trademarks of Apple Inc., registered in the
  U.S. and other countries and regions. App Store is a service mark of Apple Inc."
- **Safari's banner.** The `apple-itunes-app` meta tag stays. The privacy page's
  "This website" note says that Safari fetches the banner's details from Apple, so
  "loads nothing from other sites" stays true of the pages themselves.

## Consequences

- **The site looks different from the design.** The devices are real, with side
  buttons and the Dynamic Island, and cast no shadow. The press thumbnails have
  square corners, and the closing section has a link where the design had a badge.
- **iPhone 17 is not the latest generation.** Apple asks for "the latest-generation
  devices for which your app is currently developed", and Apple has offered iPhone 18
  bezels since 2026-09-09. The iPhone 17 is used because the design's screenshots
  are its size (1206 × 2622). The 1.4 screenshot candidates were made on an
  iPhone 18 Pro Max simulator, so moving to the 18 is a new set of screenshots and
  one argument to the script.
- **Regenerating the images needs the bezels on the machine that runs the script.**
  They are not in any repository. A later session downloads them again, and asks the
  owner before accepting the license on their behalf, as this one did.
- **The credit line has to follow the copy.** When the site names another Apple
  trademark, the line names it too.
- **No crops, and no second badge.** A request for a cropped device or a second
  badge on one page is a request to break Apple's terms, not a design choice. The
  reopen path is below.

## How to reopen

- If Apple's guidelines change, or Apple publishes approved partial-device artwork,
  read the page again and redo the affected images.
- If the screenshots are retaken on a newer iPhone, swap the bezel. That is one
  argument to `scripts/make-images.py`.
- If the owner decides to accept the risk of breaching Apple's terms, record that
  here with its cost. The cost is losing the right to use the artwork: the bezel
  license ends automatically on breach, and the badge license is conditional on
  compliance.
