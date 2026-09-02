import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Month calendar. The pattern over weeks, and the way to record a day you missed.
///
/// Complements Trends rather than duplicating it: the chart answers "how much", the
/// calendar answers "which days". Neither frames an answer as good or bad.
struct CalendarView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.modelContext) private var context
  @Environment(\.colorScheme) private var colorScheme

  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var allEntries: [DrinkEntry]
  @Query private var alcoholFreeDays: [AlcoholFreeDay]

  @State private var visibleMonth: Date = Calendar.current.startOfDay(for: Date())
  @State private var selectedDay: SelectedDay?
  @State private var editingDraft: DrinkDraft?
  @State private var deletion = DeletionCoordinator()

  /// The tail of the day sheet's ± operations. Each new one awaits the previous,
  /// so mutations run strictly in order and each resolves its target from the
  /// store at execution time — two minus taps remove two drinks even when the
  /// first is still mid-write, and a minus queued behind a plus removes the drink
  /// that plus created (ADR-0013).
  @State private var counterOps: Task<Void, Never>?

  // Drag-to-select. The anchor is set once per gesture, where the long press
  // landed; the current index follows the finger. Both clear on release, at
  // which point the run moves into `pendingDays` and stays highlighted while
  // the action bar offers what to do with it (Tallyist prototype handoff).
  @State private var dragAnchorIndex: Int?
  @State private var dragCurrentIndex: Int?
  @State private var pendingDays: [CalendarDay] = []
  @State private var bulkSelection: BulkSelection?

  /// Measured width of the grid area, for reserving the grid's height.
  @State private var gridWidth: CGFloat = 0

  /// The grid bleeds this far past the screen margin on each side — cells grow
  /// from ~45pt to ~49pt on a 402pt device while every other element keeps the
  /// 20pt margin (prototype handoff, change 1).
  private let gridBleed: CGFloat = 10

  private var calendar: Calendar { .current }

  var body: some View {
    ZStack(alignment: .bottom) {
      ScrollView {
        VStack(spacing: GlassTokens.Spacing.section) {
          monthHeader
          weekdayHeader
            .padding(.horizontal, -gridBleed)
          monthGrid
            .padding(.horizontal, -gridBleed)
          IntensityLegend()
          selectionHint
          RecentSummaryCard(summary: summary, region: settings.effectiveRegion)
        }
        .screenMargin()
        .padding(.vertical, GlassTokens.Spacing.section)
      }

      VStack(spacing: GlassTokens.Spacing.tight) {
        // The undo bar also renders inside the day sheet; here it covers the
        // window after the sheet closes, so a removal stays recoverable.
        if selectedDay == nil, let drink = deletion.recentlyDeleted {
          UndoDeleteBar(drink: drink) {
            Task { await deletion.undo(using: store) }
          }
          .padding(.bottom, GlassTokens.Spacing.tight)
        }
        if !barDays.isEmpty {
          selectionBar
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .animation(.easeOut(duration: 0.3), value: barDays.isEmpty)
    .animation(.smooth(duration: 0.25), value: deletion.recentlyDeleted)
    // The bar's visibility also flips with sheet presentation; without this value
    // the dismiss-then-appear pops in unanimated.
    .animation(.smooth(duration: 0.25), value: selectedDay)
    .onDisappear { pendingDays = [] }
    .navigationTitle("Calendar")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      // The share card (1.2 spec, Feature D): user-initiated, every time —
      // this button is the feature's only entrance. The image renders at
      // share time from the visible month's data; nothing is persisted and
      // nothing is recorded about whether or where it went.
      ToolbarItem(placement: .topBarTrailing) {
        ShareLink(
          item: MonthShareImage(
            grid: grid,
            region: settings.effectiveRegion,
            colorScheme: colorScheme,
            calendar: calendar
          ),
          preview: SharePreview(
            grid.month.formatted(.dateTime.month(.wide).year())
          )
        ) {
          Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share this month as an image")
      }
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
          YearView()
        } label: {
          Image(systemName: "square.grid.3x3")
        }
        .accessibilityLabel("Year view")
      }
    }
    .sheet(item: $selectedDay) { selection in
      DayLogSheet(
        day: selection.date,
        existingDrinks: drinks(on: selection.date),
        isMarkedAlcoholFree: markedDays.contains(calendar.startOfDay(for: selection.date)),
        seed: seedDrink(for: selection.date),
        deletion: deletion,
        onAddDrink: { addOneDrink(on: selection.date) },
        onAddStandardDrink: { addStandardDrink(on: selection.date) },
        onRemoveMostRecent: { removeMostRecent(on: selection.date) },
        onUndoDelete: { Task { await deletion.undo(using: store) } },
        onMarkAlcoholFree: { store.markAlcoholFree(selection.date) },
        onClearAlcoholFree: { store.unmarkAlcoholFree(selection.date) },
        onEditDrink: { drink in
          selectedDay = nil
          editingDraft = DrinkDraft(editing: drink)
        }
      )
    }
    .sheet(item: $editingDraft) { draft in
      DrinkDetailSheet(draft: draft, showsTimeControl: true) { _ in
        editingDraft = nil
      } onCancel: {
        editingDraft = nil
      }
    }
    .sheet(item: $bulkSelection) { selection in
      BulkFillSheet(
        days: selection.days,
        seed: bulkFillSeed,
        onApply: { count, dates in
          bulkFill(count, on: dates)
          pendingDays = []
        }
      )
    }
  }

  // MARK: - Data

  private var store: DrinkStore {
    DrinkStore(context: context, health: health)
  }

  private var markedDays: Set<Date> {
    Set(alcoholFreeDays.map(\.day))
  }

  private var totalsByDay: [Date: Double] {
    TrendSummary.totalsByDay(
      allEntries.loggedDrinks,
      region: settings.effectiveRegion,
      calendar: calendar
    )
  }

  private var grid: MonthGrid {
    TrendSummary.monthGrid(
      containing: visibleMonth,
      totalsByDay: totalsByDay,
      alcoholFreeDays: markedDays,
      calendar: calendar
    )
  }

  private var summary: RecentSummary {
    TrendSummary.recentSummary(
      endingOn: Date(),
      totalsByDay: totalsByDay,
      alcoholFreeDays: markedDays,
      calendar: calendar
    )
  }

  /// What a calendar log will look like on `day` — and it has to be *what the
  /// ＋ will actually write*, because the day sheet describes it to the user
  /// before they tap (ADR-0023).
  ///
  /// Under the standard-drink seed the memory is day-scoped (ADR-0023
  /// revision): the day's own most recently described drink, else one
  /// standard drink — the same rule `DrinkDraft.quickCount` applies, read
  /// from the same entries. Under the usual-drink seed, the type logged most
  /// often at its last-logged size, falling back to that type's defaults.
  private func seedDrink(for day: Date) -> LoggedDrink? {
    if settings.counterSeed == .standardDrink {
      if let template = DrinkDraft.dayTemplate(
        on: day, in: drinks(on: day), calendar: calendar
      ), !template.isTypeUnspecified {
        return template
      }
      return .standardDrink(in: settings.effectiveRegion)
    }
    let drinks = allEntries.loggedDrinks
    guard let type = TrendSummary.mostLoggedType(in: drinks) else { return nil }
    // The write's rule exactly (`DrinkDraft.quickCount`, ADR-0022): a newest
    // row with no size to repeat is not what ＋ will log, so the caption must
    // not describe it either. Without the check the day sheet said "0oz at
    // 0%" while ＋ wrote the type's defaults.
    if let recent = TrendSummary.mostRecentDrink(ofType: type, in: drinks), recent.isRepeatable {
      return recent
    }
    return DrinkDraft(type: type).makeLoggedDrink(region: settings.effectiveRegion)
  }

  /// The bulk-fill caption's seed. Bulk fill only ever writes to blank days
  /// (ADR-0011), and a blank day has no described drink to follow — so under
  /// the standard-drink seed this is always the standard drink itself.
  private var bulkFillSeed: LoggedDrink? {
    if settings.counterSeed == .standardDrink {
      return .standardDrink(in: settings.effectiveRegion)
    }
    return seedDrink(for: Date())
  }

  private func drinks(on day: Date) -> [LoggedDrink] {
    allEntries.loggedDrinks
      .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
      .sorted { $0.loggedAt > $1.loggedAt }
  }

  /// Chains a ± operation behind whatever is already running (see `counterOps`).
  private func enqueueCounterOp(_ op: @escaping @MainActor () async -> Void) {
    let previous = counterOps
    counterOps = Task { @MainActor in
      await previous?.value
      await op()
    }
  }

  /// The day sheet's plus: one drink, seeded by the shared `quickCount` rule.
  ///
  /// The timestamp comes from `TrendSummary.backfillTimestamp`: `now` when the day
  /// is today (Today's own contract), otherwise noon-or-later so the new drink is
  /// always the day's most recent — which is what makes plus-then-minus lossless.
  /// State is read inside the op, after any pending write has committed, never
  /// from the tap-time query snapshot.
  private func addOneDrink(on day: Date) {
    let store = store
    let calendar = calendar
    let region = settings.effectiveRegion
    let seed = settings.counterSeed
    enqueueCounterOp {
      let history = ((try? store.repository.context.fetch(FetchDescriptor<DrinkEntry>())) ?? [])
        .loggedDrinks
      let stamp = TrendSummary.backfillTimestamp(
        on: day,
        existing: store.repository.drinks(on: day, calendar: calendar),
        calendar: calendar
      )
      let drink = DrinkDraft
        .quickCount(1, from: history, seed: seed, region: region, at: stamp, calendar: calendar)
        .makeLoggedDrink(region: region)
      await store.save(drink)
    }
  }

  /// The day sheet's way back to standard drinks (ADR-0023 revision): one
  /// untyped standard drink, dated this day, which as the day's newest entry
  /// is what ＋ repeats from here on. Same timestamp rule as the plus.
  private func addStandardDrink(on day: Date) {
    let store = store
    let calendar = calendar
    let region = settings.effectiveRegion
    enqueueCounterOp {
      let stamp = TrendSummary.backfillTimestamp(
        on: day,
        existing: store.repository.drinks(on: day, calendar: calendar),
        calendar: calendar
      )
      let drink = DrinkDraft.standardDrink(region: region, at: stamp)
        .makeLoggedDrink(region: region)
      await store.save(drink)
    }
  }

  /// The day sheet's minus: removes that day's most recent entry through the same
  /// path as a swipe-delete, so the Health sample is retired and undo appears.
  /// The victim is fetched fresh inside the op — after the previous ± has fully
  /// committed — so rapid taps each remove a different drink.
  private func removeMostRecent(on day: Date) {
    let store = store
    let calendar = calendar
    let deletion = deletion
    enqueueCounterOp {
      // Same skip as Today's minus: imported Health entries are read-only
      // mirrors, so the victim is the day's newest drink the app owns (ADR-0014).
      guard let recent = store.repository.drinks(on: day, calendar: calendar)
        .first(where: { !$0.isImportedFromHealth }) else { return }
      await deletion.delete(recent, using: store)
    }
  }

  /// One answer, applied to every date the bulk sheet decided to write.
  ///
  /// The sheet has already dropped days with any record, so this only ever touches
  /// blank days — but `markAlcoholFree` still refuses a day with entries, so even a
  /// stale selection can't produce a contradiction. Seeding is captured once before
  /// the loop: "the same value" on every day means the same drink, not a seed that
  /// drifts as the loop's own writes change what's most recent.
  private func bulkFill(_ count: Int, on dates: [Date]) {
    if count == 0 {
      for date in dates { store.markAlcoholFree(date) }
      return
    }
    let history = allEntries.loggedDrinks
    let region = settings.effectiveRegion
    let seed = settings.counterSeed
    let store = store
    Task {
      for date in dates {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let drinks = DrinkDraft
          .quickCount(count, from: history, seed: seed, region: region, at: noon, calendar: calendar)
          .makeLoggedDrinks(region: region)
        await store.save(drinks)
      }
    }
  }

  // MARK: - Header

  private var monthHeader: some View {
    HStack {
      Button {
        shiftMonth(by: -1)
      } label: {
        Image(systemName: "chevron.left")
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .accessibilityLabel("Previous month")

      Spacer()

      Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
        .font(GlassTokens.Typography.sheetTitle)
        .contentTransition(.numericText())

      Spacer()

      Button {
        shiftMonth(by: 1)
      } label: {
        Image(systemName: "chevron.right")
          .frame(width: 44, height: 44)
          .contentShape(.rect)
      }
      .accessibilityLabel("Next month")
      .disabled(isShowingCurrentMonth)
      .opacity(isShowingCurrentMonth ? 0.3 : 1)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Color.accentColor)
  }

  /// There is nothing to see in the future, and a calendar that scrolls into it
  /// invites logging drinks that haven't happened.
  private var isShowingCurrentMonth: Bool {
    calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
  }

  private func shiftMonth(by months: Int) {
    guard let shifted = calendar.date(byAdding: .month, value: months, to: visibleMonth) else {
      return
    }
    // A selection is a run of days in the visible month; the bar acting on days
    // that scrolled out of sight would be an invisible write.
    pendingDays = []
    withAnimation(.snappy(duration: 0.2)) { visibleMonth = shifted }
  }

  private var weekdayHeader: some View {
    HStack(spacing: 0) {
      // Identity is the column position, not the letter: very-short weekday
      // symbols repeat ("S", "T"), and `id: \.self` over them made SwiftUI log
      // duplicate-ID warnings with undefined-results semantics.
      ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
        Text(symbol)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityHidden(true)
  }

  /// Rotated to the locale's first weekday, so the labels line up with the grid's
  /// own leading blanks.
  private var orderedWeekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let offset = calendar.firstWeekday - 1
    return Array(symbols[offset...] + symbols[..<offset])
  }

  // MARK: - Grid

  private var monthGrid: some View {
    GeometryReader { proxy in
      let spacing: CGFloat = 6
      let side = (proxy.size.width - spacing * 6) / 7

      LazyVGrid(
        columns: Array(repeating: GridItem(.fixed(side), spacing: spacing), count: 7),
        spacing: spacing
      ) {
        ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
          Color.clear.frame(width: side, height: side)
        }
        ForEach(grid.days) { day in
          IntensityCell(
            day: day,
            side: side,
            isToday: calendar.isDateInToday(day.date),
            isSelected: highlightedDates.contains(day.date),
            region: settings.effectiveRegion
          )
          .onTapGesture {
            guard day.date <= Date() else { return }
            selectedDay = SelectedDay(date: day.date)
          }
          .opacity(day.date > Date() ? 0.3 : 1)
        }
      }
      .coordinateSpace(.named("monthGrid"))
      .gesture(dragSelectGesture(side: side, spacing: spacing))
      // A tick as the selection grows or shrinks a cell, so the finger can feel
      // the extent without the eye leaving the far end of the run.
      .sensoryFeedback(.selection, trigger: dragCurrentIndex)
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      gridWidth = width
    }
    .frame(height: gridHeight)
  }

  /// Discoverability for a gesture with no visible affordance. One quiet line —
  /// the tap path works without ever reading it.
  private var selectionHint: some View {
    Text("Tip: press and hold, then drag across days to fill a stretch at once")
      .font(.caption2)
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Drag selection

  /// Long-press first, so the drag doesn't fight the scroll view: a pan scrolls,
  /// a still quarter-second claims the gesture for selection. The drag then takes
  /// zero further movement to start, because the press point itself is the anchor.
  private func dragSelectGesture(side: CGFloat, spacing: CGFloat) -> some Gesture {
    LongPressGesture(minimumDuration: 0.25)
      .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("monthGrid")))
      .onChanged { value in
        guard case .second(true, let drag?) = value else { return }
        if dragAnchorIndex == nil {
          dragAnchorIndex = dayIndex(at: drag.startLocation, side: side, spacing: spacing)
        }
        // Off-grid positions return nil and keep the last extent, so a finger
        // that wanders past an edge doesn't drop the selection it built.
        if let current = dayIndex(at: drag.location, side: side, spacing: spacing) {
          dragCurrentIndex = current
        }
      }
      .onEnded { value in
        let selection = selectedDays
        dragAnchorIndex = nil
        dragCurrentIndex = nil
        guard case .second = value, !selection.isEmpty else { return }
        // The run stays highlighted and the bar stays up: releasing is not yet a
        // decision, it's the end of pointing at things.
        pendingDays = selection
      }
  }

  /// The dragged-over run, oldest first, without future days. A drag whose anchor
  /// never landed on a day (a leading blank) selects nothing.
  private var selectedDays: [CalendarDay] {
    guard let anchor = dragAnchorIndex else { return [] }
    let current = dragCurrentIndex ?? anchor
    let now = Date()
    return grid.days(between: anchor, and: current).filter { $0.date <= now }
  }

  /// What the action bar operates on: the live run while the finger is down,
  /// the parked run after release.
  private var barDays: [CalendarDay] {
    dragAnchorIndex != nil ? selectedDays : pendingDays
  }

  private var highlightedDates: Set<Date> {
    Set(barDays.map(\.date))
  }

  /// Days in the selection a bulk action can actually write to (ADR-0011).
  private var fillableCount: Int {
    barDays.count { !$0.hasEntries && !$0.isMarkedAlcoholFree }
  }

  // MARK: - Selection action bar

  /// Bottom-pinned bar from the prototype handoff, carrying PR #12's two-way
  /// semantics: the common answer ("no drinks") is one tap, the counted answer
  /// opens the existing bulk sheet. Appears as soon as a drag selects a day,
  /// live count while the finger moves, and stays up after release until acted
  /// on or dismissed.
  private var selectionBar: some View {
    VStack(spacing: GlassTokens.Spacing.regular) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(barDays.count == 1 ? "1 day selected" : "\(barDays.count) days selected")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .contentTransition(.numericText(value: Double(barDays.count)))
            .animation(.snappy, value: barDays.count)
          Text(
            fillableCount == 0
              ? "Every selected day already has a record"
              : "Days that already have a record are kept"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          pendingDays = []
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.primary.opacity(0.06)))
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear selection")
      }

      HStack(spacing: GlassTokens.Spacing.tight) {
        Button {
          bulkSelection = BulkSelection(days: pendingDays)
        } label: {
          Text("Log drinks…")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassSurface(cornerRadius: GlassTokens.Radius.control, interactive: true)

        Button(action: markNoDrinks) {
          Text("Mark no drinks")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 40)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background(
          // AccentFill, not accentColor: white label on a fill — review R2.
          RoundedRectangle(cornerRadius: GlassTokens.Radius.control, style: .continuous)
            .fill(Color("AccentFill"))
        )
      }
      .disabled(fillableCount == 0)
      .opacity(fillableCount == 0 ? 0.4 : 1)
    }
    .padding(GlassTokens.Spacing.cardPadding)
    .glassSurface(cornerRadius: GlassTokens.Radius.pill)
    .padding(.horizontal, GlassTokens.Spacing.cardPadding)
    .padding(.bottom, GlassTokens.Spacing.section)
  }

  /// The bar's one-tap answer. Same rule as the sheet: only days with no record
  /// in either direction are touched, and the repository's own guard backstops
  /// even that (ADR-0011).
  private func markNoDrinks() {
    for day in pendingDays where !day.hasEntries && !day.isMarkedAlcoholFree {
      store.markAlcoholFree(day.date)
    }
    pendingDays = []
  }

  /// Point → (row, column) → day index, using the same `side` and `spacing` the
  /// grid was laid out with. The arithmetic that decides which day that is lives
  /// in `MonthGrid.dayIndex(row:column:)`, where it has tests.
  private func dayIndex(at point: CGPoint, side: CGFloat, spacing: CGFloat) -> Int? {
    guard point.x >= 0, point.y >= 0 else { return nil }
    let column = Int(point.x / (side + spacing))
    let row = Int(point.y / (side + spacing))
    return grid.dayIndex(row: row, column: column)
  }

  private var gridHeight: CGFloat {
    let rows = ceil(Double(grid.leadingBlanks + grid.days.count) / 7.0)
    let spacing: CGFloat = 6
    // Cells are square and sized off the width, so the height has to be reserved
    // ahead of layout. Computed from the measured width — the same formula the
    // grid itself uses — because the old hardcoded 52pt bound stopped covering
    // the widest iPhones once the grid gained its 10pt bleed. First layout pass
    // (width not yet measured) falls back to the old bound.
    let side = gridWidth > 0 ? (gridWidth - spacing * 6) / 7 : 52
    return CGFloat(rows) * side + CGFloat(max(0, rows - 1)) * spacing
  }
}

// MARK: - Sheet presentation

/// Wraps the tapped date for `.sheet(item:)`.
///
/// A retroactive `Identifiable` on `Date` would be the shorter route and the wrong
/// one: it is a conformance on a type this app doesn't own, visible everywhere it
/// imports Foundation, to satisfy one sheet.
struct SelectedDay: Identifiable, Hashable {
  let date: Date
  var id: TimeInterval { date.timeIntervalSince1970 }
}

/// Wraps a drag-selected run of days for `.sheet(item:)`, same reasoning as above.
struct BulkSelection: Identifiable, Hashable {
  /// Chronological, past days only — filtered before the sheet is presented.
  let days: [CalendarDay]
  var id: Date { days.first?.date ?? .distantPast }
}
