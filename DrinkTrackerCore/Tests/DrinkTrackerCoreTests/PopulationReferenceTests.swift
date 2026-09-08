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

  @Test("Percentiles rise monotonically in every column, and levels never overlap")
  func tableIsCoherent() throws {
    let rows = try reference.rows
    for (a, b) in zip(rows, rows.dropFirst()) {
      for column in PopulationReference.Column.allCases {
        #expect(a.percentDrinkers(in: column) <= b.percentDrinkers(in: column))
        #expect(a.percentPublished(in: column) <= b.percentPublished(in: column))
      }
      #expect((a.drinksMax ?? .max) < b.drinksMin || a.drinksMax == nil)
    }
    // Only the top row is open-ended.
    #expect(rows.dropLast().allSatisfy { $0.drinksMax != nil })
    #expect(rows.last?.drinksMax == nil)
  }

  @Test("Every drinkers percentile is the published value renormalized, exactly, in every column")
  func renormalizationIsExact() throws {
    let ref = try reference
    for column in PopulationReference.Column.allCases {
      let abstain = ref.abstainersPercent(in: column)
      for row in ref.rows {
        let expected = (row.percentPublished(in: column) - abstain) / (100 - abstain) * 100
        #expect(abs(row.percentDrinkers(in: column) - expected) < 0.06,
          "\(column) row ≤\(row.drinksMax.map(String.init) ?? "∞"): stored \(row.percentDrinkers(in: column)), derived \(expected)")
      }
    }
    for row in ref.rows {
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

  @Test("Non-finite and absurd averages neither trap nor claim a bracket")
  func absurdAveragesAreSafe() throws {
    #expect(try reference.comparison(gramsPerWeek: .infinity) == nil)
    #expect(try reference.comparison(gramsPerWeek: .nan) == nil)
    // Past Int.max in survey drinks: the open-ended top row, not a trap.
    #expect(try reference.comparison(gramsPerWeek: 1e21) == .moreThan(percent: 95))
  }

  @Test("The history gate is four weeks")
  func minimumHistory() {
    #expect(PopulationReference.minimumHistory == 28 * 24 * 3600)
  }

  // MARK: - The survey's columns (ADR-0039)

  @Test("The men's and women's columns are bundled beside the total, abstainers stated per column")
  func columnsLoad() throws {
    let ref = try reference
    #expect(PopulationReference.Column.allCases == [.allAdults, .men, .women])
    #expect(ref.abstainersPercent(in: .allAdults) == 28)
    #expect(ref.abstainersPercent(in: .men) == 25)
    #expect(ref.abstainersPercent(in: .women) == 31)
    #expect(ref.drinkersPercent(in: .allAdults) == 72)
    #expect(ref.drinkersPercent(in: .men) == 75)
    #expect(ref.drinkersPercent(in: .women) == 69)
    // The page's own top row: 99 / 100 / 99 at 70 or more a week.
    let top = try #require(ref.rows.last)
    #expect(top.percentPublished(in: .men) == 99)
    #expect(top.percentPublished(in: .women) == 100)
    #expect(top.percentPublished(in: .allAdults) == 99)
    // And its first: 50 / 65 / 58 at one a week.
    let first = try #require(ref.rows.first)
    #expect(first.percentPublished(in: .men) == 50)
    #expect(first.percentPublished(in: .women) == 65)
    #expect(first.percentPublished(in: .allAdults) == 58)
  }

  @Test("The same four drinks a week read differently against each column")
  func columnComparisons() throws {
    let ref = try reference
    let four = 4 * 14.0
    // Men at or below 4 a week: 69% of all men, (69 − 25) / 75 = 58.7% of
    // men who drink → 41.3% more → "lower than roughly 40%".
    #expect(ref.comparison(gramsPerWeek: four, in: .men) == .lowerThan(percent: 40))
    // Women: 81% → (81 − 31) / 69 = 72.5% → 27.5% more → 30.
    #expect(ref.comparison(gramsPerWeek: four, in: .women) == .lowerThan(percent: 30))
    #expect(ref.comparison(gramsPerWeek: four, in: .allAdults) == .lowerThan(percent: 35))
    // One a week: men 50% → 33.3% → 66.7% more → 65; women 65% → 49.3% → 50.7% more → 50.
    #expect(ref.comparison(gramsPerWeek: 14, in: .men) == .lowerThan(percent: 65))
    #expect(ref.comparison(gramsPerWeek: 14, in: .women) == .lowerThan(percent: 50))
  }

  @Test("The total column is the default, so every existing caller reads what it always did")
  func totalIsTheDefault() throws {
    let ref = try reference
    for drinks in [0.5, 1, 4, 4.3, 12, 40, 80] {
      #expect(ref.comparison(gramsPerWeek: drinks * 14) == ref.comparison(gramsPerWeek: drinks * 14, in: .allAdults))
    }
  }

  @Test("Every column flips to more-than at the top and says nothing at zero")
  func columnsShareTheEdges() throws {
    let ref = try reference
    for column in PopulationReference.Column.allCases {
      #expect(ref.comparison(gramsPerWeek: 80 * 14, in: column) == .moreThan(percent: 95))
      #expect(ref.comparison(gramsPerWeek: 0, in: column) == nil)
      #expect(ref.comparison(gramsPerWeek: .nan, in: column) == nil)
    }
  }
}
