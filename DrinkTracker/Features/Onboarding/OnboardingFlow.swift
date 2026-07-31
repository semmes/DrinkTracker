import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Screens 1–3 of the brief, in order, with no account-creation step anywhere.
///
/// The flow runs straight from install to Today; the only system prompt is
/// HealthKit's, and it fires immediately after the explanatory screen.
struct OnboardingFlow: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health

  @State private var step: Step = .welcome

  private enum Step: Hashable {
    case welcome, healthContext, region
  }

  var body: some View {
    ZStack {
      switch step {
      case .welcome:
        WelcomeView { advance(to: .healthContext) }
          .transition(.opacity)
      case .healthContext:
        HealthContextView {
          await health.requestAuthorization()
          advance(to: .region)
        }
        .transition(.opacity)
      case .region:
        RegionView { chosen in
          settings.region = chosen
          settings.hasCompletedOnboarding = true
        }
        .transition(.opacity)
      }
    }
    .animation(.smooth(duration: 0.35), value: step)
  }

  private func advance(to next: Step) {
    step = next
  }
}

// MARK: - Shared layout

/// Common onboarding scaffold: content centred, action pinned to the bottom.
struct OnboardingScaffold<Content: View, Actions: View>: View {
  @ViewBuilder var content: Content
  @ViewBuilder var actions: Actions

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: GlassTokens.Spacing.block)
      VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Spacer(minLength: GlassTokens.Spacing.block)
      VStack(spacing: GlassTokens.Spacing.regular) {
        actions
      }
    }
    .screenMargin()
    .padding(.bottom, GlassTokens.Spacing.section)
  }
}

struct OnboardingHeadline: View {
  let text: String

  var body: some View {
    Text(text)
      .font(GlassTokens.Typography.onboardingHeadline)
      .foregroundStyle(.primary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

struct OnboardingSubtext: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.body)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
