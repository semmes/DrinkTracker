import Foundation
import Testing

@testable import DrinkTrackerCore

/// Tier 1 — the one rounding time asleep passes through before it is printed
/// ("6h 12m") or spoken ("6 hours, 12 minutes"). The table and the sentence
/// both read these two integers, so a night that rounds up into the next
/// hour does so in both at once (ADR-0050, Phase 4).
@Suite("Health pairing — hours and minutes")
struct HealthPairingDurationTests {

  @Test("Whole hours and minutes come back as they are")
  func exactMinutes() {
    let (hours, minutes) = HealthPairing.hoursAndMinutes(6 * 3600 + 12 * 60)
    #expect(hours == 6)
    #expect(minutes == 12)
  }

  @Test("A half minute rounds up, and carries into the hour rather than reading 60 minutes")
  func halfMinuteCarries() {
    let (hours, minutes) = HealthPairing.hoursAndMinutes(6 * 3600 + 59 * 60 + 30)
    #expect(hours == 7)
    #expect(minutes == 0)
  }

  @Test("Just under a half minute rounds down")
  func underHalfMinuteRoundsDown() {
    let (hours, minutes) = HealthPairing.hoursAndMinutes(6 * 3600 + 59 * 60 + 29)
    #expect(hours == 6)
    #expect(minutes == 59)
  }

  @Test("Thirty seconds is one minute; twenty-nine is none")
  func smallDurations() {
    #expect(HealthPairing.hoursAndMinutes(30) == (0, 1))
    #expect(HealthPairing.hoursAndMinutes(29.9) == (0, 0))
  }

  @Test("Nothing, a negative and a non-finite duration are all zero")
  func degenerateDurations() {
    #expect(HealthPairing.hoursAndMinutes(0) == (0, 0))
    #expect(HealthPairing.hoursAndMinutes(-3600) == (0, 0))
    #expect(HealthPairing.hoursAndMinutes(.nan) == (0, 0))
    #expect(HealthPairing.hoursAndMinutes(.infinity) == (0, 0))
  }

  @Test("A duration past a week is clamped there instead of trapping")
  func absurdDurationIsClamped() {
    #expect(HealthPairing.hoursAndMinutes(1e300) == (7 * 24, 0))
    #expect(HealthPairing.hoursAndMinutes(Double.greatestFiniteMagnitude) == (7 * 24, 0))
  }

  @Test("Minutes never reach 60")
  func minutesStayUnderSixty() {
    for seconds in stride(from: 0.0, through: 36_000.0, by: 7.5) {
      let (_, minutes) = HealthPairing.hoursAndMinutes(seconds)
      #expect(minutes >= 0 && minutes < 60, "at \(seconds) s")
    }
  }
}
