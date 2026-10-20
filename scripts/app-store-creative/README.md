# App Store creative assets

Tallyist's artwork for the App Store's product page header and search results,
the placements iOS 27 and iPadOS 27 added (Apple calls them creative assets).
`banner.html` draws them and `render.js` renders, exports and checks them.
The decision record is ADR-0060; what to upload where, and when, is in
`docs/app-store-listing.md` ("Creative assets: header and search results").

```
cd scripts/app-store-creative
node render.js            # all six into ./out (not committed), about 40 s
python3 proofs.py         # crop proofs of them, into ./out
```

`render.js` needs Node 18 or later and Playwright with its Chromium, installed
once with `npm i -g playwright && npx playwright install chromium`. It finds a
global install through `npm root -g`; `PLAYWRIGHT_MODULE`, a path to the module,
overrides that. `--theme dark|light`, `--fmt header|search|universal`,
`--out DIR` and `--guides` (draws the template's safe area and the 4% inset, for
proofs only) narrow or change a run. It prints one line of checks per asset and
exits 1 if any fails. `proofs.py` needs Python 3 and Pillow (`pip install
pillow`): it draws each asset with its safe area, beside what a crop to the safe
area keeps, and for the universal asset two illustrative crops, 21:9 and 3:2,
centred on its safe area.

## What it makes

| File | Placement | Size | |
|---|---|---|---|
| `tallyist-header-3840x1646.png` | Product page header | 3840 × 1646, 21:9 | recommended |
| `tallyist-search-results-3840x2560.png` | Search results | 3840 × 2560, 3:2 | recommended |
| `tallyist-universal-5244x2950.png` | Both (header, with "Use header asset in search results") | 5244 × 2950, 16:9 | one asset for both |
| `…-light-…` (three more) | The same placements, light appearance | as above | the other side of a product page optimization test |

Each is 8-bit RGB with no alpha and an `sRGB` chunk, as App Store Connect asks
("Images can't include alpha channels or transparencies"). The six come to about
54 MB.

## What Apple specifies

From App Store Connect Help, "Creative assets specifications" and "Manage your
App Store assets", and Apple's templates, all read on 2026-10-08:

- **Product page header:** 21:9 at 3840 × 1646 (JPEG or PNG), or the 16:9
  universal asset at 5244 × 2950 (PNG only).
- **Search results:** 3:2 from 1920 × 1280 to 3840 × 2560 (JPEG or PNG), or the
  universal asset. With no search results asset, the App Store shows In-App
  Events, app previews and screenshots instead.
- **Art safe areas**, the "Art Safe Area" layer of each template (the Sketch
  file and the Photoshop files agree): header 1646 × 661 at (1097, 493) and
  search results 2168 × 1030 at (836, 765), both centred; universal 1402 × 962
  at (1921, 660), centred across and set high (y 660 to 1622 of 2950). The
  templates' sample art keeps its subject's head in the safe area and lets the
  rest run off the bottom. Apple publishes no crops beyond these layers; App
  Store Connect's Preview shows the real ones.
- **Content** ("App Store asset best practices and resources",
  developer.apple.com/app-store/asset-best-practices/): assets "must meet a 4+
  age rating, even if your app's rating is higher"; no prices, discounts, website
  URLs or copyright symbols; no other platforms or marketplaces; no Apple
  recognitions; one clear idea, legible, with the focal point in the centre;
  text a short phrase that "enhances your visual rather than describes it"; and
  for search results, "be sure your app or game's purpose is obvious at a
  glance". App Review Guideline 2.3.8 holds the app's icons, screenshots and
  previews to the same 4+ rating.
- **Testing:** "you can use product page optimization to test alternative header
  visuals" (the same page). Apple documents no such test of a search results
  asset.

## What it shows, and why

