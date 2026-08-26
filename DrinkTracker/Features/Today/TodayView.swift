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
  @Query private var alcoholFreeDays: [AlcoholFreeDay]

  @State private var draft: DrinkDraft?
  @State private var lastLogged: LoggedDrink?
  @State private var isShowingSettings = false
  @State private var deletion = DeletionCoordinator()

  /// The tail of the counter's ± operations. Each new one awaits the previous,
  /// so mutations run strictly in order and each resolves its target from the
  /// store at execution time — two minus taps remove two drinks even when the
  /// first is still mid-write, and a minus queued behind a plus removes the
  /// drink that plus created. Same serialization as the calendar's day sheet
  /// (ADR-0013).
  @State private var counterOps: Task<Void, Never>?

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
            counterHero
            detailedSection
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
      .task {
        // Refresh first: the guards below read the authorization state, and
        // the system's remembered answer can change while the app is away.
        health.refreshAuthorization()
        await backfillHealthKit()
        await store.syncFromHealth()
        await CloudKitStatusProbe.refresh()
      }
      .onChange(of: scenePhase) { _, phase in
        // Anything logged from the widget while the app was away lands without a
        // Health sample; sweep those up on return. Drinks other apps put into
        // Health flow in on the same sweep, and the iCloud check rides along,
        // since the user can sign in while the app is backgrounded and nothing
        // else would notice.
        if phase == .active {
          health.refreshAuthorization()
          Task {
            await backfillHealthKit()
            await store.syncFromHealth()
            await CloudKitStatusProbe.refresh()
          }
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

  // MARK: - The counter

  /// One number, and it is the log itself.
  ///
  /// The first cut of this screen showed two numbers — the day's total on top and
  /// a batch counter below — which asked the user to hold a distinction the design
  /// had invented. Now the counter *is* today: plus logs a drink the moment it is
  /// tapped, minus removes the most recent one through the same path as a
  /// swipe-delete (undo bar included), and the number can never disagree with the
  /// list below because they are the same data.
  ///
  /// Standard drinks demote to a caption. The count is the number people think in;
  /// the region-lensed figure stays one line away for when the two diverge.
  private var counterHero: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      // Upper bound keeps one tap of headroom past the count, so the thirteenth
      // drink of a heavy night is still recordable (12 is a soft floor, not a cap).
      CountStepper(
        value: liveCount,
        range: 0...max(12, todaysEntries.count + 1),
        style: .prominent,
        unitLabel: "Drinks today"
      )

      Text(todaysEntries.count == 1 ? "drink today" : "drinks today")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      // The precise figure, one line down. Reads "≈ 2.6 standard drinks" — or
      // "≈ 4.5 units" under the UK lens, where count and measure diverge most.
      if total > 0 {
        Text("≈ \(StandardDrink.formatted(total)) \(settings.effectiveRegion.unitName(for: total))")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      lastLoggedLine

      if todaysEntries.isEmpty {
        Group {
          if isTodayMarkedAlcoholFree {
            markedTodayState
          } else {
            SUButton(model: .primary("Record no alcohol today")) {
              store.markAlcoholFree(Date())
            }
          }
        }
        .padding(.top, GlassTokens.Spacing.regular)
      }
    }
    .frame(maxWidth: .infinity)
  }

  /// The counter's binding writes straight to the log: an increment saves a
  /// seeded drink, a decrement deletes today's most recent entry. The getter
  /// re-reads the query, so the displayed number is always the stored truth —
  /// there is no separate counter state to fall out of sync.
  private var liveCount: Binding<Int> {
    Binding(
      get: { todaysEntries.count },
      set: { newValue in
        let current = todaysEntries.count
        if newValue > current {
          addOneDrink()
        } else if newValue < current {
          removeMostRecent()
        }
      }
    )
  }

  /// Chains a ± operation behind whatever is already running (see `counterOps`).
  private func enqueueCounterOp(_ op: @escaping @MainActor () async -> Void) {
    let previous = counterOps
    counterOps = Task { @MainActor in
      await previous?.value
      await op()
    }
  }

  /// One drink, logged now, seeded from what is usually logged — the same rule
  /// as the calendar's day sheet (see `DrinkDraft.quickCount`). History is
  /// fetched inside the op, after any pending write has committed; this view
  /// otherwise only queries today.
  private func addOneDrink() {
    let store = store
    let region = settings.effectiveRegion
    enqueueCounterOp {
      let history = ((try? store.repository.context.fetch(FetchDescriptor<DrinkEntry>())) ?? [])
        .loggedDrinks
      let drink = DrinkDraft
        .quickCount(1, from: history)
        .makeLoggedDrink(region: region)
      lastLogged = await store.save(drink)
    }
  }

  /// Removes today's most recent entry through the same path as a swipe-delete,
  /// so the Health sample is retired and the undo bar appears. The victim is
  /// fetched fresh inside the op — after the previous ± has fully committed —
  /// so rapid taps each remove a different drink.
  private func removeMostRecent() {
    let store = store
    let deletion = deletion
    enqueueCounterOp {
      // Most recent entry the app owns: imported Health entries are read-only
      // mirrors of another app's data, so minus skips past them to the newest
      // drink logged here (ADR-0014).
      guard let recent = store.repository.drinks(on: Date())
        .first(where: { !$0.isImportedFromHealth }) else { return }
      await deletion.delete(recent, using: store)
    }
  }

  private var isTodayMarkedAlcoholFree: Bool {
    let today = Calendar.current.startOfDay(for: Date())
    return alcoholFreeDays.contains { $0.day == today }
  }

  /// Factual in both directions: states what was recorded, awards nothing.
  private var markedTodayState: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      Label("Recorded as no alcohol today", systemImage: "checkmark.circle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("Remove that record") {
        store.unmarkAlcoholFree(Date())
      }
      .font(.footnote)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Detailed logging

  /// The typed path, one disclosure down: beer/wine/spirit/other with size and
  /// strength, plus the repeat row. Persisted, so opening it once keeps it open —
  /// a preference for granularity, not a mode to re-enter every day.
  @ViewBuilder
  private var detailedSection: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      Button {
        withAnimation(.snappy) {
          settings.prefersDetailedLogging.toggle()
        }
      } label: {
        HStack(spacing: GlassTokens.Spacing.tight) {
          Text("Log by type — size and strength")
            .font(.footnote)
            .foregroundStyle(.secondary)
          Image(systemName: "chevron.down")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(settings.prefersDetailedLogging ? 180 : 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Log by drink type")
      .accessibilityValue(settings.prefersDetailedLogging ? "shown" : "hidden")

      if settings.prefersDetailedLogging {
        VStack(spacing: GlassTokens.Spacing.tight) {
          quickAddRow
          repeatControl
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
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
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
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

  // MARK: - Supporting figures

  /// Today's total in the current region's units — the caption under the counter.
  private var total: Double {
    todaysEntries.loggedDrinks.reduce(0) {
      $0 + $1.standardDrinks(in: settings.effectiveRegion)
    }
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

// `DrinkDraft`'s `Identifiable` conformance (which `.sheet(item:)` relies on)
// lives in DrinkTrackerCore with the type — a conformance declared here on an
// imported type was retroactive, and Xcode rightly warned about it.
