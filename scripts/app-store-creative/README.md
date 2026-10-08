# App Store creative assets

Tallyist's artwork for the App Store's product page header and search results,
the placements iOS 27 and iPadOS 27 added (Apple calls them creative assets).
`banner.html` draws them and `render.js` renders, exports and checks them.
The decision record is ADR-0060; what to upload where, and when, is in
`docs/app-store-listing.md` ("Creative assets: header and search results").

```
cd scripts/app-store-creative
node render.js            # all six into ./out (not committed), about 40 s
```

It needs Node 18 or later and Playwright with its Chromium
(`npm i -g playwright && npx playwright install chromium`, or point
`PLAYWRIGHT_MODULE` at an installed copy). `--theme dark|light`,
`--fmt header|search|universal`, `--out DIR` and `--guides` (draws the template's
safe area, for proofs only) narrow or change a run. It prints one line of checks
per asset and exits 1 if any fails.

## What it makes

| File | Placement | Size | |
|---|---|---|---|
| `tallyist-header-3840x1646.png` | Product page header | 3840 × 1646, 21:9 | recommended |
| `tallyist-search-results-3840x2560.png` | Search results | 3840 × 2560, 3:2 | recommended |
| `tallyist-universal-5244x2950.png` | Both (header, with "Use header asset in search results") | 5244 × 2950, 16:9 | one asset for both |
| `…-light-…` (three more) | The same placements, light appearance | as above | a product page optimization test |

Each is 8-bit RGB with no alpha and an `sRGB` chunk, as App Store Connect asks
("Images can't include alpha channels or transparencies").

## What Apple specifies

From App Store Connect Help, "Creative assets specifications", and Apple's
templates, both read on 2026-10-08:

- **Product page header:** 21:9 at 3840 × 1646 (JPEG or PNG), or the 16:9
  universal asset at 5244 × 2950 (PNG only).
- **Search results:** 3:2 from 1920 × 1280 to 3840 × 2560 (JPEG or PNG), or the
  universal asset. With no search results asset, the App Store falls back to
  In-App Events, app previews and screenshots.
- **Art safe areas**, the "Art Safe Area" layer of each template (the Sketch
  file and the Photoshop files agree): header 1646 × 661 at (1097, 493), centred;
  search results 2168 × 1030 at (836, 765), centred; universal 1402 × 962 at
  (1921, 660), centred across and in the upper half. The templates' sample art
  keeps its subject's head in the safe area and lets the rest run off the bottom.
- **Content** ("App Store asset best practices and resources",
  developer.apple.com/app-store/asset-best-practices/): assets "must meet a 4+
  age rating, even if your app's rating is higher"; no prices, discounts, website
  URLs or copyright symbols; no other platforms or marketplaces; no Apple
  recognitions; one clear idea, legible, with the focal point in the centre;
  text a short phrase that "enhances your visual rather than describes it".

## What it shows, and why

One idea in every asset: **a count, and the pattern it makes.** The headline is
"See your own pattern.", the website's and the film's own line, which the copy
review already passed. Under it is the app's counter, CountStepper's hero form
(− on glass, the count on its band tile, ＋ on AccentFill), and a month of the
app's calendar, today's cell in the same band as the counter. Behind them the
rest of the calendar is out of focus, on the icon's blue field with the
website's backlight.

- **No drink anywhere.** Tallyist is rated 18+ for alcohol references, and a
  creative asset must meet 4+. No glass, bottle or drink glyph is drawn and the
  word "drink" is not used, so "Count what you drink.", the website's first
  line, is left out. Day numbers and a count are not alcohol references.
- **One hue.** Every colour is a named step of the Tallyist Blue ramp or the
  app's own ink for that appearance: the calendar's dark steps 600/400/200/100 or
  light steps 250/450/700/800, the accent 400 (dark) or 500 (light), AccentFill
  500. In the dark asset the headline is the icon's two tones, the mark's
  near-white and the slash's 250.
- **Accurate.** The counter and the month are drawn from the shipping views'
  geometry: 42-point cells with 6-point gaps and a corner of 0.28 of the side;
  the alcohol-free outline; a 126-point tile with a 36-point corner between
  68-point discs 26 points away. Two drinks of about 2.7 standard drinks fall in
  the 3–5 band, so the tile and today's cell take that band. In the app the
  today ring is the accent, which is the 3–5 fill in dark mode, so it does not
  show there either.
- **No device.** Apple's marketing guidelines allow only Apple's own bezels,
  under a licence the owner accepted for the website only (ADR-0056), so the
  interface floats free.

## Type

Inter 4.0 (SIL Open Font License 1.1, `fonts/OFL.txt`) stands in for SF Pro.
The San Francisco licence, as Apple's Fonts page presents it (read 2026-10-08),
allows the font "solely for creating mock-ups of user interfaces" and says it
may not be used to "create, develop, display or otherwise distribute any
documentation, artwork, website content or any other work product". Inter
Display Bold sets the headline, at weight 700 like the website's display
headings and tracked −0.026 em; Inter sets the calendar's numerals. The
counter's numeral is SF Rounded semibold in the app; here it is Inter Medium
with a round-joined stroke of 6.2% of its size, which rounds its terminals the
same way. The four files are subsets of Inter
4.0 to Basic Latin, Latin-1 Supplement, Latin Extended-A and General Punctuation
(about 300 KB together), made with fontTools' `pyftsubset`; Inter declares no
Reserved Font Name. A render with the full fonts is pixel-identical, and a
headline with a character outside the subsets stops the render rather than
falling back to another font.

## What `render.js` checks

On the finished ground, before any text is drawn on it, every pixel behind the
headline and behind the tinted word is composited with that text's colour, and
the least favourable result is kept.

| Asset | Headline | Tinted word | Count | ＋ | In the safe area |
|---|---|---|---|---|---|
| Header, dark | 8.66:1 | 6.33:1 | 5.77:1 | 5.39:1 | headline, counter, month |
| Search results, dark | 10.16:1 | 4.93:1 | 5.77:1 | 5.39:1 | headline, counter, month |
| Universal, dark | 10.60:1 | 5.20:1 | 5.77:1 | 5.39:1 | headline, counter |
| Header, light | 14.39:1 | 4.72:1 | 4.42:1 | 5.39:1 | headline, counter, month |
| Search results, light | 14.87:1 | 4.75:1 | 4.42:1 | 5.39:1 | headline, counter, month |
| Universal, light | 14.36:1 | 4.55:1 | 4.42:1 | 5.39:1 | headline, counter |

Text is held to 4.5:1. The count is held to the large-text bar, 3:1: it is the
app's own hero pair, and in light mode that pair, white on 450, is 4.42:1 in the
app too (ADR-0034). The ＋ is a graphic, also 3:1. A soft scrim sits behind
each headline, 800 at most 42% in dark and white at most 85% in light, so the
tinted word clears 4.5:1; it has no edge.

The universal's month starts just below its safe area on purpose: a crop to the
safe area alone leaves the headline and the counter with nothing cut off, and a
3:2 search crop shows the whole month.

**Legibility.** At an iPhone search result about 361 points wide (a 393-point
screen less its margins, an estimate), the dedicated search asset's headline
renders at about 16 points and the universal's at about 12. That is why the
dedicated pair is the recommendation.

## Changing it

The headline is set in `headline()`, the per-placement geometry in `layout()`,
and both themes in `THEME`. A new headline needs the copy review, and the 4+
rule still applies. Every change needs a fresh `node render.js` with every check
passing, and a look at the output.
