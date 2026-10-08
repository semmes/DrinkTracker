# 0060 — The App Store's creative assets show the count and its pattern, never a drink

**Status:** proposed. The assets are rendered and checked; which of them go to
App Store Connect, and when, is the owner's · **Date:** 2026-10-08 ·
**Relates to:** ADR-0001 (no celebration), ADR-0006 (no scores), ADR-0007 (the
ramp), ADR-0010 (where brand colour goes), ADR-0034 (the hero band), ADR-0056
(Apple's devices, on Apple's terms)

## Context

iOS 27 and iPadOS 27 added two places for artwork of a developer's own on the
App Store, which App Store Connect calls creative assets: a **product page
header** above the icon and name (21:9 at 3840 × 1646, or a universal 16:9 asset
at 5244 × 2950), and a **search results** asset that replaces the screenshots in
a search result (3:2, up to 3840 × 2560, or the universal one). Both are
optional, and both take an image or a video. Apple's templates mark an Art Safe
Area in each: 1646 × 661 of the header and 2168 × 1030 of the search results
asset, both centred, and 1402 × 962 of the universal one, centred across and in
its upper half. The specifications and the safe areas are in
`scripts/app-store-creative/README.md` with their sources.

The obvious banner for a drink tracker shows drinks, and three things narrow it:

- **4+.** Apple's asset best practices: "Assets displayed on the App Store must
  meet a 4+ age rating, even if your app's rating is higher and it's intended for
  an older audience." Guideline 2.3.8 asks the same of the app's other metadata:
  "make sure your app and in-app purchase icons, screenshots, and previews adhere
  to a 4+ age rating even if your app is rated higher". Tallyist is rated 18+,
  with "Frequent" alcohol references (the product page, 2026-09-26). Where the
  line falls is a judgment. The screenshots have been held to 2.3.8 since 1.0
  while showing a drink tracker in use, and the subtitle beside every placement,
  "Alcoholic Drink Tracker", passed review too. But Apple's
  help describes creative assets as "distinct from the in-use functionality
  requirement in app previews and screenshots": brand art, not the app in use.
  In brand art a glass, a bottle or the word "drink" is a picture of alcohol for
  its own sake.
- **The rest of Apple's rules.** No prices, URLs, copyright symbols, other
  platforms or Apple recognitions; one clear idea; legible text, with the focal
  point in the centre; and for search results, "be sure your app or game's purpose
  is obvious at a glance". App Review rejected 1.4 (1) under guideline 2.3.2 for
  "text that is small or otherwise hard to read" in a promotional image, so
  legibility is not hypothetical here.
- **The brand and its licences.** One hue; the biggest thing on a surface is a
  count; no illustration style; the mark never locked up with text
  (`docs/design-system.md` §1). Devices only in Apple's bezels, on the terms
  ADR-0056 records: no crop and nothing drawn over the device. And SF Pro: the San
  Francisco licence, as Apple's Fonts page presents it (read 2026-10-08), allows
  the font "solely for creating mock-ups of user interfaces", including "the right
  to show the Apple Font in screen shots, images, mock-ups or other depictions" of
  the software, and says that "except as expressly provided for herein" it may not
  be used to "create, develop, display or otherwise distribute any documentation,
  artwork, website content or any other work product".

The options, argued honestly:

- **No search results asset at all.** Without one, the App Store shows the
  In-App Events, previews and screenshots, which say outright what the app is
  for, drinks included. It costs nothing and risks nothing at review, and it
  gives up the one placement made for a first impression. It stays open (How to
  reopen).
- **The mark, large, as a brand header.** It is the strongest brand statement,
  but the icon, which is the mark, sits directly below the header, and a headline
  beside it would be the lockup §1 forbids.
- **Screenshots in a device.** Accurate, but the screenshots already follow the
  header on the page, and the App Store crops the header's edges, where Apple's
  terms allow no crop of a device.
- **The app's own interface, without a device.** The counter and the calendar
  are what the app is, neither shows a drink, and both are drawn from the
  shipping views' geometry.

## Decision

Every asset shows **a count and the pattern it makes**: the headline "See your
own pattern.", the website's and the film's own line, over the app's counter (−,
a 2 on its band tile, ＋) and a month of the app's calendar on the app's own
ground, black in dark and white in light, with today, the month's last day, in
the counter's band. They sit on the icon's blue field, with the rest of the
calendar out of focus and the website's backlight behind. No drink is drawn and
the word is not used. `scripts/app-store-creative/` renders all of them and
checks each.

- **The month is drawn as its pattern:** no day numbers and no weekday letters,
  which at App Store sizes would be text of three to six points. The headline is
  the only text.
