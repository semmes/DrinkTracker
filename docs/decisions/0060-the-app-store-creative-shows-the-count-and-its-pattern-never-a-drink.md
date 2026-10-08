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
optional, both take an image or a video, and Apple's templates mark an Art Safe
Area in each that is a small centred box: 1646 × 661 of the header, 2168 × 1030
of the search results asset, 1402 × 962 of the universal one. The specifications
and the safe areas are in `scripts/app-store-creative/README.md` with their
sources.

The obvious banner for a drink tracker shows drinks, and three things rule that
out or narrow everything else:

- **4+.** Apple's asset best practices: "Assets displayed on the App Store must
  meet a 4+ age rating, even if your app's rating is higher and it's intended for
  an older audience." Tallyist is rated 18+, with "Frequent" alcohol references
  (the product page, 2026-09-26). A glass, a bottle, the app's own drink glyphs,
  or the word "drink" in an alcohol tracker's art is an alcohol reference.
- **The rest of Apple's rules.** No prices, URLs, copyright symbols, other
  platforms or Apple recognitions; one clear idea; legible text with the focal
  point in the centre. App Review rejected 1.4 (1) under guideline 2.3.2 for "text
  that is small or otherwise hard to read" in a promotional image, so legibility
  is not hypothetical here.
- **The brand and its licences.** One hue; the biggest thing on a surface is a
  count; no illustration style; the mark never locked up with text
  (`docs/design-system.md` §1). Devices only in Apple's bezels, whose licence the
  owner accepted for the website (ADR-0056). And SF Pro: the San Francisco
  licence, as Apple's Fonts page presents it (read 2026-10-08), allows the font
  "solely for creating mock-ups of user interfaces" and says it may not be used to
  "create, develop, display or otherwise distribute any documentation, artwork,
  website content or any other work product".

The options that remain, argued honestly:

- **The mark, large, as a brand header.** It is the strongest brand statement,
  but the icon, which is the mark, sits directly below the header, and a headline
  beside it would be the lockup §1 forbids.
- **Screenshots in a device.** Accurate, but it needs Apple's bezels under a
  licence accepted for another use, and the screenshots already follow the header
  on the page.
- **The app's own interface, without a device.** The counter and the calendar
  are what the app is, neither refers to alcohol, and both are drawn from the
  shipping views' geometry.

## Decision

Every asset shows **a count and the pattern it makes**: the headline "See your
own pattern.", the website's and the film's own line, over the app's counter (−,
a 2 on its band tile, ＋) and a month of the app's calendar with today in the
counter's band, on the icon's blue field with the rest of the calendar out of
focus and the website's backlight behind. Nothing shows a drink and the word is
not used. `scripts/app-store-creative/` renders all of them and checks each.

- **Dark is the recommendation;** the light set is the other side of a product
  page optimization test, which Apple suggests for header visuals.
- **The dedicated header and search results assets are the recommendation** over
  the universal one. On an iPhone search result about 361 points wide (an
  estimate), the dedicated asset's headline renders at about 16 points and the
  universal's at about 12, because the universal's safe area is the smallest of
  the three. The universal stays available as one asset for both placements.
- **Inter 4.0 (OFL) stands in for SF Pro,** subset and committed beside the
  generator, so a render is the same on any machine.

## Consequences

- **The art does not say "alcohol".** The purpose comes from the subtitle beside
  it ("Alcoholic Drink Tracker" on the live listing) and from what is drawn, a
  counter and a calendar shaded by amount. "Count what you drink.", the website's
  first line, would state the purpose outright and is left out for 4+.
- **The type is close to the app's, not the app's.** Inter is near SF Pro, and
  the counter's numeral is Inter Medium with a round-joined stroke where the app
  draws SF Rounded semibold. A screenshot beside the header shows the real thing.
- **Accurate where it counts.** The counter's geometry, the calendar's cells,
  outline and inks, and the band rule (two drinks of about 2.7 standard drinks are
  in 3–5) are the app's. In dark mode the today ring is the 3–5 fill's colour, so
  it does not show around today's cell, as in the app.
- **Two assets mean two uploads and two approvals;** the universal is one.
- **The light set's count is 4.42:1,** white on 450, the app's own light hero
  pair, held to the large-text bar as the app holds it.
- **Nothing here is uploaded.** The PNGs (55 MB for all six) stay out of git and
  are rendered on demand; the generator needs Node and Playwright.
- **Not verified:** how App Store Connect's Preview crops each placement on an
  iPhone and an iPad in each orientation (the safe areas are Apple's template
  layers; the crops on the proof sheet are illustrative); App Review's reading of
  4+ for a calendar shaded by amount; how either set reads at the top of the App
  Store in its light and dark appearances on a device.
- **It bears on an open item elsewhere.** The product film's type is SF Pro
  Expanded, which CLAUDE.md lists as the owner's to settle ("a font licensed for
  advertising would be a one-line swap and a re-render", the bullet "The press
  page's film…"); the licence's words quoted above are the reason to settle it.
  Nothing is changed there.

## How to reopen

- **App Review objects** to a calendar shaded by amount, or to the count, under
  the 4+ rule: the counter alone, or the calendar without colour, are the next
  steps down, and the headline stays.
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
