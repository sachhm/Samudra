import SwiftUI

struct HUDView: View {
    let tool: ToolMode
    let hazardCount: Int
    let ntmCount: Int
    let zoomPercent: Int
    let chartName: String

    var body: some View {
        HStack(spacing: 10) {
            // Chart pill
            HStack(spacing: 6) {
                Image(systemName: "map")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(chartName)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: Capsule())

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
