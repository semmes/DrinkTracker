import DrinkTrackerCore
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
/// always realistic. Scheduled from the entitlement's own expiration date, a
/// year of renewals ahead, and re-derived on every refresh, so it survives
/// renewals, plan changes, and reinstalls without a server. One instance lives
/// for the whole app, which refreshes it at launch and on every foreground
/// (ADR-0012's amendment of 2026-09-26): while it lived only on the tip jar
/// screen, a renewal's next reminder waited for someone to open that screen.
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
    /// The App Store reported a purchase the device could not verify. Money
    /// may have moved, so this is never reported as "nothing was charged".
    case unverified
    case failed
  }

  private(set) var availability: Availability = .loading
  private(set) var oneDrink: Product?
  private(set) var monthlySupport: Product?
  private(set) var yearlySupport: Product?

  /// The active recurring product, if any.
  private(set) var activeSupportID: String?

  /// The product that renews at the end of this period, from the renewal
  /// info: the other tip after a switch between monthly and yearly, which
  /// takes effect at the next renewal. Nil when unknown or when nothing
  /// renews.
  private(set) var renewingSupportID: String?

  /// Whether it renews or ends, on which date, and when its reminder fires.
  private(set) var supportRenewal: SupportRenewal?

  /// This device's notification setting, read on every refresh. The
  /// reminders are added only while notifications are allowed (otherwise the
  /// system keeps nothing), and the next refresh after permission is granted
  /// adds them.
  private(set) var notificationAuthorization: UNAuthorizationStatus?

  /// How many of the reminders are actually pending with the system after the
  /// last refresh, and when the first of them fires, for Diagnostics.
  private(set) var pendingReminderCount = 0
  private(set) var nextPendingReminder: Date?

  /// Each product fetch is stamped, so an older visit's fetch that finishes
  /// late cannot overwrite a newer visit's result.
  private var productLoadGeneration = 0

  /// Each refresh awaits StoreKit and the notification centre, and several
  /// can be asked for at once: at launch, on a foreground, after a purchase,
  /// and when the tip jar opens. They run one after another, so each caller
  /// returns with the state its own refresh wrote. (A version that let only
  /// the latest write returned early from the others, and the tip jar then
  /// read the state before it was written and never asked for permission.)
  private var refreshQueue: Task<Void, Never>?

  static let oneDrinkID = "com.shawnsemmes.DrinkTracker.tip.onedrink"
  static let monthlyID = "com.shawnsemmes.DrinkTracker.support.monthly"
  static let yearlyID = "com.shawnsemmes.DrinkTracker.support.yearly"

  /// Apple's cap on quantity per transaction. The stepper stops here; a second
  /// purchase is always possible.
  static let maximumDrinksPerPurchase = 10

  private static let allIDs = [oneDrinkID, monthlyID, yearlyID]

  /// The first is the identifier 1.0 to 1.3 used for their one reminder, so
  /// a reminder those builds scheduled is replaced, not left beside the new
  /// ones.
  private static let reminderIdentifiers: [String] = (0..<SupportRenewal.monthlyReminderCount)
    .map { $0 == 0 ? "tallyist-support-renewal-reminder" : "tallyist-support-renewal-reminder-\($0)" }

  /// Started once, by the app at launch, and never returns. The listener is
  /// created first, as Apple asks, so a transaction left unfinished last time
  /// is not missed; the first refresh runs beside it. Each transaction that
  /// arrives outside a purchase (a renewal, an Ask to Buy approval) is
  /// finished and the reminders re-derived. The entitlements are read from the
  /// device, and the renewal info only when a recurring tip is active; on a
  /// simulator with no Apple Account this launch work made no App Store
  /// request (ADR-0012's amendment says what is and is not measured).
  func observeTransactions() async {
    Task { await refreshSupportStatus() }
    for await update in Transaction.updates {
      guard case .verified(let transaction) = update else { continue }
      await transaction.finish()
      await refreshSupportStatus()
    }
  }

  /// The tip jar screen's: the three products' names and prices, from the App
  /// Store, fetched only when that screen is open. The instance lives as long
  /// as the app, so a visit after a failed one shows the spinner again rather
  /// than the last visit's note, and a failed fetch after a good one keeps the
  /// products it already has.
  func loadProducts() async {
    productLoadGeneration += 1
    let generation = productLoadGeneration
    let hadProducts = availability == .ready
    if !hadProducts { availability = .loading }
    do {
      let products = try await Product.products(for: Self.allIDs)
      guard generation == productLoadGeneration else { return }
      oneDrink = products.first { $0.id == Self.oneDrinkID }
      monthlySupport = products.first { $0.id == Self.monthlyID }
      yearlySupport = products.first { $0.id == Self.yearlyID }
      availability = oneDrink == nil && monthlySupport == nil && yearlySupport == nil
        ? .unavailable
        : .ready
    } catch {
      guard generation == productLoadGeneration else { return }
      if !hadProducts { availability = .unavailable }
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
        guard case .verified(let transaction) = verification else { return .unverified }
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

  /// Asks for notification permission once a recurring tip is active on a
  /// device that has never been asked: one where the tip was bought on another
  /// device, or after a reinstall. Called when the tip jar screen opens and
  /// whenever a tip becomes active while it is open, so the question arrives
  /// beside the subscription it is for, never at launch.
  func askForReminderPermissionIfNeeded() async {
    guard supportRenewal?.state == .renews,
          notificationAuthorization == .notDetermined
    else { return }
    _ = try? await UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound])
    await refreshSupportStatus()
  }

  // MARK: - Status

  func refreshSupportStatus() async {
    let previous = refreshQueue
    let refresh = Task {
      await previous?.value
      await readSupportStatus()
    }
    refreshQueue = refresh
    await refresh.value
  }

  private func readSupportStatus() async {
    var latest: Transaction?
    for await entitlement in Transaction.currentEntitlements {
      guard case .verified(let transaction) = entitlement,
            transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID,
            let expiration = transaction.expirationDate
      else { continue }
      if expiration > (latest?.expirationDate ?? .distantPast) {
        latest = transaction
      }
    }

    // Whether it renews is the subscription's renewal info, not the
    // transaction: cancelling leaves the entitlement active to the end of the
    // period. Read only for an active recurring tip; unknown (offline, or
    // unverified) is read as renewing (`SupportRenewal`).
    var willAutoRenew: Bool?
    var renewing: String?
    if let latest,
       let status = await latest.subscriptionStatus,
       case .verified(let renewalInfo) = status.renewalInfo {
      willAutoRenew = renewalInfo.willAutoRenew
      renewing = renewalInfo.autoRenewPreference
    }
    let authorization = await UNUserNotificationCenter.current()
      .notificationSettings().authorizationStatus

    activeSupportID = latest?.productID
    renewingSupportID = renewing
    supportRenewal = SupportRenewal(
      expiration: latest?.expirationDate,
      willAutoRenew: willAutoRenew,
      now: .now
    )
    notificationAuthorization = authorization
    await scheduleRenewalReminders()
  }

  /// One line for Settings → Diagnostics (test builds), so the reminder can be
  /// read on a device: what the jar knows and what the system holds.
  var diagnosticLine: String {
    guard let renewal = supportRenewal else { return "none" }
    let day = { (date: Date) in date.formatted(date: .abbreviated, time: .omitted) }
    let state = renewal.state == .renews ? "renews \(day(renewal.date))" : "ends \(day(renewal.date))"
    var held = "\(pendingReminderCount) reminders pending"
    if let next = nextPendingReminder {
      held += ", next \(next.formatted(date: .abbreviated, time: .shortened))"
    }
    if renewal.state == .renews, renewal.reminderDate == nil {
      held += " (this renewal's is already due)"
    }
    var renews = ""
    if let renewing = renewingSupportID, renewing != activeSupportID {
      renews = " · renews as \(renewing)"
    }
    let notifications = switch notificationAuthorization {
    case .denied: "notifications off"
    case .notDetermined: "notifications not asked"
    case nil: "notifications unknown"
    default: "notifications on"
    }
    return "\(activeSupportID ?? "?") · \(state)\(renews) · \(held) · \(notifications)"
  }

  // MARK: - The cancel reminder

  /// A year of reminders, one a week before each renewal, replaced on every
  /// refresh so they track the entitlement rather than the purchase moment.
  /// All are removed when the recurring tip has been cancelled or has ended.
  /// The one for the renewal whose week has begun is left as it is: it has
  /// fired, or is about to, and removing it in its last minute would lose it.
  private func scheduleRenewalReminders() async {
    let center = UNUserNotificationCenter.current()

    guard let renewal = supportRenewal, renewal.state == .renews,
          let schedule = reminderSchedule
    else {
      center.removePendingNotificationRequests(withIdentifiers: Self.reminderIdentifiers)
      await countPendingReminders()
      return
    }

    let count = schedule.count
    let dates = renewal.reminderDates(
      every: schedule.period, count: count, timeZone: .current, now: .now)
    let stale = Self.reminderIdentifiers.enumerated()
      .filter { index, _ in index >= count || (index > 0 && dates[index] == nil) }
      .map(\.element)
    center.removePendingNotificationRequests(withIdentifiers: stale)

    let content = UNMutableNotificationContent()
    content.title = String(localized: "Recurring tip reminder")
    content.body = String(localized: "Unless it's been cancelled, your recurring tip renews in about a week. You can cancel any time in the App Store, and the app stays the same either way.")
    content.sound = nil

    for (index, fireDate) in dates.enumerated() {
      guard let fireDate else { continue }
      let components = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: fireDate
      )
      let request = UNNotificationRequest(
        identifier: Self.reminderIdentifiers[index],
        content: content,
        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      )
      try? await center.add(request)
    }
    await countPendingReminders()
  }

  /// The period and how many reminders ahead, from the product that renews
  /// next (the other tip after a switch, which takes effect at this renewal),
  /// or the active one when the renewal info is unknown. From the product ID,
  /// so no product has to be fetched to schedule them. The first reminder is
  /// this renewal's either way, since it adds no period to `date`.
  private var reminderSchedule: (period: Calendar.Component, count: Int)? {
    let product = renewingSupportID ?? activeSupportID
    if product == Self.monthlyID {
      return (.month, SupportRenewal.monthlyReminderCount)
    }
    if product == Self.yearlyID {
      return (.year, SupportRenewal.yearlyReminderCount)
    }
    return nil
  }

  private func countPendingReminders() async {
    let ours = await UNUserNotificationCenter.current().pendingNotificationRequests()
      .filter { Self.reminderIdentifiers.contains($0.identifier) }
    pendingReminderCount = ours.count
    nextPendingReminder = ours
      .compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() }
      .min()
  }
}
