import Foundation

/// How finely the Trends chart divides a range into bars, and so what its
/// dashed line averages (ADR-0059): a bar per day, per calendar week or per
/// calendar month, with the line on the same scale — per day over daily bars,
/// per week over weekly ones, per month over monthly ones — because a line on
/// another scale than its bars reads as every bar being far above or below it
/// (ADR-0028).
///
/// Week and Month are always daily. Quarter and Year default to their own
/// buckets, weekly and monthly, and the reader may choose a finer grain to see
/// the range by day, or Year by week. The choice is view state: nothing is
/// stored, and each visit to Trends opens on the defaults (the owner's
/// decisions of 2026-10-01).
public enum TrendGrain: String, CaseIterable, Identifiable, Sendable {
  case day
  case week
  case month

  public var id: String { rawValue }

  /// The calendar unit one bar spans.
  public var component: Calendar.Component {
    switch self {
    case .day: .day
    case .week: .weekOfYear
    case .month: .month
    }
  }
}

extension TrendRange {
  /// The grain the range opens on: daily on the rolling ranges, weekly at
  /// Quarter and monthly at Year — the buckets the chart has always drawn.
  public var defaultGrain: TrendGrain {
    switch self {
    case .week, .month: .day
    case .quarter: .week
    case .year: .month
    }
  }

  /// The grains a reader may choose between, finest first. One on Week and
  /// Month, so no choice is offered there. Quarter offers no monthly grain, by
  /// the owner's choice: its 13 weeks usually hold two whole months and parts
  /// of two more, and between one and three whole months on any day.
  public var grains: [TrendGrain] {
    switch self {
    case .week, .month: [.day]
    case .quarter: [.day, .week]
    case .year: [.day, .week, .month]
    }
  }
}
