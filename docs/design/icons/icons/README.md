# Tallyist drink glyphs

24×24 filled source art (evenodd cut-outs), 2pt safe margin, shared baseline (y 20).

- `alcoholfree` is an outline by rule (the marker sits off the ramp).

## Making custom SF Symbols
1. SF Symbols app → File → New Symbol from Template (or export `circle` as a template).
2. Paste the path into the **Regular-M** layer, scaled so the 24-unit box fills the template's glyph box; outline the `alcoholfree` strokes first.
3. Export and drop into `Assets.xcassets`; name as below. iOS derives Small/Large and the other weights.

## Names
| file | symbol name | replaces |
|---|---|---|
| beer | tally.beer | mug.fill |
| wine | tally.wine | wineglass.fill |
| spirit | tally.spirit | flask.fill |
| cocktail | tally.cocktail | — (candidate fifth type) |
| other | tally.other | cup.and.saucer.fill |
| standard | tally.standard | drop.fill |
| health | tally.health | heart.text.square |
| alcoholfree | tally.alcoholfree | checkmark.circle |

Change site: `DrinkTrackerCore/Sources/DrinkTrackerCore/DrinkType.swift` (`symbolName`), plus the two hard-coded companions in `TodayDrinkRow`, `DrinkRow`, `PeriodDetailView`, `TodayView`, `DayLogSheet`, `BulkFillSheet`.