- **The interface is drawn flat, as the app draws it:** no glow, shine, shadow
  or tilt.
- **Key elements stand 4% inside each safe area,** which is the worst case, not
  a frame to draw up to.
- **Dark is the recommendation;** the light set is the other side of a product
  page optimization test, which Apple suggests for header visuals.
- **The dedicated header and search results assets are the recommendation**
  over the universal one. On an iPhone search result about 361 points wide (an
  estimate), the dedicated asset's headline renders at about 16 points, and the
  universal's at about 11 if the result shows its full-height 3:2 crop, because
  the universal's safe area is the smallest of the three. Used as the header, the
  universal's month is also cut through a row by any crop between its safe area
  and its full frame. It stays available as one asset for both placements.
- **Inter 4.0 (OFL) stands in for SF Pro,** in the headline and the counter's
  numeral, subset and committed beside the generator, so the fonts are the same
  on any machine.

## Consequences

- **The art does not say "alcohol".** The purpose comes from the subtitle beside
  it ("Alcoholic Drink Tracker" on the live listing) and from what is drawn, a
  counter and a calendar shaded by amount. Against Apple's "purpose is obvious at
  a glance", that is the cost: the art alone could belong to any habit tracker.
  "Count what you drink.", the website's first line, would state the purpose
  outright and is left out by the judgment above.
- **The type is close to the app's, not the app's.** Inter is near SF Pro, and
  the counter's numeral is Inter Medium with a round-joined stroke where the app
  draws SF Rounded semibold. The numeral in SF Rounded is arguably a depiction of
  the interface, which the licence allows; a headline in SF Pro would be artwork,
  which it names. A screenshot below the header shows the real thing.
- **Accurate where it counts.** The counter's geometry, the calendar's cells,
  outline and inks, and the band rule (two drinks of about 2.7 standard drinks
  are in 3–5) are the app's, and on the app's own ground the inks keep their
  order: a no-alcohol cell's L\* is 16.6 against a 1–2 cell's 33.9 in dark, and
  91.0 against 72.7 in light. In dark mode the today ring is the 3–5 fill's
  colour, so it does not show around today's cell, as in the app. Not the app's:
  the type, the card's padding and corner (proportions of the cell), and the
  missing day numbers.
- **Two assets mean two uploads and two approvals;** the universal is one.
- **The light set's count is 4.42:1,** white on 450, the app's own light hero
  pair, held to the large-text bar as the app holds it.
- **The pixels are not guaranteed across machines.** The fonts are committed,
  but Chromium rasterises text a little differently on macOS and Linux; the
  checks run wherever it renders.
- **Nothing here is uploaded.** The PNGs (about 54 MB for all six) stay out of
  git and are rendered on demand; the generator needs Node and Playwright.
- **Not verified:** how App Store Connect's Preview crops each placement on an
  iPhone and an iPad in each orientation (the safe areas are Apple's template
  layers; the crops on the proof sheet are illustrative); App Review's reading of
  4+ for a calendar shaded by amount; how either set reads at the top of the App
  Store in its light and dark appearances on a device.
- **It bears on an open item elsewhere.** The product film's type is SF Pro
  Expanded, which CLAUDE.md lists as the owner's to settle ("a font licensed for
  advertising would be a one-line swap and a re-render", the bullet "The press
  page's film…"). The licence's words above are a reason to look at it: a film
  that shows the app's screens may be a depiction the licence allows, and its
  title cards may be artwork. Nothing is changed there.

## How to reopen

- **App Review objects** to a calendar shaded by amount, or to the count, under
  the 4+ rule: the counter alone, or the calendar without colour, are the next
  steps down, and the headline stays.
- **The search asset does not earn its place,** in a product page optimization
  test or on the owner's reading of "obvious at a glance": remove it, and the
  screenshots return to search results.
- **The owner reads 4+ more widely,** as the reviews of the screenshots and the
  subtitle suggest App Review does: "Count what you drink." can come back through
  the copy review, first as one side of a test.
- **Apple publishes per-placement crops** that the template's safe areas do not
  anticipate, or Preview shows a crop cutting the headline or the counter:
  re-lay out in `layout()`.
- **SF Pro becomes usable here** (a licence for advertising, or new terms): swap
  the `@font-face` block in `banner.html` for it and re-render.
- **A localization ships:** Apple asks for the text to be localized; the headline
  is one string, and it goes through the copy review.
- **A product page optimization test** shows the light set doing better: swap the
  recommendation, not the art.
- **A seasonal or feature asset** (the watch, say) wants a device: that is
  ADR-0056's terms, and a new decision.
