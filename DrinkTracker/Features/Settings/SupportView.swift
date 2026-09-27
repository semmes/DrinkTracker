import ComponentsKit
import DrinkTrackerCore
import StoreKit
import SwiftUI

/// The tip jar, reached from Settings → "Buy me a drink".
///
/// Same register as everything else: the counter is the signature control, the
/// copy is factual, nothing celebrates. Tips unlock nothing and the screen says
/// so before asking for anything — an honest jar, not a paywall (ADR-0012).
struct SupportView: View {
  /// The app's one tip jar, which the app refreshes at launch and on every
  /// foreground so the renewal reminder never waits for this screen
  /// (ADR-0012's amendment of 2026-09-26). This screen adds the products.
  @Environment(TipJar.self) private var tipJar

  @State private var drinkCount = 1
  @State private var isPurchasing = false
  @State private var outcomeMessage: LocalizedStringKey?
  @State private var recurringOutcomeMessage: LocalizedStringKey?
  @State private var recurringOutcomeIsPending = false
  @State private var isManagingSubscription = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
        intro

        switch tipJar.availability {
        case .loading:
          ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, GlassTokens.Spacing.block)
        case .unavailable:
          unavailableNote
          // An active recurring tip keeps its status and its way to cancel
          // when the products could not be loaded.
          if tipJar.supportRenewal != nil {
            recurringSection
          }
        case .ready:
          oneTimeSection
          if showsRecurring {
            recurringSection
          }
          footer
        }
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle("Buy me a drink")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await tipJar.loadProducts()
      await tipJar.refreshSupportStatus()
    }
    // Also when a tip starts renewing while the screen is open (an Ask to Buy
    // approval, a restore, a purchase on another device, or a cancelled tip
    // turned back on in "Manage or cancel"), not only on arrival.
    .task(id: tipJar.supportRenewal?.state == .renews ? tipJar.activeSupportID : nil) {
      await tipJar.askForReminderPermissionIfNeeded()
    }
    .onChange(of: tipJar.activeSupportID) { _, active in
      // A "pending" note has been answered once the tip is active.
      if active != nil, recurringOutcomeIsPending { recurringOutcomeMessage = nil }
    }
    .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
    .onChange(of: isManagingSubscription) { _, isShown in
      // Cancelling in the sheet makes no transaction and may not leave the
      // foreground, so the caption would keep saying "Renews" until the next
      // launch or foreground.
      if !isShown { Task { await tipJar.refreshSupportStatus() } }
    }
  }

  private var intro: some View {
    Text("Tallyist is free, private, and has nothing to sell you. If it earns a place on your home screen, you can buy its maker a drink. Tips unlock nothing — everyone gets the whole app.")
      .font(.body)
      .foregroundStyle(.secondaryInk)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var unavailableNote: some View {
    Text("Tips aren't available right now. The app works exactly the same without them.")
      .font(GlassTokens.Typography.supporting)
      .foregroundStyle(.secondaryInk)
  }

  // MARK: - One-time

  private var oneTimeSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("One-time")

      CountStepper(
        value: $drinkCount,
        range: 1...TipJar.maximumDrinksPerPurchase,
        style: .prominent,
        unitLabel: "Drinks"
      )

      if let product = tipJar.oneDrink {
        Text("\(drinkCount) × \(product.displayPrice) · App Store limit is \(TipJar.maximumDrinksPerPurchase) per purchase")
          .font(.caption)
          .foregroundStyle(.secondaryInk)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)

        SUButton(model: .primary(buyTitle(for: product), isEnabled: !isPurchasing)) {
          Task { await buyDrinks() }
        }
      }

      if let outcomeMessage {
        Text(outcomeMessage)
          .font(GlassTokens.Typography.supporting)
          .foregroundStyle(.secondaryInk)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  // Stays String: ButtonVM.title is a plain String, so this title reaches the
  // catalog only if ComponentsKit's model gains a localized title type.
  private func buyTitle(for product: Product) -> String {
    let total = product.price * Decimal(drinkCount)
    let formatted = total.formatted(product.priceFormatStyle)
    return drinkCount == 1
      ? "Buy 1 drink · \(formatted)"
      : "Buy \(drinkCount) drinks · \(formatted)"
  }

  private func buyDrinks() async {
    isPurchasing = true
    defer { isPurchasing = false }
    switch await tipJar.buyDrinks(count: drinkCount) {
    case .purchased:
      outcomeMessage = drinkCount == 1
        ? "Received — thank you. That keeps Tallyist free."
        : "All \(drinkCount) received — thank you. That keeps Tallyist free."
    case .cancelled:
      outcomeMessage = nil
    case .pending:
      outcomeMessage = "Purchase pending approval — nothing charged yet."
    case .unverified:
      outcomeMessage = "The App Store couldn't confirm that purchase. If you were charged, it shows in your App Store purchase history."
    case .failed:
      outcomeMessage = "That didn't go through. Nothing was charged."
    }
  }

  // MARK: - Recurring

  /// Drawn when there is something to offer or something to report. Otherwise
  /// a build approved without its subscriptions would show a "Recurring"
  /// heading with no rows over a caption promising a reminder for tips that
  /// cannot be bought.
  private var showsRecurring: Bool {
    tipJar.monthlySupport != nil || tipJar.yearlySupport != nil || tipJar.supportRenewal != nil
  }

  private var recurringSection: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      SectionLabel("Recurring")

      VStack(spacing: GlassTokens.Spacing.tight) {
        if let monthly = tipJar.monthlySupport {
          supportRow(monthly, cadence: "month")
        }
        if let yearly = tipJar.yearlySupport {
          supportRow(yearly, cadence: "year")
        }
      }

      if let recurringOutcomeMessage {
        Text(recurringOutcomeMessage)
          .font(GlassTokens.Typography.supporting)
          .foregroundStyle(.secondaryInk)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let renewal = tipJar.supportRenewal {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text(renewalCaption(renewal))
            .font(.caption)
            .foregroundStyle(.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
          Button("Manage or cancel") { isManagingSubscription = true }
            .font(.footnote)
        }
      } else {
        Text(tipJar.notificationAuthorization == .denied
          ? "A week before any renewal, Tallyist sends a reminder so you can cancel before being charged. Notifications are off for Tallyist, so it can't send one. You can turn them on in the Settings app."
          : "A week before any renewal, Tallyist sends a reminder so you can cancel before being charged. That needs notification permission, asked for when you subscribe.")
          .font(.caption)
          .foregroundStyle(.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  /// What the caption says about the active recurring tip. The reminder is
  /// promised only where it will be sent: never for a tip that was cancelled,
  /// not once its week has begun, and not where notifications are off.
  private func renewalCaption(_ renewal: SupportRenewal) -> LocalizedStringKey {
    let date = renewal.date.formatted(date: .abbreviated, time: .omitted)
    switch renewal.state {
    case .ends:
      return "Ends \(date) and won't renew."
    case .renews where renewal.reminderDate == nil:
      return "Renews \(date)."
    case .renews where tipJar.notificationAuthorization == .denied:
      return "Renews \(date). Notifications are off for Tallyist, so it can't remind you a week before. You can turn them on in the Settings app."
    case .renews:
      return "Renews \(date). Tallyist will remind you a week before, so cancelling first is always realistic."
    }
  }

  private func subscribe(to product: Product) async {
    isPurchasing = true
    defer { isPurchasing = false }
    let wasActive = tipJar.activeSupportID
    let outcome = await tipJar.subscribe(to: product)
    recurringOutcomeIsPending = outcome == .pending
    switch outcome {
    case .purchased:
      if let wasActive, wasActive != product.id, tipJar.activeSupportID != product.id,
         let renewal = tipJar.supportRenewal {
        // Moving between the monthly and yearly tip, which share a level, takes
        // effect at the next renewal, so nothing is received today.
        recurringOutcomeMessage = "Switches to \(product.displayName) on \(renewal.date.formatted(date: .abbreviated, time: .omitted)). Nothing is charged until then."
      } else {
        recurringOutcomeMessage = "Received — thank you. That keeps Tallyist free."
      }
    case .cancelled:
      recurringOutcomeMessage = nil
    case .pending:
      recurringOutcomeMessage = "Purchase pending approval — nothing charged yet."
    case .unverified:
      recurringOutcomeMessage = "The App Store couldn't confirm that purchase. If you were charged, it shows in your App Store purchase history."
    case .failed:
      recurringOutcomeMessage = "That didn't go through. Nothing was charged."
    }
  }

  private func supportRow(_ product: Product, cadence: String) -> some View {
    let isActive = tipJar.activeSupportID == product.id
    return Button {
      guard !isActive else {
        isManagingSubscription = true
        return
      }
      Task { await subscribe(to: product) }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(product.displayName)
            .font(.body)
            .foregroundStyle(.primary)
          Text("\(product.displayPrice) per \(cadence) · cancel any time")
            .font(.caption)
            .foregroundStyle(.secondaryInk)
        }
        Spacer()
        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isActive ? Color.accentColor : Color.secondaryInk)
      }
      .padding(.horizontal, GlassTokens.Spacing.cardPadding)
      .frame(minHeight: 60)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(isPurchasing)
    .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      Button("Restore purchases") {
        Task { await tipJar.restorePurchases() }
      }
      .font(.footnote)

      Text("Payments are processed by Apple through your App Store account. Tallyist never sees your payment details, and tips appear nowhere in your drink log.")
        .font(.caption)
        .foregroundStyle(.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)

      // Guideline 3.1.2(c) and Apple's subscriptions page: an app that sells
      // auto-renewing subscriptions must link both documents, and next to the
      // subscription UI is where a reviewer looks first.
      HStack(spacing: GlassTokens.Spacing.regular) {
        NavigationLink("Privacy Policy") { PrivacyPolicyView() }
        Link("Terms of Use", destination: SupportView.termsOfUseURL)
      }
      .font(.footnote)
    }
  }

  /// Apple's standard EULA — the terms that govern App Store purchases for apps
  /// that don't ship a custom agreement. Also linked from Settings → About and
  /// the App Store listing metadata.
  static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

#Preview {
  NavigationStack { SupportView() }
    .environment(TipJar())
}
