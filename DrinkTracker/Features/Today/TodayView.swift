import Combine
import ComponentsKit
import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Screen 4 — Today. Home surface and the entry point for every log.
///
/// One tap of ＋ logs a drink. Everything else on the screen exists to say what
/// that tap just did: the band behind the number is the day's own amount on the
/// calendar's scale, the pill says which drink ＋ is following, and the list
/// below is the same data the number counts (ADR-0034).
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
  /// The entry this session's last save produced — set on every save, never
  /// cleared. Read through `currentLastLogged`, which is what decides whether
  /// the screen still shows it.
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
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  init() {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    _recentEntries = Query(FetchDescriptor<DrinkEntry>.since(startOfDay))
  }

  var body: some View {
    NavigationStack {
      // A List rather than a ScrollView so today's entries get native
      // swipe-to-delete. The counter sits in a chrome-less first section so the
      // screen still reads as one surface rather than a form.
      List {
        Section {
          VStack(spacing: GlassTokens.Spacing.block) {
            counterHero
            SessionPaceCard()
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
        style: .hero,
        unitLabel: "Drinks today",
        band: todayIntensity
      )

      Text(todaysEntries.count == 1 ? "drink today" : "drinks today")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      // The precise figure, one line down. Reads "≈ 2.6 standard drinks" — or
      // "≈ 4.5 units" under the UK lens, where count and measure diverge most.
      //
      // It also names the quantity the band above is keyed to, which is what
      // makes the colour checkable rather than atmospheric (ADR-0034).
      if total > 0 {
        Text(verbatim: StandardDrink.liveEstimate(total, region: settings.effectiveRegion))
          .font(.footnote)
          .foregroundStyle(.secondary)
          // Its own element in this stack, so the label is what VoiceOver
          // speaks — "Approximately 2.6 standard drinks" rather than the "≈"
          // symbol, which has no reading. Composed verbatim because the
          // package already translated it (same as `DrinkDetailSheet`).
          .accessibilityLabel(
            Text(verbatim: StandardDrink.accessibleEstimate(total, region: settings.effectiveRegion))
          )
      }

      HeroBandLegend(active: todayIntensity)
        .padding(.top, 2)

      if let template = typedDayTemplate {
        PlusModePill(
          template: template,
          seed: counterSeed,
          onRecordStandardDrink: recordStandardDrink,
          onRepeatTemplate: { repeatDrink(template) }
        )
        .padding(.top, GlassTokens.Spacing.tight)
      }

      lastLoggedLine

      if todaysEntries.isEmpty {
        VStack(spacing: GlassTokens.Spacing.tight) {
          if isTodayMarkedAlcoholFree {
            markedTodayState
          } else {
            SUButton(model: .primary("Record no alcohol today")) {
              store.markAlcoholFree(Date())
            }
            // The drawing's "Or tap + — one tap is one standard drink." is
            // true only under the standard-drink seed; this is the same point
            // in a sentence that stays true under both (ADR-0034).
            Group {
              if settings.counterSeed == .standardDrink {
                CounterSeedCaption(seed: counterSeed)
              } else {
                UsualDrinkSeedCaption()
              }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
          }

          // The typed path has to exist on an empty day too — it is the day
          // with the least to go on. The Logged-today heading that normally
          // carries it does not render until there is a row.
          addSpecificButton
        }
        .padding(.top, GlassTokens.Spacing.regular)
      }
    }
    .frame(maxWidth: .infinity)
  }

  /// Today's own band — the same fold and the same palette as the calendar
  /// cell for this day, so the two can never disagree about one day (ADR-0034).
  ///
  /// `total` is already region-lensed, so a UK reader's tile re-expresses along
  /// with every other figure (invariant 3).
  private var todayIntensity: DayIntensity {
    DayIntensity.bucket(
      standardDrinks: total,
      isMarkedAlcoholFree: isTodayMarkedAlcoholFree,
      hasEntries: !todaysEntries.isEmpty
    )
  }

  /// The drink ＋ would log right now, under the standard-drink seed. Built by
  /// the write path's own function, so a caption describing it cannot drift
  /// from what the button does.
  ///
  /// Today's entries are the whole input, and that is exact rather than a
  /// shortcut: `quickCount`'s standard-drink branch reads only `dayTemplate`,
  /// which filters to the day. The usual-drink seed *does* need the whole log,
  /// and it gets it in `UsualDrinkSeedCaption`, which owns that fetch — so the
  /// default configuration never runs an unbounded query for a caption.
  private var counterSeed: LoggedDrink {
    DrinkDraft.countSeedPreview(
      from: todaysEntries.loggedDrinks,
      seed: .standardDrink,
      region: settings.effectiveRegion
    )
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

  // MARK: - Repeat

  /// Logs an identical drink at the current time — a new entry, not an edit, so the
  /// original stays exactly where it was.
  private func repeatDrink(_ drink: LoggedDrink) {
    let store = store
    let region = settings.effectiveRegion
    let copy = DrinkDraft.repeating(drink, region: region).makeLoggedDrink(region: region)
    // Enqueued like every other ± now that this is the pill's right segment,
    // a thumb's width from −. `DrinkStore.save` awaits the HealthKit write
    // *before* the row reaches the store, so an unchained repeat left a window
    // in which − fetched the log, could not see the new drink, and deleted the
    // previous one instead — right count, wrong entry, and a retired Health
    // sample the user never asked to remove. `copy.loggedAt` is fixed at tap
    // time, so waiting its turn does not move the drink.
    enqueueCounterOp {
      lastLogged = await store.save(copy)
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
    // Newest first, like History and the day sheet. The drink you just logged
    // is the one you look for, the one − takes back, and the one most likely to
    // need correcting — so it belongs where the eye lands, not at the end of a
    // list that grows all evening (ADR-0013's amendment, reverted on the
    // owner's review).
    //
    // `recentEntries` is already reverse-sorted by the query descriptor, and
    // `todaysEntries` only filters it, so this is stating the order rather than
    // establishing it — kept explicit so the screen does not silently change
    // direction if that descriptor ever does.
    let drinks = todaysEntries.loggedDrinks.sorted { $0.loggedAt > $1.loggedAt }
    if !drinks.isEmpty {
      Section {
        // Deliberately a row rather than a `header:`. A plain list pins its
        // headers and draws them on nothing, so at accessibility sizes the
        // first row scrolled underneath "Add specific" and the two overlapped.
        // The heading has nothing to gain from following the scroll — it
        // labels a list that is a handful of rows long.
        listHeader
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)

        ForEach(drinks) { drink in
          // Imported Health entries are read-only mirrors, exactly as they are
          // in History (ADR-0014): no edit, because there is no size or strength
          // to correct, and no remove, because the delete path retracts the
          // sample from Health — and that sample belongs to the app that wrote
          // it. Adoption is the one door out (ADR-0016).
          if drink.isImportedFromHealth {
            if drink.isAdoptable {
              row(drink)
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
              // No tap, no chevron, no swipe: Remove would reach
              // `health.deleteSample` on another app's UUID.
              row(drink, isTappable: false)
            }
          } else {
            row(drink)
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

        // Under the rows rather than over them: it describes what tapping one
        // does, and a hint above a list is read before there is anything to
        // apply it to.
        //
        // The condition is `isTypeUnspecified`, not the broader
        // `!recordsSizeAndStrength` — that one is also false for a Health
        // import, and an import is not a drink whose type the reader declined
        // to give. Promising "left alone it counts as one standard drink"
        // over a day of imported rows would describe a choice nobody made,
        // and a multi-count import cannot be tapped at all.
        //
        // And only while there is a row a tap can reach. A day whose only
        // rows are multi-count imports renders them read-only (`isTappable:
        // false` above), and "Tap a drink to change what it was" over those
        // answers no tap. The prototype's ternary chose between the two
        // sentences and never considered the third case (ADR-0034's
        // deviation list).
        if drinks.contains(where: { !$0.isImportedFromHealth || $0.isAdoptable }) {
          Text(drinks.contains(where: \.isTypeUnspecified)
            ? "Tap a drink to say what it was — left alone it counts as one standard drink."
            : "Tap a drink to change what it was.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
      }
    }
  }

  /// "Logged today" and the way into the typed path.
  @ViewBuilder
  private var listHeader: some View {
    let stack = dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: GlassTokens.Spacing.tight))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline))

    stack {
      Text("Logged today")
        .font(.caption)
        .foregroundStyle(.secondary)
        // Explicit, because this is a row rather than a `header:` — see the
        // note where it is placed. A plain `Text` in a list carries no header
        // trait, so rotor navigation would lose the only landmark on Today.
        .accessibilityAddTraits(.isHeader)

      if !dynamicTypeSize.isAccessibilitySize { Spacer() }

      // The typed path, now one always-available link rather than a persisted
      // disclosure holding four buttons (ADR-0009's own reopen clause). The
      // sheet opens on an untyped standard drink, so it asks "what was it?"
      // first and only then offers size and strength — and with no time
      // control, because this is a new entry, not a retroactive one
      // (invariant 2).
      addSpecificButton
    }
  }

  /// The way into the typed path, rendered in the Logged-today heading and —
  /// on an empty day, which has no heading — under the counter.
  ///
  /// The 44pt floor and the hit shape are inside the label, not on the Button:
  /// a `Button`'s tap gesture is attached to its label, so a frame applied
  /// outside it grows the layout without growing the target. Same shape as
  /// `SizePill` and the Settings rows.
  private var addSpecificButton: some View {
    Button {
      draft = DrinkDraft.standardDrink(region: settings.effectiveRegion)
    } label: {
      Text("Add specific")
        .font(.footnote.weight(.medium))
        .frame(minHeight: GlassTokens.Layout.minimumTouchTarget)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.accentColor)
  }

  /// One row, with the entry this session just logged marked.
  ///
  /// `lastLogged`, not "whatever − would remove": the tint answers "where did
  /// the thing I just tapped go", which is why it is `@State` that a relaunch
  /// clears rather than something derived from the log. On a newest-first list
  /// the two are usually the same row anyway — the top one.
  private func row(_ drink: LoggedDrink, isTappable: Bool = true) -> some View {
    TodayDrinkRow(
      drink: drink,
      region: settings.effectiveRegion,
      isTappable: isTappable,
      isMostRecent: drink.id == currentLastLogged?.id
    )
  }

  // MARK: - Supporting figures

  /// Today's total in the current region's units — the caption under the counter.
  private var total: Double {
    todaysEntries.loggedDrinks.reduce(0) {
      $0 + $1.standardDrinks(in: settings.effectiveRegion)
    }
  }

  /// `lastLogged` while its row is still on today's list; nil otherwise.
  ///
  /// The state is set on every save and never cleared, and both readers — the
  /// line under the counter and the row tint — go through this rather than
  /// the raw state. Cleared state would be the wrong fix: the tint answers
  /// "where did my tap land" (see `row`), so the line must not be derived
  /// from `todaysEntries.first` — a widget or Health row is not something
  /// this session logged — but a line naming a drink that is no longer in
  /// the log is a claim about nothing, and its Edit re-inserted the removed
  /// entry through `DrinkStore.save`'s insert-on-missing-id path. Reading
  /// presence off the query also gives the right answer without new state
  /// in every case that used to be wrong: − or swipe-Remove hides the line,
  /// Undo brings it back, and midnight clears it with the rest of the day.
  private var currentLastLogged: LoggedDrink? {
    guard let lastLogged,
          todaysEntries.contains(where: { $0.entryID == lastLogged.id }) else { return nil }
    return lastLogged
  }

  /// The "last logged" line only appears once something has been logged this
  /// session, and carries the Edit affordance for the edit-after pattern.
  @ViewBuilder
  private var lastLoggedLine: some View {
    if let current = currentLastLogged {
      HStack(spacing: GlassTokens.Spacing.tight) {
        Text(current.summaryLine)
          .font(.footnote)
          .foregroundStyle(.secondary)
        Button("Edit") {
          draft = DrinkDraft(editing: current)
        }
        .font(.footnote.weight(.medium))
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
      }
      .padding(.top, GlassTokens.Spacing.tight)
      .transition(.opacity.combined(with: .move(edge: .top)))
      .animation(.smooth, value: current)
    }
  }

}

// `DrinkDraft`'s `Identifiable` conformance (which `.sheet(item:)` relies on)
// lives in DrinkTrackerCore with the type — a conformance declared here on an
// imported type was retroactive, and Xcode rightly warned about it.
