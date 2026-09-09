# Tallyist tab-bar glyphs

The five glyphs the prototype draws in its tab bar (`../Tallyist iOS
Prototype.dc.html`, the `data-screen-label="Tab bar"` block), lifted into one
24×24 filled `<path>` each so `scripts/make-drink-symbols.py` can build them
into template symbols exactly as it builds the drink glyphs from
`../../icons/icons/` (ADR-0036, ADR-0040 amendment).

What changed in the lift, and why:

- The prototype draws the calendar's header line and its five squares as
  **white shapes over a filled body**. A symbol is one ink, so those are
  cut-outs here: the body is split at the header line into two contours and
  the squares are holes (the generator re-orients winding, so they read the
  same under either fill rule).
- `rect`/`circle` elements became path data with the same radii; nothing
  moved.
- The gear's path repeated each arc's end as a zero-length line; those are
  dropped. Its `stroke-width="0"` stroke is ignored.
- `today` is the prototype's *Filled* drop (`this.ICS.Filled.drop`), which the
  tab reads through `this.IC.drop`. It is the untyped drink's own shape; the
  drink-row version (`../../icons/icons/standard.svg`) is drawn cap-height,
  this one at the bar's size.

| file | symbol name | tab |
|---|---|---|
| today | tally.tab.today | Today |
| calendar | tally.tab.calendar | Calendar |
| trends | tally.tab.trends | Trends |
| history | tally.tab.history | History |
| settings | tally.tab.settings | Settings |

Change site: `DrinkTracker/Features/Navigation/AppTabs.swift` (`AppTab.symbolName`);
the generator cross-checks that list against this directory and the catalog.
