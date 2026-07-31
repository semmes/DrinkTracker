import ComponentsKit
import SwiftUI

/// Screen 1 — Welcome. Copy is verbatim from the brief.
struct WelcomeView: View {
  var onContinue: () -> Void

  var body: some View {
    OnboardingScaffold {
      OnboardingHeadline(text: "Know your pattern, at your pace")
      OnboardingSubtext(
        text: "See how much you're actually drinking, day to day and week to week. No lectures, just your own picture."
      )
    } actions: {
      SUButton(model: .primary("Get started"), action: onContinue)
    }
  }
}

#Preview {
  WelcomeView {}
}
