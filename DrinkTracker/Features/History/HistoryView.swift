import DrinkTrackerCore
import SwiftData
import SwiftUI

/// Every logged drink, grouped by day.
///
/// This is where a mistake gets corrected: swipe to remove, tap to edit, or add a
/// drink you forgot at the time it actually happened. Deleting is undoable for a
/// few seconds, because "I tapped the wrong thing" applies to deleting too.
struct HistoryView: View {
  @Environment(AppSettings.self) private var settings
  @Environment(HealthKitService.self) private var health
  @Environment(\.modelContext) private var context

  @Query(sort: \DrinkEntry.loggedAt, order: .reverse) private var entries: [DrinkEntry]

  @State private var draft: DrinkDraft?
  @State private var deletion = DeletionCoordinator()

  private var groups: [DayGroup] {
    TrendSummary.groupedByDay(entries.loggedDrinks)
  }

  var body: some View {
    Group {
      if groups.isEmpty {
        emptyState
      } else {
        list
      }
    }
    .navigationTitle("History")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          // Opens at the current time; the sheet's time control moves it back.
          draft = DrinkDraft(type: .beer)
        } label: {
          Image(systemName: "plus")
        }
        .accessibilityLabel("Add a drink")
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let drink = deletion.recentlyDeleted {
        UndoDeleteBar(drink: drink) {
          Task { await deletion.undo(using: store) }
        }
        .padding(.bottom, GlassTokens.Spacing.tight)
      }
    }
    .animation(.smooth(duration: 0.25), value: deletion.recentlyDeleted)
    .sheet(item: $draft) { current in
      DrinkDetailSheet(draft: current, showsTimeControl: true) { _ in
        draft = nil
      } onCancel: {
        draft = nil
      }
    }
  }

  private var store: DrinkStore {
    DrinkStore(context: context, health: health)
  }

  // MARK: - List

  private var list: some View {
    List {
      ForEach(groups) { group in
        Section {
          ForEach(group.drinks) { drink in
            // Imported Health entries are read-only mirrors: no edit (there is
            // no size or strength to correct) and no remove (delete it in the
            // app that logged it, and the mirror follows) — ADR-0013.
            if drink.isImportedFromHealth {
              DrinkRow(drink: drink, region: settings.effectiveRegion)
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
                    Label("Edit", systemImage: "pencil")
                  }
                  .tint(.accentColor)
                }
            }
          }
        } header: {
          header(for: group)
        }
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
  }

  private func header(for group: DayGroup) -> some View {
    HStack {
      Text(group.day.formatted(.dateTime.weekday(.wide).month().day()))
      Spacer()
      Text(StandardDrink.formatted(group.total(in: settings.effectiveRegion)))
        .monospacedDigit()
    }
    .font(.caption)
    .foregroundStyle(.secondary)
  }

  // MARK: - Empty

  private var emptyState: some View {
    ContentUnavailableView {
      Label("Nothing logged yet", systemImage: "list.bullet")
    } description: {
      Text("Drinks you log will appear here, where you can edit or remove them.")
    }
  }
}
