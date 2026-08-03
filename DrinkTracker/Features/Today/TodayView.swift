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
  @State private var isShowingSettings = false
  @State private var deletion = DeletionCoordinator()

  @Environment(\.scenePhase) private var scenePhase

  init() {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    _todaysEntries = Query(FetchDescriptor<DrinkEntry>.since(startOfDay))
  }

  var body: some View {
    NavigationStack {
      // A List rather than a ScrollView so today's entries get native
      // swipe-to-delete. The metric and quick-add row sit in a chrome-less first
      // section so the screen still reads as the original design.
      List {
        Section {
          VStack(spacing: GlassTokens.Spacing.block) {
            metric
            VStack(spacing: GlassTokens.Spacing.tight) {
              quickAddRow
              repeatControl
            }
          }
          .padding(.top, GlassTokens.Spacing.tight)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
          top: 0,
          leading: GlassTokens.Spacing.screenMargin,
          bottom: GlassTokens.Spacing.section,
          trailing: GlassTokens.Spacing.screenMargin
        ))

        todaysDrinksSection
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .scrollBounceBehavior(.basedOnSize)
      .navigationTitle("Today")
      .safeAreaInset(edge: .bottom) {
        if let drink = deletion.recentlyDeleted {
          UndoDeleteBar(drink: drink) {
            Task { await deletion.undo(using: store) }
          }
          .padding(.bottom, GlassTokens.Spacing.tight)
        }
      }
      .animation(.smooth(duration: 0.25), value: deletion.recentlyDeleted)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            HistoryView()
          } label: {
            Image(systemName: "list.bullet")
          }
          .accessibilityLabel("History")
        }
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            CalendarView()
          } label: {
            Image(systemName: "calendar")
          }
          .accessibilityLabel("Calendar")
        }
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink {
            TrendsView()
          } label: {
            Image(systemName: "chart.bar.xaxis")
          }
          .accessibilityLabel("Trends")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isShowingSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
          .accessibilityLabel("Settings")
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
      .sheet(isPresented: $isShowingSettings) {
        SettingsView()
      }
      .task { await backfillHealthKit() }
      .onChange(of: scenePhase) { _, phase in
        // Anything logged from the widget while the app was away lands without a
        // Health sample; sweep those up on return.
        if phase == .active {
          Task { await backfillHealthKit() }
        }
      }
    }
  }

  private var store: DrinkStore {
    DrinkStore(context: context, health: health)
  }

  private func backfillHealthKit() async {
    await store.backfillHealthKit()
  }

  // MARK: - Repeat

  /// One tap logs another of whatever was logged most recently today.
  ///
  /// The common case for a second drink is the same as the first, and going back
  /// through type → size → confirm to say "the same again" is friction that shows
  /// up as under-logging. Only appears once something has been logged today, so it
  /// never occupies space it hasn't earned.
  @ViewBuilder
  private var repeatControl: some View {
    if let recent = todaysEntries.first?.logged {
      Button {
        repeatDrink(recent)
      } label: {
        HStack(spacing: GlassTokens.Spacing.tight) {
          Image(systemName: "arrow.trianglehead.clockwise")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
          Text("Another \(recent.type.displayName.lowercased())")
            .font(.subheadline)
            .foregroundStyle(.primary)
          Text("\(LoggedDrink.displayOunces(recent.volumeOunces))oz · \(LoggedDrink.displayPercent(recent.abvPercent))%")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(height: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
      .accessibilityLabel("Log another \(recent.type.displayName.lowercased()), same size and strength")
      .transition(.opacity.combined(with: .move(edge: .top)))
      .animation(.smooth(duration: 0.25), value: recent)
    }
  }

  /// Logs an identical drink at the current time — a new entry, not an edit, so the
  /// original stays exactly where it was.
  private func repeatDrink(_ drink: LoggedDrink) {
    let copy = DrinkDraft.repeating(drink).makeLoggedDrink(region: settings.effectiveRegion)
    Task {
      let saved = await store.save(copy)
      lastLogged = saved
    }
  }

  // MARK: - Today's drinks

  /// Today's entries, newest first, each removable and editable in place.
  ///
  /// Logging by accident is a one-tap mistake — from the quick-add row or the
  /// widget — so undoing it should be visible on the same screen rather than
  /// buried in History.
  @ViewBuilder
  private var todaysDrinksSection: some View {
    let drinks = todaysEntries.loggedDrinks
    if !drinks.isEmpty {
      Section {
        ForEach(drinks) { drink in
          DrinkRow(drink: drink, region: settings.effectiveRegion)
            .contentShape(.rect)
            .onTapGesture { draft = DrinkDraft(editing: drink) }
            .swipeActions(edge: .trailing) {
              Button(role: .destructive) {
                Task { await deletion.delete(drink, using: store) }
              } label: {
                Label("Remove", systemImage: "trash")
              }
            }
            .swipeActions(edge: .leading) {
              Button {
                draft = DrinkDraft(editing: drink)
              } label: {
                Label("Edit", systemImage: "pencil")
              }
              .tint(.accentColor)
            }
        }
      } header: {
        Text("Logged today")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Primary metric

  private var total: Double {
    todaysEntries.loggedDrinks.reduce(0) {
      $0 + $1.standardDrinks(in: settings.effectiveRegion)
    }
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
