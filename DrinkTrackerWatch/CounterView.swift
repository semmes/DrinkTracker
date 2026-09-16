import DrinkTrackerCore
import SwiftData
import SwiftUI
import WidgetKit

/// The counter — the watch's home surface and the only screen that writes
/// (watch Phase 3; `docs/design/watch/README.md`; ADR-0042, 0043, 0045).
///
/// Today's counter reduced to what a wrist can carry: the count in the day's
/// own band, ＋ as the primary control, − as the secondary, the unit word, the
/// region's figure, and the four bands named. No header, no navigation, no
/// summary: everything else the watch could show is a reason to keep looking
/// at it, and the target is a log in under two seconds from raise to lower.
///
/// Every write goes through the same rules as the phone's — ＋ through
/// `DrinkRepository.logOneDrink`, the one implementation of the counter's seed
/// rule (ADR-0023) that Today's ＋ and the widget's ＋ also call (PRD invariant
/// 1); − through `LoggedDrink.removableNewest`, pinned at tier 1 (ADR-0043);
/// the no-alcohol record through `markAlcoholFreeOrThrow`, exactly as Siri's
/// intent does. Each operation acts on the store at execution time, chained
/// behind the previous one, never on a captured snapshot: a fast − behind a
/// ＋ removes the drink that ＋ just made, and two fast ＋ taps log two drinks
/// (`TodayView`'s `counterOps` discipline; the race is likelier on a watch
/// because a tap is easier to repeat).
struct CounterView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Everything since the start of the day *before* the one the view was
  /// built on; the lower bound only ever grows older relative to now, so the
  /// window keeps covering today and `todaysEntries` cuts it to the current
  /// calendar day — the shape `TodayView` arrived at after a night suspended
  /// showed yesterday as today. The extra day is for the session (Phase 5):
  /// a sitting can start before midnight, and one that reaches back past
  /// yesterday's start would be longer than a day of drinks under four hours
  /// apart, which the row is content to cut.
  @Query private var recentEntries: [DrinkEntry]
  @Query private var alcoholFreeDays: [AlcoholFreeDay]

  /// Bumped on the day-change notification and on foregrounding, so
  /// `todaysEntries` re-cuts the day.
  @State private var dayChanged = Date()
  /// Bumped when the phone's context lands (Phase 2): the region every figure
  /// here is expressed in may have changed, and the App Group defaults are not
  /// observable (invariant 3, on the wrist).
  @State private var bridgeRevision = 0

  /// The user's own hide, per glance: view-local, never persisted, and it
  /// never gates a write (ADR-0045, the owner's answers to the design's
  /// questions 3 and 4). Cleared on launch by construction.
  @State private var isCountHidden = false
  /// Occupies the hint's slot for about two seconds; reserves no row.
  @State private var toast: Toast?
  @State private var toastTask: Task<Void, Never>?

  /// The tail of the counter's operations — see the type's comment.
  @State private var counterOps: Task<Void, Never>?

  #if DEBUG
  @State private var cloudKitStatus: String?
  #endif

  private enum Toast {
    case tapAgainToShow
    case removeOnPhone
    case notSaved
    /// The type a pick from the picker just wrote, by name.
    case loggedType(String)
  }

  /// The type picker, the app's only navigation (ADR-0042): pushed by a hold
  /// on ＋, popped by the pick.
  @State private var showsPicker = false

  /// The watch's own "Show session pace" (ADR-0044): watch-local, off until
  /// set, read once here and written through `AppSettings.store`.
  @State private var showsSessionPace = AppSettings.storedShowsSessionPace()

  /// Whether the app's store fell back to memory at launch — the app's own
  /// knowledge, not the App Group's store-mode breadcrumb, which the
  /// complication's own container also writes.
  private let isStoreInMemory: Bool

  init(isStoreInMemory: Bool = false, now: Date = .now, calendar: Calendar = .current) {
    self.isStoreInMemory = isStoreInMemory
    let today = calendar.startOfDay(for: now)
    let floor = calendar.date(byAdding: .day, value: -1, to: today) ?? today
    _recentEntries = Query(FetchDescriptor<DrinkEntry>.since(floor))
  }

  // MARK: - Derived facts

  private var todaysEntries: [DrinkEntry] {
    _ = dayChanged
    return recentEntries.filter { Calendar.current.isDateInToday($0.loggedAt) }
  }

  private var todaysDrinks: [LoggedDrink] { todaysEntries.loggedDrinks }

  /// The session's raw material: everything the query holds, since a sitting
  /// can start before midnight. Sessions are runs of absolute timestamps,
  /// calendar-free (ADR-0017), so no day cut applies here.
  private var sessionDrinks: [LoggedDrink] { recentEntries.loggedDrinks }

  /// The rolling two-hour window's band, or nil for the ring — the one rule
  /// the complication reads too (`SessionDots.band`, ADR-0044).
  private func paceBand(now: Date) -> DayIntensity? {
    SessionDots.band(in: sessionDrinks, now: now, region: region)
  }

  /// The region the phone last sent — or the US, which is also what the phone
  /// itself computes with when none was chosen (ADR-0041).
  private var region: Region {
    _ = bridgeRevision
    return AppSettings.storedRegion()
  }

  /// Whether the phone has ever sent its settings. Until it has, the region
  /// line says so rather than printing a US figure as if it were chosen.
  private var hasReceivedContext: Bool {
    _ = bridgeRevision
    return Diagnostics.lastWatchContextReceived != nil
  }

  private var total: Double {
    todaysDrinks.reduce(0) { $0 + $1.standardDrinks(in: region) }
  }

  private var isTodayMarked: Bool {
    let today = Calendar.current.startOfDay(for: Date())
    return alcoholFreeDays.contains { $0.day == today }
  }

  private var isTodayMarkedFromHealth: Bool {
    let today = Calendar.current.startOfDay(for: Date())
    return alcoholFreeDays.contains { $0.day == today && $0.isImportedFromHealth }
  }

  /// The same fold as the phone's hero and the calendar cell (ADR-0034).
  private var band: DayIntensity {
    DayIntensity.bucket(
      standardDrinks: total,
      isMarkedAlcoholFree: isTodayMarked,
      hasEntries: !todaysEntries.isEmpty
    )
  }

  /// Whether − has something it may remove right now — drawn, never trusted:
  /// the operation re-decides from the store at execution time.
  private var canRemove: Bool {
    LoggedDrink.removableNewest(in: todaysDrinks, on: Date()) != nil
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      counter
        .navigationDestination(isPresented: $showsPicker) {
          TypePickerView { type in
            logSpecific(type)
            showsPicker = false
          }
        }
    }
  }

  private var counter: some View {
    ScrollView {
      VStack(spacing: 0) {
        counterRow

        if isTodayMarked {
          markedState
            .padding(.top, WatchLayout.rowToMarkedLine)
        } else {
          unitWord
            .padding(.top, WatchLayout.rowToUnitWord)
          if todaysEntries.isEmpty {
            recordNoAlcoholButton
              .padding(.top, WatchLayout.unitWordToRecordButton)
          } else {
            estimateLine
              .padding(.top, WatchLayout.unitWordToEstimate)
          }
        }

        // The legend keys the ramp, so it is drawn only while the day is on
        // it: an empty day has no band to key and a marked day is off the
        // ramp (the design's screens 3 and 5).
        if band != .unlogged && band != .alcoholFree {
          WatchBandLegend(active: band, labelsHidden: isCountHidden)
            .padding(.top, WatchLayout.estimateToLegend)
        }

        if isStoreInMemory {
          StorageWarningStrip()
            .padding(.top, 8)
        } else {
          hintSlot
            .padding(.top, 8)

          // The wrist's Settings in miniature: one switch, below the fold,
          // so the screen the user raises stays the counter (ADR-0044). Not
          // offered while the strip owns the slot: a switch for a row that
          // cannot appear would be a promise.
          //
          // And not offered on a day with nothing logged (the owner's ask,
          // 2026-09-15): the row it governs cannot exist without a drink, so
          // on a dry day the switch is a control for nothing — and this app
          // does not put a session surface in front of someone who is not
          // having one. `|| showsSessionPace` keeps it reachable once turned
          // on, so the setting can never be stranded out of reach on a dry
          // day.
          if !todaysEntries.isEmpty || showsSessionPace {
            sessionToggle
              .padding(.top, WatchLayout.slotToToggle)
          }
        }
      }
      .padding(.horizontal, WatchLayout.screenMargin)
      .padding(.top, 2)
      .padding(.bottom, 4)
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      dayChanged = Date()
    }
    .onReceive(NotificationCenter.default.publisher(for: .watchContextDidChange)) { _ in
      bridgeRevision += 1
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      dayChanged = Date()
      bridgeRevision += 1
      // The face re-reads the store on every raise: the cheapest moment to
      // catch up on what the phone logged while this app was not running.
      WidgetCenter.shared.reloadAllTimelines()
      #if DEBUG
      Task { await refreshCloudKitStatus() }
      #endif
    }
    #if DEBUG
    .task { await refreshCloudKitStatus() }
    #endif
  }

  // MARK: - The row

  private var counterRow: some View {
    HStack(spacing: WatchLayout.counterGap) {
      CounterDisc(glyph: .minus, looksEnabled: canRemove) { _ in
        removeNewest()
      }

      CounterTile(count: todaysEntries.count, band: band, isCountHidden: isCountHidden)
        // 86pt is well over the touch floor, so the hide needs no affordance
        // and none is drawn (ADR-0045).
        .contentShape(RoundedRectangle(cornerRadius: WatchLayout.tileRadius, style: .continuous))
        .onTapGesture { toggleHidden() }

      // Also the Double Tap target (the disc carries the shortcut), and held,
      // the way to the type picker (ADR-0042).
      CounterDisc(glyph: .plus, onLongPress: { showsPicker = true }) { viaGesture in
        addOne(viaGesture: viaGesture)
      }
    }
    .frame(maxWidth: .infinity)
    // One adjustable element, not three stops: the value already says the
    // number, and the colour encodes nothing a reader needs twice. Hiding
    // does not change what is spoken (ADR-0045).
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Drinks today")
    // The `Text` overload: an interpolated literal here would put a bare
    // "%lld" key in the catalog, which is no key at all.
    .accessibilityValue(Text(todaysEntries.count, format: .number))
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: addOne(viaGesture: false)
      case .decrement: removeNewest()
      @unknown default: break
      }
    }
  }

  // MARK: - Beneath the row

  private var unitWord: some View {
    Text(todaysEntries.count == 1 ? "drink today" : "drinks today")
      .font(.system(size: WatchLayout.unitWordSize))
      .foregroundStyle(.secondary)
  }

  /// The region's figure, or — before the phone has ever sent its settings —
  /// the fact that it has not, rather than a US figure that looks chosen.
  @ViewBuilder
  private var estimateLine: some View {
    if hasReceivedContext {
      Text(verbatim: StandardDrink.liveEstimate(total, region: region))
        .font(.system(size: WatchLayout.estimateSize))
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .privacySensitive()
        .opacity(isCountHidden ? 0 : 1)
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isCountHidden)
    } else {
      Text("Region not set yet")
        .font(.system(size: WatchLayout.estimateSize))
        .foregroundStyle(.secondary)
    }
  }

  /// The empty day's second control (the owner's answer to the design's
  /// question 1): the wrist is the surface you are wearing at the end of a
  /// dry day. The phone's exact words.
  private var recordNoAlcoholButton: some View {
    Button {
      recordNoAlcohol()
    } label: {
      Text("Record no alcohol today")
        .font(.system(size: WatchLayout.recordButtonTextSize, weight: .medium))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: WatchLayout.discSide)
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    // The design's full-width capsule on `AccentFill` — the fill pair, never
    // the accent text colour, under a white label (design review R2).
    .background(Capsule().fill(Color("AccentFill")))
  }

  /// Factual in both directions, in `TodayView`'s words: states what was
  /// recorded, awards nothing. A day mirrored from Apple Health offers no way
  /// to clear it (ADR-0025); ＋ is the way back from the user's own marker,
  /// since a logged drink clears it (`DrinkRepository.saveOrThrow`).
  private var markedState: some View {
    VStack(spacing: WatchLayout.markedLineGap) {
      Text("Recorded as no alcohol today")
        .font(.system(size: WatchLayout.markedLineSize))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Text(isTodayMarkedFromHealth ? "From Apple Health" : "Tap the plus sign to change that.")
        .font(.system(size: WatchLayout.hintSize))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  /// The bottom slot (the design's "the hint yields the bottom slot to the
  /// row"): a toast for a moment; otherwise the sitting's dots while a
  /// session is active and the watch's own toggle is on (Phase 5, ADR-0044);
  /// otherwise the one hint the counter carries, the way to the type picker.
  /// The diagnostics line sits beneath whichever, in debug builds.
  private var hintSlot: some View {
    VStack(spacing: 4) {
      slotContent
      #if DEBUG
      Text(verbatim: debugLine)
        .font(.system(size: 8))
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
      #endif
    }
  }

  @ViewBuilder
  private var slotContent: some View {
    if let toast {
      // The design's toast pill: the hint's size on a `.primary` 10% ground.
      toastText(toast)
        .font(.system(size: WatchLayout.hintSize))
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
          RoundedRectangle(cornerRadius: WatchLayout.toastRadius, style: .continuous)
            .fill(Color.primary.opacity(0.10))
        )
        .transition(.opacity)
    } else if showsSessionPace {
      // A 60-second clock, never a `Timer`: session existence, the elapsed
      // time and the rolling band recompute at the cadence they change at
      // (ADR-0017; a one-second wakeup in a frontmost watch app is a battery
      // complaint in a review).
      TimelineView(.periodic(from: .now, by: 60)) { context in
        if let session = SessionPace.currentSession(in: sessionDrinks, now: context.date) {
          SessionDotRow(
            session: session,
            band: paceBand(now: context.date),
            now: context.date,
            isCountHidden: isCountHidden
          )
        } else {
          hint
        }
      }
    } else {
      hint
    }
  }

  private var hint: some View {
    Text("Hold ＋ to say what it was")
      .font(.system(size: WatchLayout.hintSize))
      .foregroundStyle(.tertiary)
      .multilineTextAlignment(.center)
  }

  /// Off by default; the phone's own words for the switch. Watch-local: what
  /// the row shows is computed the same everywhere, so this changes what is
  /// shown and never crosses the bridge (the plan's dividing line).
  private var sessionToggle: some View {
    // The system's own switch row at its own size: a settings row, not
    // counter chrome.
    Toggle("Show session pace", isOn: Binding(
      get: { showsSessionPace },
      set: { on in
        showsSessionPace = on
        AppSettings.store(showsSessionPace: on)
        // The card's dots follow this switch (ADR-0046), and the face reads
        // it only when a timeline is built.
        WidgetCenter.shared.reloadAllTimelines()
      }
    ))
  }

  /// `Text` rather than a key, because one case is a name the package has
  /// already localized (`DrinkRow`'s reason, and `TodayDrinkRow`'s).
  private func toastText(_ toast: Toast) -> Text {
    switch toast {
    case .tapAgainToShow: Text("Tap again to show the count")
    case .removeOnPhone: Text("Remove that drink on the phone")
    case .notSaved: Text("Not saved")
    case .loggedType(let name): Text(verbatim: name)
    }
  }

  #if DEBUG
  private var debugLine: String {
    _ = bridgeRevision
    // This app's own store, not the App Group breadcrumb: the complication's
    // process opens its own container and overwrites that key.
    let store = isStoreInMemory ? "IN MEMORY" : (Diagnostics.storeMode ?? "store mode unknown")
    let cloud = cloudKitStatus ?? "iCloud not checked"
    let sent = Diagnostics.lastWatchContextReceived.map {
      $0.formatted(date: .omitted, time: .shortened)
    } ?? "none"
    return "\(store) · \(cloud) · \(region.rawValue) · \(AppSettings.storedCounterSeed().rawValue) · \(sent)"
  }

  private func refreshCloudKitStatus() async {
    await CloudKitStatusProbe.refresh()
    cloudKitStatus = Diagnostics.cloudKitStatus
  }
  #endif

  // MARK: - Operations

  /// Chains an operation behind whatever is already running.
  private func enqueue(_ op: @escaping @MainActor () async -> Void) {
    let previous = counterOps
    counterOps = Task { @MainActor in
      await previous?.value
      await op()
    }
  }

  /// One drink, now, by the seed the phone chose (ADR-0023 and its
  /// day-memory revision) — the one implementation, called at execution time.
  private func addOne(viaGesture: Bool) {
    let context = modelContext
    enqueue {
      let repository = DrinkRepository(context: context)
      do {
        try repository.logOneDrink(
          seed: AppSettings.storedCounterSeed(),
          region: AppSettings.storedRegion()
        )
        viaGesture ? WatchHaptics.loggedByGesture() : WatchHaptics.acknowledged()
        WidgetCenter.shared.reloadAllTimelines()
      } catch {
        Diagnostics.record("watch ＋ failed: \(error)")
        WatchHaptics.refused()
        show(.notSaved)
      }
    }
  }

  /// One drink of `type` at the type's defaults — what the picker writes
  /// (ADR-0042): the entry a two-tap phone log of the type makes, minus the
  /// Health sample the phone adds on its next foreground. Under the
  /// standard-drink seed it also becomes the day's template, so ＋ repeats it
  /// for the rest of the day (ADR-0023's day memory) with no stored mode.
  private func logSpecific(_ type: DrinkType) {
    let context = modelContext
    enqueue {
      let repository = DrinkRepository(context: context)
      let drink = DrinkDraft(type: type).makeLoggedDrink(region: AppSettings.storedRegion())
      do {
        try repository.saveOrThrow(drink)
        WatchHaptics.acknowledged()
        WidgetCenter.shared.reloadAllTimelines()
        // The haptic is the receipt for ＋, where there is nothing to say
        // that the count does not already show. A pick is different: it is
        // the one write on the wrist that records a *fact about the drink*,
        // and the counter has no room to carry it afterwards. So the slot
        // names the type for a moment — the owner's ask, 2026-09-15 — and
        // says nothing about size or strength, which are the type's defaults
        // and not the reader's statement (ADR-0023).
        show(.loggedType(type.displayName))
      } catch {
        Diagnostics.record("watch typed log failed: \(error)")
        WatchHaptics.refused()
        show(.notSaved)
      }
    }
  }

  /// Removes today's newest entry when the watch may (ADR-0043); otherwise
  /// refuses, and says why once, in the hint's slot.
  private func removeNewest() {
    let context = modelContext
    enqueue {
      let repository = DrinkRepository(context: context)
      let today = repository.drinks(on: Date())
      guard let target = LoggedDrink.removableNewest(in: today, on: Date()) else {
        WatchHaptics.refused()
        if !today.isEmpty { show(.removeOnPhone) }
        return
      }
      repository.delete(id: target.id)
      WatchHaptics.acknowledged()
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  /// Records today as a day with no alcohol, exactly as Siri's intent does:
  /// through `markAlcoholFreeOrThrow`, which refuses a day that has drinks and
  /// writes nothing to Health (the phone's `DrinkStore.markAlcoholFree` writes
  /// none either — checked before this was built, per the plan).
  private func recordNoAlcohol() {
    let context = modelContext
    enqueue {
      let repository = DrinkRepository(context: context)
      do {
        let recorded = try repository.markAlcoholFreeOrThrow(Date())
        recorded ? WatchHaptics.acknowledged() : WatchHaptics.refused()
        // The phone's store skips this reload because its widget draws
        // nothing for a marker; the face draws the marker (ADR-0046).
        if recorded { WidgetCenter.shared.reloadAllTimelines() }
      } catch {
        Diagnostics.record("watch no-alcohol failed: \(error)")
        WatchHaptics.refused()
        show(.notSaved)
      }
    }
  }

  private func toggleHidden() {
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.22)) {
      isCountHidden.toggle()
    }
    if isCountHidden { show(.tapAgainToShow) }
  }

  private func show(_ message: Toast) {
    toastTask?.cancel()
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { toast = message }
    toastTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(2))
      guard !Task.isCancelled else { return }
      withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { toast = nil }
    }
  }
}
