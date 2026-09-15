import SwiftUI

/// The one state where nothing is being saved: the store could not be opened
/// at all and the app is running on memory (ADR-0004). On the phone this is
/// the one line house voice permits an exclamation mark, in Settings; the
/// watch has no Settings screen to bury it on, and a wrist that silently
/// discards every log is the worst outcome available, so it sits on the
/// counter itself, in `SettingsView`'s own words. A symbol plus words — colour
/// carries nothing alone.
struct StorageWarningStrip: View {
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 14, weight: .semibold))
      Text("Not saving — storage unavailable")
        .font(.system(size: WatchLayout.hintSize))
        .multilineTextAlignment(.leading)
    }
    .foregroundStyle(.primary)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: WatchLayout.stripRadius, style: .continuous)
        .fill(Color.primary.opacity(0.10))
    )
    .accessibilityElement(children: .combine)
  }
}
