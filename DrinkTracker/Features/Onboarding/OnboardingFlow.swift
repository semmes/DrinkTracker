import ComponentsKit
import DrinkTrackerCore
import SwiftUI

/// Three steps, no account-creation anywhere: welcome, privacy, region.
///
/// The flow runs straight from install to Today; the only system prompt is
/// HealthKit's, and it fires immediately after the privacy screen that explains
/// it. Copy and motion follow the Tallyist prototype handoff — personality in
/// the words, restraint in the movement, and every decorative animation gated
/// behind Reduce Motion.
struct OnboardingFlow: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var step: Step = .welcome

  private enum Step: Int, Hashable {
    case welcome, privacy, region
  }

  var body: some View {
    VStack(spacing: 0) {
      OnboardingProgressDots(current: step.rawValue)
        .padding(.top, GlassTokens.Spacing.section)

      ZStack {
        switch step {
        case .welcome:
          WelcomeView { advance(to: .privacy) }
            .transition(stepTransition)
        case .privacy:
          PrivacyView {
            await health.requestAuthorization()
            advance(to: .region)
          }
          .transition(stepTransition)
        case .region:
          RegionView { chosen in
            settings.region = chosen
            settings.hasCompletedOnboarding = true
          }
          .transition(stepTransition)
        }
      }
      .animation(
        reduceMotion ? .smooth(duration: 0.25) : .easeOut(duration: 0.5),
        value: step
      )
    }
  }

  /// Content fades in and rises ~16pt on step change; with Reduce Motion the
  /// rise is dropped and only the crossfade remains.
  private var stepTransition: AnyTransition {
    reduceMotion
      ? .opacity
      : .asymmetric(
          insertion: .opacity.combined(with: .offset(y: 16)),
          removal: .opacity
        )
  }

  private func advance(to next: Step) {
    step = next
  }
}

// MARK: - Progress dots

/// Three dots above the content; the active step stretches into a short accent
/// capsule. Purely positional — it never celebrates progress, it states it.
struct OnboardingProgressDots: View {
  let current: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<3, id: \.self) { index in
        Capsule()
          .fill(index == current ? Color.accentColor : Color.secondary.opacity(0.35))
          .frame(width: index == current ? 24 : 8, height: 8)
      }
    }
    .animation(.smooth(duration: 0.3), value: current)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(current + 1) of 3")
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
