import Foundation

/// The in-flight state of the drink-detail sheet.
///
/// A draft is always immediately loggable — it is seeded with the type's defaults
/// the moment the sheet opens, which is what makes the two-tap fast path work.
public struct DrinkDraft: Equatable, Sendable {
  public var type: DrinkType
  public var selectedSize: DrinkSizeOption
  /// Volume used when `selectedSize` is the Custom pill.
  public var customVolumeOunces: Double
  public var abvPercent: Double
  public var isABVExpanded: Bool
  /// Set when the draft came from tapping Edit on an existing entry.
  public var editingEntryID: UUID?

  public init(type: DrinkType) {
    self.type = type
    self.selectedSize = type.defaultSizeOption
    self.customVolumeOunces = type.defaultVolumeOunces
    self.abvPercent = type.defaultABVPercent
    self.isABVExpanded = false
    self.editingEntryID = nil
  }

  /// Rebuilds a draft from an already-logged drink, for the Edit path.
  public init(editing drink: LoggedDrink) {
    self.type = drink.type
    let match = drink.type.sizeOptions.first { $0.volumeOunces == drink.volumeOunces }
    self.selectedSize = match ?? .custom
    self.customVolumeOunces = drink.volumeOunces
    self.abvPercent = drink.abvPercent
    self.isABVExpanded = false
    self.editingEntryID = drink.id
  }

  /// Materialises the draft into a value ready to persist.
  ///
  /// Re-logging an edited drink reuses the original identity so the store
  /// replaces the previous entry's contribution rather than adding a duplicate.
  public func makeLoggedDrink(region: Region, loggedAt: Date = Date()) -> LoggedDrink {
    LoggedDrink(
      id: editingEntryID ?? UUID(),
      loggedAt: loggedAt,
      type: type,
      volumeOunces: volumeOunces,
      abvPercent: abvPercent,
      region: region
    )
  }

  public var volumeOunces: Double {
    selectedSize.volumeOunces ?? customVolumeOunces
  }

  public func standardDrinks(region: Region) -> Double {
    StandardDrink.count(volumeOunces: volumeOunces, abvPercent: abvPercent, region: region)
  }

  /// Switching type resets size and ABV to that type's defaults.
  public mutating func changeType(to newType: DrinkType) {
    guard newType != type else { return }
    type = newType
    selectedSize = newType.defaultSizeOption
    customVolumeOunces = newType.defaultVolumeOunces
    abvPercent = newType.defaultABVPercent
  }
}