One idea in every asset: **a count, and the pattern it makes.** The headline is
"See your own pattern.", the website's and the film's own line, which the copy
review passed in both places. With it are the app's counter, CountStepper's hero
form (− on glass, the count on its band tile, ＋ on AccentFill), and a month of
the app's calendar on the app's own ground, black in the dark set and white in
the light one, its last day today and in the same band as the counter. In the
search results and universal assets the headline stands over the two; in the
header it stands over the counter, with the month beside them. Behind them the
rest of the calendar is out of focus, with the website's backlight: in the dark
set the field is the ramp's deepest steps, 800 at the edges lit to 650, and in
the light set it is the app's grouped ground, #f2f2f7, lit to white, with washes
of the ramp's palest steps.

- **The month is drawn as its pattern.** Thirty days: eighteen recorded as no
  alcohol, seven in the 1–2 band, three in 3–5 (today among them), one in 6–9
  and one not logged, most of the colour in the week's last two columns. There
  are no day numbers and no weekday letters: at App Store sizes they would be
  text of three to six points, and 1.4 (1) was rejected under guideline 2.3.2
  for text that is "small or otherwise hard to read". The headline is the only
  words; the counter's 2 is part of the drawn counter (its contrast is below).
- **No drink, by judgment.** Tallyist is rated 18+ for frequent alcohol
  references, and a creative asset must meet 4+. No glass, bottle or drink glyph
  is drawn and the word "drink" is not used, so "Count what you drink.", the
  website's first line, is left out. That is a reading of the rule, not its
  wording: guideline 2.3.8 holds the screenshots to 4+ too, and they have shown
  a drink tracker in use since 1.0, and the listing's subtitle beside every
  placement says "Alcoholic Drink Tracker". The art stays on the side of the rule
  that needs no argument (ADR-0060).
- **One hue.** Every colour is a named step of the Tallyist Blue ramp or the
  app's own ink for that appearance: the calendar's dark steps 600/400/200/100 or
  light steps 250/450/700/800, the accent 400 (dark) or 500 (light), AccentFill
  500, and the card black or white, the app's own grounds. In the dark set the
  headline is the icon's two tones, the mark's near-white and the slash's 250.
- **The app's, as the app draws it.** 42-point cells with 6-point gaps and a
  corner of 0.28 of the side; the no-alcohol cell's fill (16% in dark, 10% in
  light) with its 35% outline at 0.04 of the side; a 126-point tile with a
  36-point corner between 68-point discs 26 points away; flat fills with no
  glow, shine, shadow or tilt, which the app does not draw either; the − keeps
  its glass, a soft highlight and a rim, and the card a hairline rim. On the
  app's ground the inks keep their order, measured on the render: a no-alcohol
  cell's L\* is 16.6 in dark against 33.9 for a 1–2 cell, and 90.9 in light
  against 72.7, so lightness still means amount. Two drinks of about 2.7
  standard drinks fall in the 3–5 band, so the tile and today's cell take that
  band; in dark mode the today ring is the accent, which is the 3–5 fill, so it
  does not show there, as in the app. Not the app's: the type (below), and the
  card's padding and corner, which are proportions of the cell.
- **No device.** The screenshots on the same page already show the app in
  use. A device would put Apple's bezels in a strip whose edges the App Store
  crops, and Apple's terms for its device images allow no crop and nothing drawn
  over them (ADR-0056), so the interface floats free.

## Type

Inter 4.0 (SIL Open Font License 1.1, `fonts/OFL.txt`) stands in for SF Pro.
The San Francisco licence, as Apple's Fonts page presents it (read 2026-10-08),
allows the font "solely for creating mock-ups of user interfaces", including "the
right to show the Apple Font in screen shots, images, mock-ups or other
depictions" of the software, and says that "except as expressly provided for
herein" it may not be used to "create, develop, display or otherwise distribute
any documentation, artwork, website content or any other work product". The
counter's numeral in SF Rounded could pass as a depiction of the interface; a
headline set in SF Pro is artwork. Inter sets both, which keeps the question out
of the art.

