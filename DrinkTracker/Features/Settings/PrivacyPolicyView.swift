import SwiftUI

/// The privacy policy, shipped inside the app.
///
/// Guideline 5.1.1 wants the policy both in App Store Connect and "easily
/// accessible" in the app; a HealthKit app gets held to that strictly. Shipping
/// the text natively (rather than a web view of the hosted copy) means it is
/// readable offline, respects Dynamic Type, and can't differ from what was
/// reviewed. The canonical copy lives at `docs/privacy-policy.md` in this repo;
/// it is published at the URL below, from the separate public `semmes/Tallyist`
/// repository, which is what App Store Connect points to (ADR-0024). All three
/// copies change together (the doc says so too).
struct PrivacyPolicyView: View {

  /// The hosted copy of this same text — the URL given to App Store Connect.
  static let hostedURL = URL(string: "https://semmes.github.io/Tallyist/privacy/")!

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.section) {
        Text("Tallyist does not collect your data. Nothing you log leaves your control.")
          .font(.body.weight(.medium))
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)

        policySection(
          "What Tallyist stores",
          """
          The drinks you log — type, size, strength, and when. Days you record as \
          alcohol-free. Your settings, such as which region's standard-drink \
          definition your totals use.

          All of it is stored on your device, in the app's own database. There are \
          no accounts and no sign-up.
          """
        )

        // Shorter than the doc's heading: SectionLabel sets uppercase, and a
        // clause-length title in caps reads like shouting.
        policySection(
          "Where your data can go",
          """
          iCloud: if your device is signed into iCloud, your log syncs through your \
          own private iCloud database so it follows you across your devices. That \
          database belongs to your Apple Account; the developer cannot read it, and \
          no server other than Apple's is involved.

          Apple Health: with your permission, drinks you log are saved to Health as \
          alcoholic beverages, and Tallyist reads that same category back — \
          including drinks that other apps recorded there, which then appear in \
          your Tallyist log, clearly labeled. You can grant, refuse, or revoke \
          this at any time in the Health app under Sharing. Tallyist reads no \
          other Health data.

          The widget: the home-screen widget shares the app's on-device storage. \
          Nothing about that leaves the device.

          Export and sharing: Settings → Export log turns your whole record \
          into a CSV file, and the calendar can render a month as an image. \
          Both are created on your device, only when you ask, and go only \
          where you send them through the system share sheet. The app keeps \
          no copy, adds no identifier, and does not record whether or where \
          you shared anything.
          """
        )

        policySection(
          "What Tallyist does not do",
          """
          No analytics or crash-reporting SDKs. No advertising, and no tracking of \
          any kind. No third-party services — the app contains no networking code \
          of its own; the only network traffic is Apple's iCloud sync described \
          above and, if you choose to leave a tip, Apple's own App Store purchase \
          processing. No selling, sharing, or transfer of your data to anyone, \
          because the developer never has it in the first place.

          In App Store terms: Data Not Collected.
          """
        )

        policySection(
          "Tips",
          """
          The optional tip jar is processed entirely by Apple through your App \
          Store account, exactly like any App Store purchase: Tallyist never sees \
          your payment details, and Apple tells the app only that a purchase \
          completed. Tips unlock nothing, and nothing about tipping — or not — \
          appears in or affects your drink log. Recurring tips can be cancelled \
          any time in your App Store subscription settings, and the app offers a \
          local reminder a week before each renewal so you can cancel before \
          being charged.
          """
        )

        policySection(
          "Deleting your data",
          """
          Any entry can be deleted in the app, individually. Deleting the app \
          removes everything stored on the device. iCloud copies can be removed in \
          the iOS Settings app under your Apple Account → iCloud → Manage Account \
          Storage. Data saved to Health is yours in Health: delete it there under \
          Browse → Other Data → Alcohol Consumption.
          """
        )

        policySection(
          "Changes to this policy",
          """
          This policy is published in a public repository at \
          github.com/semmes/Tallyist; every change to it, and its date, is \
          visible in that repository's history. If a future version of the app \
          ever collects data, this policy and the App Store privacy labels will \
          change before that version ships.
          """
        )

        VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
          Link("Read this policy online", destination: Self.hostedURL)
            .font(.body)
          Text("Last updated August 31, 2026.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .screenMargin()
      .padding(.vertical, GlassTokens.Spacing.section)
    }
    .navigationTitle("Privacy Policy")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func policySection(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.tight) {
      SectionLabel(title)
      Text(text)
        .font(GlassTokens.Typography.supporting)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
