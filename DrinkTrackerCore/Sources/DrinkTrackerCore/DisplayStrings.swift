import Foundation

/// Localized lookup for the display names this package owns (ADR-0020).
///
/// The domain layer names a few things the user reads — drink types, regions,
/// what one standard drink is called — because those names belong to the
/// concepts, not to any one screen. They are consumed by the app, the widget,
/// the CSV export, and the phrases Siri speaks, so moving them to the app
/// layer would leave `LogExport` unable to name a drink at all.
///
/// Resolution goes through `Bundle.module`, which exists because the package
/// already ships the population-reference JSON. A missing translation falls
/// back to the English source string, so the domain tests keep asserting
/// exact English on macOS CI without any locale setup.
///
/// This is not a UI dependency: no SwiftUI, no view types, nothing that fails
/// to compile outside Xcode. Invariant 9 holds.
func localized(_ key: String.LocalizationValue, comment: StaticString) -> String {
  String(localized: key, bundle: .module, comment: comment)
}
