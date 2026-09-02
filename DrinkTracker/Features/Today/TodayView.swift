import Combine
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

  /// Everything since the start of the day this view was built, newest first;
  /// the trend screens run their own wider query. The lower bound only ever
  /// grows older relative to now, so the window keeps covering today —
  /// `todaysEntries` cuts it down to the current calendar day.
  @Query private var recentEntries: [DrinkEntry]
  @Query private var alcoholFreeDays: [AlcoholFreeDay]

  /// Bumped when the calendar day changes, so `todaysEntries` re-evaluates.
  @State private var dayChanged = Date()

  /// Today's entries, decided by the calendar day *now* rather than the day
  /// the view was built.
  ///
  /// The query's lower bound is fixed at init and nothing rebuilt the view
  /// across midnight, so an app suspended overnight and resumed showed
  /// yesterday's rows as today — while ＋, − and the day template, which read
  /// the clock, already acted on the new day. Filtering the wider query by
  /// the current day, and re-running that on the day-change notification and
  /// on every foregrounding, keeps the number, the list, and the controls on
  /// the same day.
  private var todaysEntries: [DrinkEntry] {
    _ = dayChanged
    return recentEntries.filter { Calendar.current.isDateInToday($0.loggedAt) }
  }

  @State private var draft: DrinkDraft?
  /// The imported entry being given typed details, if any (ADR-0016).
  @State private var adopting: LoggedDrink?
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

  /// The tail of the foreground sweeps, chained the same way (see
  /// `runForegroundSweep`).
  @State private var foregroundSweep: Task<Void, Never>?

  @Environment(\.scenePhase) private var scenePhase

  init() {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    _recentEntries = Query(FetchDescriptor<DrinkEntry>.since(startOfDay))
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
            SessionPaceCard()
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
      .sheet(item: $adopting) { imported in
        // The adopted row updates in place a few points below, so this does not
        // also claim the "last logged" line — adoption fills in a drink that was
        // already in the log, it does not add one.
        DrinkDetailSheet(adopting: imported) { _ in
          adopting = nil
        } onCancel: {
          adopting = nil
        }
      }
      .sheet(isPresented: $isShowingSettings) {
        SettingsView()
      }
      .task {
        runForegroundSweep()
      }
      .onChange(of: scenePhase) { _, phase in
        // Anything logged from the widget while the app was away lands without a
        // Health sample; sweep those up on return. Drinks other apps put into
        // Health flow in on the same sweep, and the iCloud check rides along,
        // since the user can sign in while the app is backgrounded and nothing
        // else would notice.
        if phase == .active {
          dayChanged = Date()
          runForegroundSweep()
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
        dayChanged = Date()
      }
    }
  }

  /// The foreground sweep — authorization refresh, Health backfill, Health
  /// import, iCloud probe — chained so two triggers never run it at once.
  ///
  /// `.task` and the scene-phase change both fire on a cold launch. Unchained,
  /// the second sweep fetched the same sample-less rows while the first was
  /// suspended on the HealthKit save, and every widget- or Siri-logged drink
  /// got two samples in Health, one of them orphaned for good. Same shape as
  /// `counterOps`: each sweep awaits the previous, so a tap that lands
  /// mid-sweep is picked up by the next, and a sweep that finds nothing to do
  /// costs one fetch.
  private func runForegroundSweep() {
    let store = store
    let health = health
    let previous = foregroundSweep
    foregroundSweep = Task { @MainActor in
      await previous?.value
      // Refresh first: the guards below read the authorization state, and
      // the system's remembered answer can change while the app is away.
      health.refreshAuthorization()
      await store.backfillHealthKit()
      await store.syncFromHealth()
      await CloudKitStatusProbe.refresh()
    }
  }

  private var store: DrinkStore {
    DrinkStore(context: context, health: health)
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
        Text(verbatim: StandardDrink.liveEstimate(total, region: settings.effectiveRegion))
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

  /// One drink, logged now, by whichever seed the user chose (ADR-0023, and
  /// its day-memory revision): under the default, a day starts at one
  /// standard drink and the count follows the most recent drink the user
  /// described *today*; under the usual-drink seed, the type they log most.
  /// The same rule as the calendar's day sheet and the widget's ＋ (see
  /// `DrinkDraft.quickCount`).
  ///
  /// History is fetched inside the op, after any pending write has committed —
  /// which is also what makes rapid taps follow a just-described drink; this
  /// view otherwise only queries today.
  private func addOneDrink() {
    let store = store
    let region = settings.effectiveRegion
    let seed = settings.counterSeed
    enqueueCounterOp {
      let history = ((try? store.repository.context.fetch(FetchDescriptor<DrinkEntry>())) ?? [])
        .loggedDrinks
      let drink = DrinkDraft
        .quickCount(1, from: history, seed: seed, region: region)
        .makeLoggedDrink(region: region)
      lastLogged = await store.save(drink)
    }
  }

  /// The way back to plain standard drinks after describing a typed one
  /// (ADR-0023 revision): logs one untyped standard drink now, which both
  /// records this drink and — being the day's newest entry — is what the ＋
  /// repeats from here on. No stored mode to reset; the log is the memory.
  private func recordStandardDrink() {
    let store = store
    let region = settings.effectiveRegion
    enqueueCounterOp {
      let drink = DrinkDraft.standardDrink(region: region).makeLoggedDrink(region: region)
      lastLogged = await store.save(drink)
    }
  }

  /// The drink today's ＋ will repeat, when that is a typed one the user
  /// described — the condition for offering the way back. Nil under the
  /// usual-drink seed (that mode has no day memory) and while the day is
  /// already on standard drinks.
  private var typedDayTemplate: LoggedDrink? {
    guard settings.counterSeed == .standardDrink else { return nil }
    guard let template = DrinkDraft.dayTemplate(
      on: Date(), in: todaysEntries.loggedDrinks, calendar: .current
    ), !template.isTypeUnspecified else { return nil }
    return template
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

  /// Whether another app's Health zero is what marked today (ADR-0025).
  private var isTodayMarkedFromHealth: Bool {
    let today = Calendar.current.startOfDay(for: Date())
    return alcoholFreeDays.contains { $0.day == today && $0.isImportedFromHealth }
  }

  /// Factual in both directions: states what was recorded, awards nothing.
  private var markedTodayState: some View {
    VStack(spacing: GlassTokens.Spacing.tight) {
      Label("Recorded as no alcohol today", systemImage: "checkmark.circle")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      if isTodayMarkedFromHealth {
        // Mirrored from another app, so read-only here — same as the day
        // sheet, same reason as an imported drink (ADR-0014). Logging a
        // drink still clears it.
        Text("From Apple Health")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        Button("Remove that record") {
          store.unmarkAlcoholFree(Date())
        }
        .font(.footnote)
      }
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
          standardDrinkControl
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
  ///
  /// Skips past anything with no size to repeat, the same rule `quickCount` and
  /// `removeMostRecent` follow — an imported Health entry is a count and a time,
  /// so "another one of those" has no answer (ADR-0014, ADR-0022). Without this
  /// the row read "Another other · 0oz · 0%" and one tap wrote exactly that.
  @ViewBuilder
  private var repeatControl: some View {
    if let recent = todaysEntries.lazy.map(\.logged).first(where: { $0.isRepeatable }) {
      Button {
        repeatDrink(recent)
      } label: {
        HStack(spacing: GlassTokens.Spacing.tight) {
          Image(systemName: "arrow.trianglehead.clockwise")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
          // An untyped drink gets its own sentence rather than being fed
          // through the noun slot — "Another one standard drink" is not a
          // phrase — and shows no size or strength, because the 0.6oz/100% it
          // stores is the definition it was logged against (ADR-0023).
          if recent.isTypeUnspecified {
            Text("Another standard drink")
              .font(.subheadline)
              .foregroundStyle(.primary)
          } else {
            Text("Another \(recent.type.displayName.lowercased())")
              .font(.subheadline)
              .foregroundStyle(.primary)
            Text("\(LoggedDrink.displayOunces(recent.volumeOunces))oz · \(LoggedDrink.displayPercent(recent.abvPercent))%")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
      .accessibilityLabel(
        recent.isTypeUnspecified
          ? Text("Log another standard drink")
          : Text("Log another \(recent.type.displayName.lowercased()), same size and strength")
      )
      .transition(.opacity.combined(with: .move(edge: .top)))
      .animation(.smooth(duration: 0.25), value: recent)
    }
  }

  /// The way back to plain standard drinks, shown only while ＋ is following a
  /// described drink (ADR-0023 revision). Lives in the disclosure with the
  /// other type-level controls — the owner's call, keeping the counter area
  /// clear of a tap target beside the last-logged line's Edit. The follow
  /// state itself stays visible above: the last-logged line shows the drink
  /// ＋ will repeat.
  @ViewBuilder
  private var standardDrinkControl: some View {
    if typedDayTemplate != nil {
      Button {
        recordStandardDrink()
      } label: {
        HStack(spacing: GlassTokens.Spacing.tight) {
          Image(systemName: DrinkType.unspecified.symbolName)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
          Text("Record a standard drink instead")
            .font(.subheadline)
            .foregroundStyle(.primary)
          Spacer()
        }
        .padding(.horizontal, GlassTokens.Spacing.cardPadding)
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)
      .transition(.opacity.combined(with: .move(edge: .top)))
    }
  }

  /// Logs an identical drink at the current time — a new entry, not an edit, so the
  /// original stays exactly where it was.
  private func repeatDrink(_ drink: LoggedDrink) {
    let region = settings.effectiveRegion
    let copy = DrinkDraft.repeating(drink, region: region).makeLoggedDrink(region: region)
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
          // Imported Health entries are read-only mirrors, exactly as they are
          // in History (ADR-0014): no edit, because there is no size or strength
          // to correct, and no remove, because the delete path retracts the
          // sample from Health — and that sample belongs to the app that wrote
          // it. Adoption is the one door out (ADR-0016).
          if drink.isImportedFromHealth {
            if drink.isAdoptable {
              DrinkRow(drink: drink, region: settings.effectiveRegion)
                .contentShape(.rect)
                .onTapGesture { adopting = drink }
                .swipeActions(edge: .leading) {
                  Button {
                    adopting = drink
                  } label: {
                    Label("Add details", systemImage: "square.and.pencil")
                  }
                  .tint(.accentColor)
                }
            } else {
              DrinkRow(drink: drink, region: settings.effectiveRegion)
            }
          } else {
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
                  // An untyped drink borrows adoption's vocabulary (ADR-0016):
                  // there is nothing recorded to correct, only facts to add.
                  // Same destination either way — the sheet asks for a type
                  // when the entry has none (ADR-0023).
                  drink.isTypeUnspecified
                    ? Label("Add details", systemImage: "square.and.pencil")
                    : Label("Edit", systemImage: "pencil")
                }
                .tint(.accentColor)
              }
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
        ForEach(DrinkType.selectableCases) { type in
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
