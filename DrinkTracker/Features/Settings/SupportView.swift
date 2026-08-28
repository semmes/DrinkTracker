import ComponentsKit
import StoreKit
import SwiftUI

/// The tip jar, reached from Settings → "Buy me a drink".
///
/// Same register as everything else: the counter is the signature control, the
/// copy is factual, nothing celebrates. Tips unlock nothing and the screen says
/// so before asking for anything — an honest jar, not a paywall (ADR-0012).
struct SupportView: View {
  @State private var tipJar = TipJar()

  @State private var drinkCount = 1
  @State private var isPurchasing = false
  @State private var outcomeMessage: LocalizedStringKey?
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
        case .ready:
          oneTimeSection
          recurringSection
          footer
        }
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle("Buy me a drink")
    .navigationBarTitleDisplayMode(.inline)
    .task { await tipJar.start() }
    .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
  }

  private var intro: some View {
    Text("Tallyist is free, private, and has nothing to sell you. If it earns a place on your home screen, you can buy its maker a drink. Tips unlock nothing — everyone gets the whole app.")
      .font(.body)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var unavailableNote: some View {
    Text("Tips aren't available right now. The app works exactly the same without them.")
      .font(GlassTokens.Typography.supporting)
      .foregroundStyle(.secondary)
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
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)

        SUButton(model: .primary(buyTitle(for: product), isEnabled: !isPurchasing)) {
          Task { await buyDrinks() }
        }
      }

      if let outcomeMessage {
        Text(outcomeMessage)
          .font(GlassTokens.Typography.supporting)
          .foregroundStyle(.secondary)
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
    case .failed:
      outcomeMessage = "That didn't go through. Nothing was charged."
    }
  }

  // MARK: - Recurring

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

      if let renewal = tipJar.supportRenewalDate {
        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Text("Renews \(renewal.formatted(date: .abbreviated, time: .omitted)). Tallyist will remind you a week before, so cancelling first is always realistic.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          Button("Manage or cancel") { isManagingSubscription = true }
            .font(.footnote)
        }
      } else {
        Text("A week before any renewal, Tallyist sends a reminder so you can cancel before being charged. That needs notification permission, asked for when you subscribe.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private func supportRow(_ product: Product, cadence: String) -> some View {
    let isActive = tipJar.activeSupportID == product.id
    return Button {
      guard !isActive else {
        isManagingSubscription = true
        return
      }
      Task {
        isPurchasing = true
        defer { isPurchasing = false }
        _ = await tipJar.subscribe(to: product)
      }
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(product.displayName)
            .font(.body)
            .foregroundStyle(.primary)
          Text("\(product.displayPrice) per \(cadence) · cancel any time")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
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
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      // Guideline 3.1.2(a): auto-renewing subscriptions must expose functional
      // links to both documents, and next to the subscription UI is where a
      // reviewer looks first.
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
}
