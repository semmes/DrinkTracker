import WatchKit

/// The receipt for a log on the wrist is felt, not shown (the watch plan,
/// Phase 3; ADR-0042): no confirmation step, no sheet, no "logged" screen.
/// The user is not looking, which is the whole reason a distinct feel matters.
///
/// Never `.success`: it reads as praise for the act (PRD invariant 8).
enum WatchHaptics {
  /// A drink logged by a touch on the screen, or removed by one.
  static func acknowledged() {
    WKInterfaceDevice.current().play(.click)
  }

  /// A drink logged by Double Tap — deliberately a different feel from a
  /// touch, so a pinch the user did not mean announces itself now rather
  /// than being found in History three days later (ADR-0042).
  static func loggedByGesture() {
    WKInterfaceDevice.current().play(.directionUp)
  }

  /// A refusal: − with nothing it may remove, a no-alcohol record on a day
  /// that has drinks, or a write that failed.
  static func refused() {
    WKInterfaceDevice.current().play(.failure)
  }
}
