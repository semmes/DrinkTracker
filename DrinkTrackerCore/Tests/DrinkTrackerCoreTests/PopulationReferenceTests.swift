import Foundation
import Testing

@testable import DrinkTrackerCore

/// Feature C's data file and math (ADR-0018). The bundled table itself is
/// under test — a drifted or mistranscribed row fails here, not on a user.
@Suite("Population reference")
struct PopulationReferenceTests {

  private var reference: PopulationReference {
    get throws { try #require(PopulationReference.bundled) }
  }

  @Test("The bundled file loads, names its source, and states its year")
  func fileLoads() throws {
    let ref = try reference
    #expect(ref.year == 2020)
    #expect(ref.source.contains("National Alcohol Survey"))
    #expect(ref.sourceURL.contains("arg.org"))
    #expect(!ref.derivation.isEmpty)
    #expect(ref.rows.count == 27)
  }

  @Test("Percentiles rise monotonically and levels never overlap")
  func tableIsCoherent() throws {
    let rows = try reference.rows
    for (a, b) in zip(rows, rows.dropFirst()) {
      #expect(a.percentDrinkers <= b.percentDrinkers)
      #expect(a.percentAllAdults <= b.percentAllAdults)
      #expect((a.drinksMax ?? .max) < b.drinksMin || a.drinksMax == nil)
    }
    // Only the top row is open-ended.
    #expect(rows.dropLast().allSatisfy { $0.drinksMax != nil })
    #expect(rows.last?.drinksMax == nil)
  }

  @Test("Every drinkers percentile is the published value renormalized, exactly")
  func renormalizationIsExact() throws {
    let ref = try reference
    let abstain = ref.abstainersPercentAllAdults
    for row in ref.rows {
      let expected = (row.percentAllAdults - abstain) / (100 - abstain) * 100
      #expect(abs(row.percentDrinkers - expected) < 0.06,
        "row ≤\(row.drinksMax.map(String.init) ?? "∞"): stored \(row.percentDrinkers), derived \(expected)")
      if let max = row.drinksMax {
        #expect(row.gramsMax == Double(max) * ref.gramsPerSurveyDrink)
      }
    }
  }

  @Test("Four US drinks a week reads: lower than roughly 35%")
  func usComparison() throws {
    // 4 US standard drinks = 56 g. Drinkers at or below 4/week: 65.3%,
    // so 34.7% drink more → "lower than roughly 35%".
    let grams = 4 * Region.unitedStates.gramsPureAlcoholPerStandardDrink
    #expect(try reference.comparison(gramsPerWeek: grams) == .lowerThan(percent: 35))
  }

  @Test("The same alcohol reads the same under every regional unit")
  func unitConversionIsMandatory() throws {
    // 56 g of ethanol a week is 4 US drinks, 7 UK units, or 5.6 AU drinks —
    // the comparison must not care which lens produced it (the spec's
    // silent-skew trap, covered for all three settings).
    let ref = try reference
    let usGrams = 4.0 * Region.unitedStates.gramsPureAlcoholPerStandardDrink
    let ukGrams = 7.0 * Region.unitedKingdom.gramsPureAlcoholPerStandardDrink
    let auGrams = 5.6 * Region.australia.gramsPureAlcoholPerStandardDrink
    // Regional grams are derived (a US drink computes to 14.0001 g), so the
    // three only agree to within real-world tolerance — which is the point.
    #expect(abs(usGrams - 56) < 0.01)
    #expect(abs(ukGrams - 56) < 0.01)
    #expect(abs(auGrams - 56) < 0.01)
    let expected = ref.comparison(gramsPerWeek: usGrams)
    #expect(ref.comparison(gramsPerWeek: ukGrams) == expected)
    #expect(ref.comparison(gramsPerWeek: auGrams) == expected)
  }

  @Test("A fractional average rounds up to the next level — conservative at the edge")
  func fractionalAverageRoundsUp(  ) throws {
    let ref = try reference
    // 4.3 US drinks brackets to ≤5 (69.4% of drinkers) → 30.6% more → 30.
    #expect(ref.comparison(gramsPerWeek: 4.3 * 14) == .lowerThan(percent: 30))
    // Just under a drink a week brackets to ≤1 (41.7%) → 58.3% more → 60.
    #expect(ref.comparison(gramsPerWeek: 0.5 * 14) == .lowerThan(percent: 60))
  }

  @Test("A zero average says nothing rather than something strange")
  func zeroAverageIsNil() throws {
    #expect(try reference.comparison(gramsPerWeek: 0) == nil)
    #expect(try reference.comparison(gramsPerWeek: -5) == nil)
  }

  @Test("Above the table the phrasing flips to more-than, never 'lower than 0%'")
  func topOfTableFlips() throws {
    // 80 US drinks a week: 98.6% of drinkers are at or below → 1.4% more,
    // which would round to "lower than 0%". Flips to more-than, floored.
    #expect(try reference.comparison(gramsPerWeek: 80 * 14) == .moreThan(percent: 95))
  }

  @Test("The history gate is four weeks")
  func minimumHistory() {
    #expect(PopulationReference.minimumHistory == 28 * 24 * 3600)
  }
}
