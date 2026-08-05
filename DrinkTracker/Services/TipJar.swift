import Foundation
import Observation
import StoreKit
import UserNotifications

/// The tip jar: one consumable and two auto-renewing subscriptions.
///
/// In-App Purchase, not Apple Pay, on purpose — guideline 3.1.1 requires IAP for
/// anything digital sold in-app, tips included, and Apple Pay is reserved for
/// physical goods. The customer experience is the same one-confirm sheet either
/// way. Tips unlock nothing: every feature ships to everyone, which keeps this a
/// gift rather than a paywall (ADR-0012).
///
/// The recurring products come with a promise the UI states outright: a local
/// notification a week before each renewal, so cancelling before being charged is
/// always realistic. Scheduled from the entitlement's own expiration date and
/// re-derived on every refresh, so it survives renewals, plan changes, and
/// reinstalls without a server.
@Observable
@MainActor
final class TipJar {

  enum Availability {
    /// Products not fetched yet.
    case loading
    /// Products loaded; purchases possible.
    case ready
    /// The store had nothing for us — not configured, or no network. The
    /// Settings row simply says tips aren't available; nothing else degrades.
    case unavailable
  }

  enum PurchaseOutcome {
    case purchased
    case cancelled
    case pending
    case failed
  }

  private(set) var availability: Availability = .loading
  private(set) var oneDrink: Product?
  private(set) var monthlySupport: Product?
  private(set) var yearlySupport: Product?

  /// The active recurring product, if any, and when it next renews.
  private(set) var activeSupportID: String?
  private(set) var supportRenewalDate: Date?

  static let oneDrinkID = "com.shawnsemmes.DrinkTracker.tip.onedrink"
  static let monthlyID = "com.shawnsemmes.DrinkTracker.support.monthly"
  static let yearlyID = "com.shawnsemmes.DrinkTracker.support.yearly"

  /// Apple's cap on quantity per transaction. The stepper stops here; a second
  /// purchase is always possible.
  static let maximumDrinksPerPurchase = 10

  private static let allIDs = [oneDrinkID, monthlyID, yearlyID]
  private static let reminderIdentifier = "tallyist-support-renewal-reminder"

  /// Called from the support screen's `.task`, and structured so the view owns
  /// the whole lifetime: after loading products and status this keeps awaiting
  /// `Transaction.updates` until the `.task` is cancelled on disappear. No
  /// stored `Task`, so nothing to cancel in a `deinit` — which couldn't touch
  /// MainActor state anyway.
  func start() async {
    await loadProducts()
    await refreshSupportStatus()
    for await update in Transaction.updates {
      guard case .verified(let transaction) = update else { continue }
      await transaction.finish()
      await refreshSupportStatus()
    }
  }

  private func loadProducts() async {
    do {
      let products = try await Product.products(for: Self.allIDs)
      oneDrink = products.first { $0.id == Self.oneDrinkID }
      monthlySupport = products.first { $0.id == Self.monthlyID }
      yearlySupport = products.first { $0.id == Self.yearlyID }
      availability = oneDrink == nil && monthlySupport == nil && yearlySupport == nil
        ? .unavailable
        : .ready
    } catch {
      availability = .unavailable
    }
  }

  // MARK: - Purchasing

  /// One transaction for `count` drinks, clamped to Apple's per-transaction cap.
  func buyDrinks(count: Int) async -> PurchaseOutcome {
    guard let product = oneDrink else { return .failed }
    let quantity = max(1, min(count, Self.maximumDrinksPerPurchase))
    return await purchase(product, options: [.quantity(quantity)])
  }

  func subscribe(to product: Product) async -> PurchaseOutcome {
    let outcome = await purchase(product, options: [])
    if outcome == .purchased {
      // Ask only once there is actually something to remind about. A denial
      // doesn't block the subscription — the promise just can't be kept, and
      // the UI says so.
      _ = try? await UNUserNotificationCenter.current()
        .requestAuthorization(options: [.alert, .sound])
      await refreshSupportStatus()
    }
    return outcome
  }

  private func purchase(
    _ product: Product,
    options: Set<Product.PurchaseOption>
  ) async -> PurchaseOutcome {
    do {
      switch try await product.purchase(options: options) {
      case .success(let verification):
        guard case .verified(let transaction) = verification else { return .failed }
        await transaction.finish()
        await refreshSupportStatus()
        return .purchased
      case .userCancelled:
        return .cancelled
      case .pending:
        return .pending
      @unknown default:
        return .failed
      }
    } catch {
      return .failed
    }
  }

  /// Re-syncs entitlements with the App Store, for a new device or reinstall.
  func restorePurchases() async {
    try? await AppStore.sync()
    await refreshSupportStatus()
  }

  // MARK: - Status

  func refreshSupportStatus() async {
    var latestID: String?
    var latestExpiration: Date?
    for await entitlement in Transaction.currentEntitlements {
      guard case .verified(let transaction) = entitlement,
            transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID
      else { continue }
      if let expiration = transaction.expirationDate,
         expiration > (latestExpiration ?? .distantPast) {
        latestExpiration = expiration
        latestID = transaction.productID
      }
    }
    activeSupportID = latestID
    supportRenewalDate = latestExpiration
    await scheduleRenewalReminder()
  }

  // MARK: - The cancel reminder

  /// One pending notification, a week before the next renewal, replaced on every
  /// refresh so it tracks the entitlement rather than the purchase moment.
  private func scheduleRenewalReminder() async {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

    guard let renewal = supportRenewalDate, activeSupportID != nil else { return }
    let fireDate = renewal.addingTimeInterval(-7 * 24 * 60 * 60)
    guard fireDate > Date().addingTimeInterval(60) else { return }

    let content = UNMutableNotificationContent()
    content.title = "Tallyist support renews in a week"
    content.body =
      "Your recurring tip renews on \(renewal.formatted(date: .abbreviated, time: .omitted)). Cancel any time in the App Store — the app stays the same either way."
    content.sound = nil

    let components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: fireDate
    )
    let request = UNNotificationRequest(
      identifier: Self.reminderIdentifier,
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    )
    try? await center.add(request)
  }
}