Inter Display Bold sets the headline, at weight 700 like the website's display
headings and tracked −0.026 em. The counter's numeral is SF Rounded semibold in
the app; here it is Inter Medium with a round-joined stroke of 6.2% of its size,
which rounds its terminals the same way. The two files are subsets of Inter 4.0
to Basic Latin, Latin-1 Supplement, Latin Extended-A, General Punctuation and
the minus sign (U+2212), about 150 KB together, made with fontTools'
`pyftsubset`; Inter declares no Reserved Font Name. A render with the full fonts
is pixel-identical. `banner.html` lists the code points the subsets cover
(`COVERED`), and a headline with a character outside them stops the render
rather than falling back to another font; `render.js` checks the list against
both fonts' character maps on every render, so a new subset cannot leave it
stale.

The fonts are the same on any machine; the pixels may not be. Chromium
rasterises text a little differently on macOS and Linux, so a render elsewhere
can differ at the edges of glyphs. The checks run wherever it renders.

## What `render.js` checks

- The file: its size, 8-bit RGB, no alpha and no transparency chunk; it adds the
  `sRGB` chunk.
- The safe area: the headline and the counter stand at least 4% of the safe
  area's width and height inside it, and so does the month except in the
  universal asset. The safe area is the worst case, not a frame to draw up to.
- The fonts: `COVERED` in `banner.html` against both fonts' character maps.
- Contrast: on the finished ground, before any text is drawn on it, every pixel
  behind the headline and behind the tinted word is composited with that text's
  colour, and the least favourable result is kept. The count and the ＋ are flat
  fills, so their pairs are computed from the fills; the rendered pixels give the
  same figures.

| Asset | Headline | Tinted word | Count | ＋ | 4% inside the safe area |
|---|---|---|---|---|---|
| Header, dark | 8.55:1 | 6.19:1 | 5.77:1 | 5.39:1 | headline, counter, month |
| Search results, dark | 10.29:1 | 5.00:1 | 5.77:1 | 5.39:1 | headline, counter, month |
| Universal, dark | 10.60:1 | 5.29:1 | 5.77:1 | 5.39:1 | headline, counter |
| Header, light | 14.37:1 | 4.75:1 | 4.42:1 | 5.39:1 | headline, counter, month |
| Search results, light | 14.95:1 | 4.74:1 | 4.42:1 | 5.39:1 | headline, counter, month |
| Universal, light | 14.59:1 | 4.64:1 | 4.42:1 | 5.39:1 | headline, counter |

The headline is held to 4.5:1. The count and the ＋ are parts of the drawn
counter, a picture of the app's interface, and are held to 3:1, the bar for
graphics. The count's pair is the app's own (ADR-0034): in light, white on 450 is
4.42:1, which the app's 68pt numeral carries as large text. In the art the
numeral shows at about 12 to 15 points on an iPhone (15 in the search asset, 13
in the universal's 3:2 crop, 12 in the header on a 393-point screen), where text
would want 4.5:1, so read as text the light count falls short. The dark count,
5.77:1, clears either bar, and dark is the recommendation. A soft scrim sits
behind each headline, 800 at most 42% in dark and white at most 85% in light, so
the tinted word clears 4.5:1; it has no edge.

The universal's month starts just below its safe area on purpose: a crop to the
safe area alone leaves the headline and the counter whole, and the full-height
3:2 crop shows the whole month. Used as the header, though, any crop between
those two cuts the month through a row (`proofs.py` draws a 21:9 crop that shows
it), which is one more reason the dedicated pair is recommended.

**Legibility.** On an iPhone search result about 361 points wide (a 393-point
screen less its margins, an estimate), the dedicated search asset's headline
renders at about 16 points. The universal's renders at about 11, if the search
result shows its full-height 3:2 crop. That is why the dedicated pair is the
recommendation.

## Changing it

The headline is set in `headline()`, the per-placement geometry in `layout()`,
and both themes in `THEME`. Some edges line up by construction: in the header,
the card stands on the inset's right edge, its top on the headline's cap line
(read from the laid-out headline in CSS's `cap` unit, so it follows a change of
font or size) and its foot on the band tile's, and its pitch follows from those;
in the search asset, the counter and the card share a centre line. A new
headline needs the copy review, and the 4+ rule still applies. Every change
needs a fresh `node render.js` with every check passing, `python3 proofs.py`,
and a look at the output.
