import SwiftUI

struct HUDView: View {
    let tool: ToolMode
    let hazardCount: Int
    let ntmCount: Int
    let zoomPercent: Int
    let currentChart: ChartDocument
    let onSelectChart: (ChartDocument) -> Void
    let pencilLatLong: Coordinate?

    var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 10) {
                // Chart pill — Menu for picker
                Menu {
                    Section("Charts") {
                        ForEach(ChartCatalog.all, id: \.id) { chart in
                            Button {
                                guard chart.id != currentChart.id else { return }
                                onSelectChart(chart)
                            } label: {
                                if chart.id == currentChart.id {
                                    SwiftUI.Label("\(chart.code) — \(chart.displayName)", systemImage: "checkmark")
                                } else {
                                    Text("\(chart.code) — \(chart.displayName)")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(currentChart.code)  \(currentChart.displayName.uppercased())")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .contentShape(Capsule())
                }
                .menuOrder(.fixed)
                .buttonStyle(.plain)
                .accessibilityLabel("Chart")
                .accessibilityValue("\(currentChart.code) \(currentChart.displayName)")
                .accessibilityHint("Choose a different chart")

                // Coord pill (only when pencilLatLong present)
                if let coord = pencilLatLong {
                    CoordinateHUDPill(coordinate: coord)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer()

                // Zoom + marks pill
                HStack(spacing: 12) {
                    Text("\(zoomPercent)%")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Capsule().fill(.quaternary).frame(width: 1, height: 12)

                    tally(symbol: "exclamationmark.triangle.fill",
                          count: hazardCount,
                          tint: ChartPalette.hazardRed)

                    tally(symbol: "mappin.circle.fill",
                          count: ntmCount,
                          tint: ChartPalette.noteYellow)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .glassEffect(.regular, in: Capsule())
            }
        }
    }

    private func tally(symbol: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? Color.primary : Color.secondary)
                .contentTransition(.numericText())
        }
    }
}
