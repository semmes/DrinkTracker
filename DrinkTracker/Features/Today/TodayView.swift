import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Screen 4 — Today. Home surface and the entry point for every log.
///
/// Tapping a quick-add button opens the drink-detail sheet already seeded with
/// that type's defaults, so the common case is two taps: type, then Log.
struct TodayView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.modelContext) private var context

  /// Scoped to today only; the trend screens run their own wider query.
  @Query private var todaysEntries: [DrinkEntry]

  @State private var draft: DrinkDraft?
  @State private var lastLogged: LoggedDrink?

  init() {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    _todaysEntries = Query(FetchDescriptor<DrinkEntry>.since(startOfDay))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: GlassTokens.Spacing.block) {
          metric
          quickAddRow
        }
        .screenMargin()
        .padding(.top, GlassTokens.Spacing.section)
      }
      .scrollBounceBehavior(.basedOnSize)
      .navigationTitle("Today")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            TrendsView()
          } label: {
            Image(systemName: "chart.bar.xaxis")
          }
          .accessibilityLabel("Trends")
        }
      }
      .sheet(item: $draft) { current in
        DrinkDetailSheet(draft: current) { saved in
          lastLogged = saved
          draft = nil
        } onCancel: {
          draft = nil
        }
      }
    }
  }

  // MARK: - Primary metric

  private var total: Double {
    todaysEntries.loggedDrinks.reduce(0) { $0 + $1.standardDrinks }
  }

  private var metric: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      Text(StandardDrink.formatted(total))
        .font(GlassTokens.Typography.metric)
        .foregroundStyle(.primary)
        .contentTransition(.numericText(value: total))
        .animation(.snappy, value: total)
        .accessibilityHidden(true)

      Text(unitLabel)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      lastLoggedLine
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(StandardDrink.formatted(total)) \(unitLabel)")
  }

  private var unitLabel: String {
    let region = settings.effectiveRegion
    let noun = total == 1 ? region.unitName : region.unitName + "s"
    return "\(noun) today"
  }

  /// The "last logged" line only appears once something has been logged this
  /// session, and carries the Edit affordance for the edit-after pattern.
  @ViewBuilder
  private var lastLoggedLine: some View {
    if let lastLogged {
      HStack(spacing: GlassTokens.Spacing.tight) {
        Text(lastLogged.summaryLine)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Button("Edit") {
          draft = DrinkDraft(editing: lastLogged)
        }
        .font(.footnote.weight(.medium))
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
      }
      .padding(.top, GlassTokens.Spacing.tight)
      .transition(.opacity.combined(with: .move(edge: .top)))
      .animation(.smooth, value: lastLogged)
    }
  }

  // MARK: - Quick add

  private var quickAddRow: some View {
    GlassEffectContainer(spacing: GlassTokens.Spacing.tight) {
      HStack(spacing: GlassTokens.Spacing.tight) {
        ForEach(DrinkType.allCases) { type in
          QuickAddButton(type: type) {
            draft = DrinkDraft(type: type)
          }
        }
      }
    }
  }
}

/// One of the four quick-add buttons. Tapping opens the sheet; it does not log
/// directly, because the sheet is where the live standard-drink figure lives.
private struct QuickAddButton: View {
  let type: DrinkType
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: GlassTokens.Spacing.tight) {
        Image(systemName: type.symbolName)
          .font(.title2)
          .foregroundStyle(Color.accentColor)
        Text(type.displayName)
          .font(.caption)
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: GlassTokens.Layout.quickAddHeight)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
    .accessibilityLabel("Log \(type.displayName.lowercased())")
  }
}

// MARK: - Sheet presentation

/// `DrinkDraft` drives `.sheet(item:)`, so it needs a stable identity while the
/// sheet is open. The identity is the type plus the entry being edited, which
/// is what actually distinguishes one sheet presentation from another.
extension DrinkDraft: Identifiable {
  public var id: String {
    "\(type.rawValue)-\(editingEntryID?.uuidString ?? "new")"
  }
}
