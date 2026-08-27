import CoreTransferable
import DrinkTrackerCore
import SwiftUI
import UniformTypeIdentifiers

/// The share card (1.2 spec, Feature D): a one-way image export of one month.
///
/// User-initiated every time — the ShareLink in the calendar's toolbar is the
/// only way in; no prompts, no nudges. The PNG is built at share time from
/// raw data (no temp file, nothing persisted, nothing logged about sharing),
/// and PNG data from `pngData()` carries no EXIF or identifying metadata.
/// Content is the user's own month and nothing else: month name, total,
/// average per week, the grid. No comparison to anyone.
struct MonthShareImage: Transferable {
  let grid: MonthGrid
  let region: Region
  let colorScheme: ColorScheme
  let calendar: Calendar

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .png) { card in
      let data = await MainActor.run { card.renderPNG() }
      guard let data else {
        throw CocoaError(.fileWriteUnknown)
      }
      return data
    }
    // A static name: DataRepresentation has no per-item filename hook, and
    // the file-writing alternative would leave a temp file behind — which
    // the spec's acceptance criteria forbid ("no file left behind").
    .suggestedFileName("tallyist-month.png")
  }

  @MainActor
  private func renderPNG() -> Data? {
    let renderer = ImageRenderer(
      content: MonthShareCardView(
        grid: grid, region: region, calendar: calendar
      )
      .environment(\.colorScheme, colorScheme)
    )
    renderer.scale = 3
    renderer.proposedSize = ProposedViewSize(width: 360, height: nil)
    return renderer.uiImage?.pngData()
  }
}

/// The purpose-built layout — never a screenshot of the live Trends or
/// Calendar view. Sized for Messages; explicit backgrounds because an
/// exported image has no host surface to inherit.
struct MonthShareCardView: View {
  let grid: MonthGrid
  let region: Region
  let calendar: Calendar

  @Environment(\.colorScheme) private var scheme

  private var total: Double {
    grid.days.reduce(0) { $0 + $1.standardDrinks }
  }

  private var perWeek: Double {
    guard !grid.days.isEmpty else { return 0 }
    return total / (Double(grid.days.count) / 7)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GlassTokens.Spacing.regular) {
      Text(grid.month.formatted(.dateTime.month(.wide).year()))
        .font(.title2.weight(.semibold))
        .foregroundStyle(textPrimary)

      HStack(spacing: GlassTokens.Spacing.section) {
        stat(StandardDrink.formatted(total), region.unitName(for: total))
        stat(StandardDrink.formatted(perWeek), "\(region.unitName(for: perWeek)) a week")
      }

      monthGrid

      legend

      // Wordmark in text, alone — the mark never locks up with text
      // (design-system.md, "The mark").
      Text("Tallyist")
        .font(.caption.weight(.semibold))
        .foregroundStyle(textSecondary)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(GlassTokens.Spacing.section)
    .frame(width: 360)
    .background(background)
  }

  private func stat(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(.title, design: .rounded, weight: .semibold))
        .foregroundStyle(textPrimary)
      Text(label)
        .font(.caption)
        .foregroundStyle(textSecondary)
    }
  }

  private var monthGrid: some View {
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    return LazyVGrid(columns: columns, spacing: 4) {
      ForEach(0..<grid.leadingBlanks, id: \.self) { _ in
        Color.clear.frame(height: 36)
      }
      ForEach(grid.days) { day in
        cell(day)
      }
    }
  }

  private func cell(_ day: CalendarDay) -> some View {
    let intensity = day.intensity
    return RoundedRectangle(cornerRadius: 8, style: .continuous)
      .fill(IntensityPalette.fill(intensity, scheme: scheme))
      .frame(height: 36)
      .overlay {
        if IntensityPalette.isOutlined(intensity) {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(textSecondary, lineWidth: 1.5)
        }
      }
      .overlay {
        Text("\(calendar.component(.day, from: day.date))")
          .font(.system(size: 12, weight: .medium, design: .rounded))
          .foregroundStyle(ink(intensity))
      }
  }

  private var legend: some View {
    HStack(spacing: GlassTokens.Spacing.regular) {
      legendSwatch(.alcoholFree, "No alcohol")
      legendSwatch(.low, "1–2")
      legendSwatch(.medium, "3–5")
      legendSwatch(.high, "6+")
    }
    .font(.caption2)
    .foregroundStyle(textSecondary)
  }

  private func legendSwatch(_ intensity: DayIntensity, _ label: String) -> some View {
    HStack(spacing: 4) {
      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(IntensityPalette.fill(intensity, scheme: scheme))
        .overlay {
          if IntensityPalette.isOutlined(intensity) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
              .strokeBorder(textSecondary, lineWidth: 1)
          }
        }
        .frame(width: 12, height: 12)
      Text(label)
    }
  }

  // Explicit, not semantic: the image has no surface behind it, so the card
  // paints its own light or dark ground and inks.
  private var background: Color {
    scheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
  }

  private var textPrimary: Color {
    scheme == .dark ? .white : .black
  }

  private var textSecondary: Color {
    (scheme == .dark ? Color.white : .black).opacity(0.55)
  }

  private func ink(_ intensity: DayIntensity) -> Color {
    switch intensity {
    case .unlogged: textSecondary
    case .alcoholFree: textPrimary
    case .low: scheme == .dark ? .white : .black
    case .medium, .high: scheme == .dark ? .black : .white
    }
  }
}
